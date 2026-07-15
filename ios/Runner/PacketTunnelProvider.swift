import NetworkExtension
import os.log

/// iOS VPN tunnel provider — equivalent of Android's ForgeVpnService.
///
/// Runs as a separate process managed by iOS. All traffic routed through
/// a TUN interface, forwarded to sing-box or equivalent proxy engine.
@available(iOS 14.0, *)
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - State

    private var config: TunnelConfig?
    private var singBoxProcess: Process?
    private let queue = DispatchQueue(label: "dev.forge.vpn.tunnel")

    private struct TunnelConfig {
        let server: String
        let port: Int
        let method: String
        let password: String
        let configJSON: String
    }

    // MARK: - Tunnel Lifecycle

    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        os_log(.info, "[ForgeVPN] Starting tunnel...")

        guard let options = options,
              let configJSON = options["config"] as? String else {
            throw NSError(
                domain: "dev.forge.vpn",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing VPN configuration"]
            )
        }

        // Parse config from Flutter
        config = parseConfig(from: configJSON)
        guard let config = config else {
            throw NSError(
                domain: "dev.forge.vpn",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid VPN configuration"]
            )
        }

        // Build NEVPN tunnel network settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "172.16.0.1")
        settings.mtu = 1500

        // IPv4 settings — route all traffic through tunnel
        let ipv4 = NEIPv4Settings(addresses: ["172.16.0.2"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        // DNS
        let dns = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        settings.dnsSettings = dns

        // Apply settings
        try await setTunnelNetworkSettings(settings)

        // Handle tunnel packets
        let tunFd = packetFlow.value(forKey: "socket") as! Int32
        os_log(.info, "[ForgeVPN] TUN fd: %d", tunFd)

        // Start sing-box or equivalent
        startProxyEngine(config: config, tunFd: tunFd)

        // Notify Flutter
        VpnPlugin.sendStatus("connected", message: "")
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        os_log(.info, "[ForgeVPN] Stopping tunnel, reason: %{public}@", String(describing: reason))

        stopProxyEngine()
        VpnPlugin.sendStatus("disconnected", message: "Tunnel stopped: \(reason)")
    }

    // MARK: - Packet Handling

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        // Respond to pings from the main app
        return "pong".data(using: .utf8)
    }

    // MARK: - Proxy Engine

    private func startProxyEngine(config: TunnelConfig, tunFd: Int32) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // ──────────────────────────────────────
            // Approach: Bundle sing-box compiled for iOS
            // ──────────────────────────────────────
            // 1. Get sing-box binary from app bundle
            guard let binaryPath = Bundle.main.path(forResource: "sing-box", ofType: nil) else {
                os_log(.error, "[ForgeVPN] sing-box binary not found in bundle")
                // Fallback: run without proxy engine (tunnel only)
                self.startDirectTunnel(tunFd: tunFd)
                return
            }

            // 2. Write config to temp directory
            let tmpDir = FileManager.default.temporaryDirectory
            let configFile = tmpDir.appendingPathComponent("singbox-config.json")
            do {
                try config.configJSON.write(to: configFile, atomically: true, encoding: .utf8)
            } catch {
                os_log(.error, "[ForgeVPN] Failed to write config: %{public}@",
                       error.localizedDescription)
                self.startDirectTunnel(tunFd: tunFd)
                return
            }

            // 3. Launch sing-box
            os_log(.info, "[ForgeVPN] Starting sing-box with TUN fd: %d", tunFd)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = [
                "run",
                "-c", configFile.path,
                "-D", tmpDir.path,
                "--tun-fd", "\(tunFd)"
            ]

            process.terminationHandler = { [weak self] proc in
                os_log(.info, "[ForgeVPN] sing-box exited code: %d", proc.terminationStatus)
                if proc.terminationStatus != 0 {
                    VpnPlugin.sendLog("[err] sing-box exit code: \(proc.terminationStatus)")
                }
            }

            self.singBoxProcess = process

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                os_log(.error, "[ForgeVPN] Failed to start sing-box: %{public}@",
                       error.localizedDescription)
                self.startDirectTunnel(tunFd: tunFd)
            }
        }
    }

    /// Simple direct tunnel (no proxy) — used as fallback if sing-box is unavailable.
    /// Packets pass through untouched; enough to verify UI and tunnel plumbing.
    private func startDirectTunnel(tunFd: Int32) {
        VpnPlugin.sendLog("[warn] Running without sing-box — direct tunnel mode (no proxy)")

        // Read packets from TUN and write them back (pass-through)
        queue.async { [weak self] in
            guard let self = self else { return }
            let readSize = 65535

            while true {
                // Read a batch of packets
                let packets = self.packetFlow.readPackets()
                if packets.packets.isEmpty {
                    Thread.sleep(forTimeInterval: 0.05)
                    continue
                }

                // In direct mode, just echo them back
                // (In real mode, these would be routed to sing-box)
                if packets.protocols.count == packets.packets.count {
                    self.packetFlow.writePackets(packets.packets, withProtocols: packets.protocols)
                }
            }
        }
    }

    private func stopProxyEngine() {
        singBoxProcess?.terminate()
        singBoxProcess = nil
    }

    // MARK: - Config Parsing

    private func parseConfig(from jsonString: String) -> TunnelConfig? {
        struct ParsedConfig: Codable {
            let server: String
            let serverPort: Int
            let method: String?
            let password: String?
            let uuid: String?
            let security: String?

            enum CodingKeys: String, CodingKey {
                case server
                case serverPort = "server_port"
                case method, password, uuid, security
            }
        }

        guard let data = jsonString.data(using: .utf8),
              let outbounds = try? JSONDecoder().decode(
                [String: [ParsedConfig]].self, from: data
              ),
              let servers = outbounds["outbounds"],
              let first = servers.first else {
            return nil
        }

        return TunnelConfig(
            server: first.server,
            port: first.serverPort,
            method: first.method ?? "aes-256-gcm",
            password: first.password ?? first.uuid ?? "",
            configJSON: jsonString
        )
    }
}
