import NetworkExtension
import os.log

// Sing-box gomobile framework — linked via build-singbox-ios.sh.
// #if canImport(Singbox) used at call sites for graceful degradation
// when the framework hasn't been compiled yet.
#if canImport(Singbox)
import Singbox
#endif

/// iOS VPN tunnel provider — integrates sing-box via gomobile bindings.
///
/// Two TUN modes:
///   A) **Direct FD mode** — retrieves the TUN file descriptor via KVO and
///      passes it to sing-box so it manages TUN I/O natively. Faster.
///   B) **PacketFlow bridge** — sing-box runs without TUN fd; the tunnel
///      provider reads/writes `NEPacketTunnelFlow` and forwards packets
///      to sing-box via FeedTunPacket/ReadTunPacket.
///
@available(iOS 14.0, *)
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Configuration

    private let tunnelAddress = "172.16.0.1"
    private let tunnelNet = "172.16.0.2"
    private let tunnelMask = "255.255.255.252"
    private let dnsServers = ["223.5.5.5", "1.1.1.1"]
    private let mtu: Int = 1500

    /// Indicates whether the packet read loop is active.
    private var reading = false
    private var packetTask: Task<Void, Never>?

    /// TUN file descriptor obtained after setting tunnel network settings.
    private var tunFd: Int32 = -1

    /// The logs callback handle registered with sing-box.
    #if canImport(Singbox)
    private var logCallback: SingboxLogCallbackProtocol?
    #endif

    // MARK: - Tunnel Lifecycle

    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        os_log(.info, "[ForgeVPN] Starting tunnel with sing-box...")

        // 1. Retrieve config from options or saved preferences
        let configJson: String
        if let optConfig = options?["config"] as? String {
            configJson = optConfig
        } else if let savedConfig = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["config"] as? String
        {
            configJson = savedConfig
        } else {
            throw VpnError.configError("No sing-box configuration provided")
        }

        // 2. Build TUN network settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelAddress)
        settings.mtu = NSNumber(value: mtu)

        // IPv4 — route all traffic through tunnel
        let ipv4 = NEIPv4Settings(
            addresses: [tunnelNet],
            subnetMasks: [tunnelMask]
        )
        ipv4.includedRoutes = [NEIPv4Route.default()]
        ipv4.excludedRoutes = [
            // Keep local traffic direct
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "100.64.0.0", subnetMask: "255.192.0.0"),
        ]
        settings.ipv4Settings = ipv4

        // DNS
        let dns = NEDNSSettings(servers: dnsServers)
        dns.domainName = "local"
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        // 3. Apply tunnel settings — this creates the TUN interface
        try await setTunnelNetworkSettings(settings)

        // 4. Retrieve TUN file descriptor for sing-box
        retrieveTunFd()

        // 5. Start sing-box via gomobile bindings
        try startSingBox(configJson: configJson, tunFd: tunFd)

        // 6. Start packet loop (needed when tunFd < 0 for packetFlow bridge)
        startPacketLoop(useFd: tunFd >= 0)

        // 7. Notify Flutter
        VpnPlugin.sendStatus("connected", message: "Tunnel established with sing-box")

        os_log(.info, "[ForgeVPN] Tunnel started successfully (tunFd=%d, fdMode=%@)",
               tunFd,
               tunFd >= 0 ? "direct" : "packetFlow")
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        os_log(.info, "[ForgeVPN] Stopping tunnel, reason: %{public}@",
               String(describing: reason))

        stopPacketLoop()
        stopSingBox()

        VpnPlugin.sendStatus("disconnected",
                             message: "Tunnel stopped: \(reason)")
    }

    // MARK: - TUN FD

    /// Attempt to retrieve the TUN interface file descriptor via KVO.
    /// Falls back silently to packetFlow mode if unavailable.
    private func retrieveTunFd() {
        if let fd = (self as NSObject).value(forKey: "tunInterfaceFileDescriptor") as? Int32,
           fd >= 0
        {
            tunFd = fd
            os_log(.info, "[ForgeVPN] TUN fd obtained: %d", tunFd)
        } else {
            tunFd = -1
            os_log(.info, "[ForgeVPN] TUN fd not available; using packetFlow bridge")
        }
    }

    // MARK: - Sing-box Integration

    /// Start sing-box core with the provided configuration.
    ///
    /// gomobile exports Go functions with these signatures:
    ///   SingboxSetLogCallback(_ cb: SingboxLogCallbackProtocol?)
    ///   SingboxStart(_ configJson: String?, _ tunFd: Int32) -> String?
    ///   SingboxStop()
    ///   SingboxFeedTunPacket(_ data: Data?, _ af: Int32)
    ///   SingboxReadTunPacket(_ mtu: Int32) -> Data?
    private func startSingBox(configJson: String, tunFd: Int32) throws {
        #if canImport(Singbox)
        // Set up log callback
        let cb = LogCallbackImpl()
        logCallback = cb
        SingboxSetLogCallback(cb)

        // Start sing-box — returns empty string on success, error msg on failure
        let result = SingboxStart(configJson, tunFd)
        if let errorMsg = result, !errorMsg.isEmpty {
            throw VpnError.tunnelError("sing-box Start failed: \(errorMsg)")
        }

        os_log(.info, "[ForgeVPN] sing-box started")
        VpnPlugin.sendLog("[info] sing-box started")
        #else
        os_log(.info, "[ForgeVPN] Singbox framework not linked; running in pass-through mode")
        VpnPlugin.sendLog("[warn] Singbox framework not linked — pass-through mode")
        #endif
    }

    /// Stop the sing-box core.
    private func stopSingBox() {
        #if canImport(Singbox)
        SingboxStop()
        logCallback = nil
        os_log(.info, "[ForgeVPN] sing-box stopped")
        VpnPlugin.sendLog("[info] sing-box stopped")
        #endif
    }

    // MARK: - Packet Handling

    /// Start reading packets from the TUN interface and forward to sing-box.
    ///
    /// When `useFd` is true (tunFd >= 0), sing-box manages the TUN interface
    /// directly and packetFlow is only used for health checks.
    /// When false, we use packetFlow as a bridge.
    private func startPacketLoop(useFd: Bool) {
        reading = true

        if useFd {
            VpnPlugin.sendLog("[info] Packet loop: fd mode (sing-box manages TUN)")
            return
        }

        VpnPlugin.sendLog("[info] Packet loop: packetFlow bridge mode")

        packetTask = Task { [weak self] in
            guard let self = self else { return }

            while self.reading {
                let (packets, protocols) = await self.packetFlow.readPackets()
                if packets.isEmpty {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    continue
                }
                await self.forwardPacketsToSingBox(packets, protocols: protocols)
            }
        }
    }

    /// Forward TUN packets to sing-box via FeedTunPacket/ReadTunPacket.
    /// In fd mode, this is handled by sing-box internally.
    private func forwardPacketsToSingBox(
        _ packets: [Data],
        protocols: [NSNumber]
    ) async {
        guard !packets.isEmpty else { return }

        #if canImport(Singbox)
        for (index, packet) in packets.enumerated() {
            let af = protocols[index].intValue == AF_INET ? Int32(AF_INET) : Int32(AF_INET6)
            SingboxFeedTunPacket(packet, af)
        }

        // Read processed packets back from sing-box
        var outPackets: [Data] = []
        while true {
            guard let outData = SingboxReadTunPacket(Int32(mtu)) else { break }
            outPackets.append(outData)
        }

        if !outPackets.isEmpty {
            // Use the last protocol for all output packets
            let outProtocol = protocols.last ?? NSNumber(value: AF_INET)
            let outProtocols = Array(repeating: outProtocol, count: outPackets.count)
            self.packetFlow.writePackets(outPackets, withProtocols: outProtocols)
        }
        #else
        // No sing-box: pass through directly
        if protocols.count == packets.count {
            self.packetFlow.writePackets(packets, withProtocols: protocols)
        }
        #endif
    }

    private func stopPacketLoop() {
        reading = false
        packetTask?.cancel()
        packetTask = nil
    }

    // MARK: - App Messages

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        guard let request = String(data: messageData, encoding: .utf8) else {
            return "{\"error\":\"invalid request\"}".data(using: .utf8)
        }

        switch request {
        case "ping":
            return "pong".data(using: .utf8)
        case "status":
            let statusJson = """
            {"fdMode":\(tunFd >= 0), "mtu":\(mtu), "connected":true}
            """
            return statusJson.data(using: .utf8)
        default:
            return "{\"error\":\"unknown command\"}".data(using: .utf8)
        }
    }
}

// MARK: - Sing-box Log Callback

/// ObjC-compatible callback class that conforms to the gomobile-generated
/// `SingboxLogCallbackProtocol`. gomobile exports Go interfaces as ObjC protocols
/// with the method name camelCased: `onLog:`.
#if canImport(Singbox)
class LogCallbackImpl: NSObject, SingboxLogCallbackProtocol {
    func onLog(_ message: String?) {
        guard let msg = message else { return }
        VpnPlugin.sendLog("[sing-box] \(msg)")
    }
}
#endif
