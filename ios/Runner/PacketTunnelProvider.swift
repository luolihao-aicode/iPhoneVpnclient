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
    private var commandServer: LibboxCommandServer?
    private var boxService: LibboxBoxService?
    private lazy var platformInterface = LibboxPlatformInterface(provider: self)
    private var logLines = [String]()
    private let logLock = NSLock()

    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        let config = try tunnelConfiguration(options: options)
        appendLog("[packet-tunnel] configuring libbox")

        let setupOptions = LibboxSetupOptions()
        setupOptions.basePath = applicationSupportDirectory().path
        setupOptions.workingPath = applicationSupportDirectory().path
        setupOptions.tempPath = FileManager.default.temporaryDirectory.path
        setupOptions.logMaxLines = 3000
        setupOptions.debug = false

        var setupError: NSError?
        LibboxSetup(setupOptions, &setupError)
        if let setupError {
            throw VpnError.libboxError("setup service: \(setupError.localizedDescription)")
        }

        let server = await LibboxNewCommandServer(platformInterface, 3000)
        do {
            try server.start()
        } catch {
            throw VpnError.libboxError("start command server: \(error.localizedDescription)")
        }
        commandServer = server

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

        server.setService(service)
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
                "commandServer": commandServer != nil,
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
        guard let config = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["config"] as? String,
            !config.isEmpty else {
            throw VpnError.configError("Missing saved sing-box configuration")
        }
        guard let commandServer else {
            throw VpnError.libboxError("Command server is not running")
        }
        try boxService?.close()
        var error: NSError?
        guard let service = LibboxNewService(config, platformInterface, &error) else {
            throw VpnError.libboxError(error?.localizedDescription ?? "create service returned no instance")
        }
        if let error { throw VpnError.libboxError(error.localizedDescription) }
        try service.start()
        commandServer.setService(service)
        boxService = service
        appendLog("[packet-tunnel] service reloaded")
    }

    func postServiceClose() {
        boxService = nil
    }

    private func tunnelConfiguration(options: [String: NSObject]?) throws -> String {
        if let config = options?["config"] as? String, !config.isEmpty { return config }
        if let config = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["config"] as? String,
            !config.isEmpty { return config }
        throw VpnError.configError("No sing-box configuration provided")
    }

    private func applicationSupportDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private func closeRuntime() {
        if let service = boxService { try? service.close() }
        boxService = nil
        commandServer?.setService(nil)
        try? commandServer?.close()
        commandServer = nil
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
