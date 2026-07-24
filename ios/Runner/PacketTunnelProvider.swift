import Foundation
import Libbox
import NetworkExtension

enum VpnError: LocalizedError {
    case configError(String)
    case libboxError(String)

    var errorDescription: String? {
        switch self {
        case .configError(let message): return "Configuration error: \(message)"
        case .libboxError(let message): return "libbox error: \(message)"
        }
    }
}

@available(iOS 15.0, *)
final class PacketTunnelProvider: NEPacketTunnelProvider, LibboxCommandServerHandlerProtocol {
    private var commandServer: LibboxCommandServer?
    private lazy var platformInterface = LibboxPlatformInterface(provider: self)
    private var logLines = [String]()
    private let logLock = NSLock()

    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        let config = try tunnelConfiguration(options: options)
        appendLog("[packet-tunnel] configuring libbox")
        appendLog("[packet-tunnel] normal DNS routes through proxy")
        appendLog("[packet-tunnel] port 53 routes to the DNS outbound")

        try setupLibbox()
        guard let server = LibboxCommandServer(self, platformInterface: platformInterface) else {
            closeRuntime()
            throw VpnError.libboxError("create command server returned no instance")
        }

        do {
            // Do not call server.start(): that only opens libbox's optional
            // command socket, which is unnecessary and restricted in a
            // Network Extension sandbox. The in-process service API remains
            // available through startOrReloadService.
            try server.startOrReloadService(config, options: LibboxOverrideOptions())
        } catch {
            closeRuntime()
            throw VpnError.libboxError("start service: \(error.localizedDescription)")
        }

        commandServer = server
        appendLog("[packet-tunnel] libbox service started")
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        appendLog("[packet-tunnel] stopping: \(reason.rawValue)")
        closeRuntime()
    }

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        guard let request = String(data: messageData, encoding: .utf8) else {
            return response(["error": "invalid request"])
        }
        switch request {
        case "ping":
            return Data("pong".utf8)
        case "status":
            return response([
                "running": commandServer != nil,
                "connected": commandServer != nil,
            ])
        case "diagnose":
            return response([
                "running": commandServer != nil,
                "platform": "ios",
                "engine": "libbox",
            ])
        case "logs":
            return response(["lines": recentLogs()])
        default:
            return response(["error": "unknown request"])
        }
    }

    func appendLog(_ line: String) {
        logLock.lock()
        logLines.append(line)
        if logLines.count > 300 { logLines.removeFirst(logLines.count - 300) }
        logLock.unlock()
    }

    func reloadService() async throws {
        guard let savedConfig = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["config"] as? String,
            !savedConfig.isEmpty else {
            throw VpnError.configError("Missing saved sing-box configuration")
        }
        guard let commandServer else {
            throw VpnError.libboxError("libbox command server is unavailable")
        }
        try commandServer.startOrReloadService(
            proxyDNSConfiguration(savedConfig),
            options: LibboxOverrideOptions()
        )
        appendLog("[packet-tunnel] service reloaded")
    }

    func postServiceClose() {
        commandServer = nil
    }

    func serviceReload() throws {
        Task { try? await self.reloadService() }
    }

    func serviceStop() throws {
        closeRuntime()
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        LibboxSystemProxyStatus()
    }

    func setSystemProxyEnabled(_: Bool) throws {}

    func writeDebugMessage(_ message: String?) {
        if let message, !message.isEmpty { appendLog(message) }
    }

    private func tunnelConfiguration(options: [String: NSObject]?) throws -> String {
        if let config = options?["config"] as? String, !config.isEmpty {
            return proxyDNSConfiguration(config)
        }
        if let config = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["config"] as? String,
            !config.isEmpty {
            return proxyDNSConfiguration(config)
        }
        throw VpnError.configError("No sing-box configuration provided")
    }

    /// Normal browsing DNS must use the proxy on iOS. The Dart configuration
    /// also serves Android, where some local/emulator setups need direct DNS.
    /// The explicit local rule for resolving the proxy endpoint remains intact.
    private func proxyDNSConfiguration(_ configuration: String) -> String {
        guard let input = configuration.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: input),
              var root = object as? [String: Any],
              var dns = root["dns"] as? [String: Any],
              var outbounds = root["outbounds"] as? [Any] else {
            return configuration
        }

        dns["final"] = "remote"
        root["dns"] = dns

        // sing-box v1.10 does not support the later hijack-dns route action.
        // A DNS outbound is the compatible way to send intercepted port-53
        // packets into the configured DNS router.
        let hasDNSOutbound = outbounds.contains { outbound in
            (outbound as? [String: Any])?["tag"] as? String == "ios-dns"
        }
        if !hasDNSOutbound {
            outbounds.append(["type": "dns", "tag": "ios-dns"])
            root["outbounds"] = outbounds
        }

        // Do not force Cloudflare's resolver itself to bypass the tunnel.
        // The remote DNS server has a `detour: proxy` in the shared config.
        if var route = root["route"] as? [String: Any],
           var rules = route["rules"] as? [Any] {
            // The virtual resolver is 172.19.0.2:53. It is private, so the
            // generic private-address direct rule would otherwise match first.
            rules.insert(["port": [53], "outbound": "ios-dns"], at: 0)
            for index in rules.indices {
                guard var rule = rules[index] as? [String: Any],
                      rule["outbound"] as? String == "direct",
                      let cidrs = rule["ip_cidr"] as? [String] else {
                    continue
                }
                rule["ip_cidr"] = cidrs.filter { $0 != "1.1.1.1/32" }
                rules[index] = rule
            }
            route["rules"] = rules
            root["route"] = route
        }

        guard let output = try? JSONSerialization.data(withJSONObject: root),
              let rewritten = String(data: output, encoding: .utf8) else {
            return configuration
        }
        return rewritten
    }

    private func closeRuntime() {
        if let commandServer {
            try? commandServer.closeService()
            commandServer.close()
        }
        commandServer = nil
        platformInterface.reset()
    }

    private func setupLibbox() throws {
        let basePath = FileManager.default.temporaryDirectory.path
        let options = LibboxSetupOptions()
        options.basePath = basePath
        options.workingPath = basePath
        options.tempPath = basePath
        options.fixAndroidStack = false
        options.logMaxLines = 3000
        options.debug = true
        var setupError: NSError?
        guard LibboxSetup(options, &setupError) else {
            throw setupError ?? VpnError.libboxError("libbox setup failed")
        }
    }

    private func recentLogs() -> [String] {
        logLock.lock()
        defer { logLock.unlock() }
        return logLines
    }

    private func response(_ value: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: value)
    }
}
