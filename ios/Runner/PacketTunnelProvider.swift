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
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var boxService: LibboxBoxService?
    private lazy var platformInterface = LibboxPlatformInterface(provider: self)
    private var logLines = [String]()
    private let logLock = NSLock()

    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        let config = try tunnelConfiguration(options: options)
        appendLog("[packet-tunnel] configuring libbox")
        appendLog("[packet-tunnel] normal DNS routes through proxy")

        // The iOS extension exposes control through handleAppMessage below.
        // Do not start libbox's optional CommandServer here: it opens a Unix
        // socket and is blocked by the Network Extension sandbox.
        let basePath = FileManager.default.temporaryDirectory.path
        LibboxSetup(basePath, basePath, basePath, false)

        var serviceError: NSError?
        guard let service = LibboxNewService(config, platformInterface, &serviceError) else {
            closeRuntime()
            throw VpnError.libboxError(serviceError?.localizedDescription ?? "create service returned no instance")
        }
        if let serviceError {
            closeRuntime()
            throw VpnError.libboxError("create service: \(serviceError.localizedDescription)")
        }

        do {
            try service.start()
        } catch {
            closeRuntime()
            throw VpnError.libboxError("start service: \(error.localizedDescription)")
        }

        boxService = service
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
                "running": boxService != nil,
                "connected": boxService != nil,
            ])
        case "diagnose":
            return response([
                "running": boxService != nil,
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
        let config = proxyDNSConfiguration(savedConfig)
        try boxService?.close()
        var error: NSError?
        guard let service = LibboxNewService(config, platformInterface, &error) else {
            throw VpnError.libboxError(error?.localizedDescription ?? "create service returned no instance")
        }
        if let error { throw VpnError.libboxError(error.localizedDescription) }
        try service.start()
        boxService = service
        appendLog("[packet-tunnel] service reloaded")
    }

    func postServiceClose() {
        boxService = nil
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
              var dns = root["dns"] as? [String: Any] else {
            return configuration
        }

        dns["final"] = "remote"
        root["dns"] = dns

        // Do not force Cloudflare's resolver itself to bypass the tunnel.
        // The remote DNS server has a `detour: proxy` in the shared config.
        if var route = root["route"] as? [String: Any],
           var rules = route["rules"] as? [Any] {
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
        if let service = boxService { try? service.close() }
        boxService = nil
        platformInterface.reset()
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
