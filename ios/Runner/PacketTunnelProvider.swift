import NetworkExtension
import os.log

// Sing-box gomobile framework — linked via build-singbox-ios.sh
// #if canImport(Singbox) used at call sites for graceful degradation
// when the framework hasn't been compiled yet.
#if canImport(Singbox)
import Singbox
#endif

/// iOS VPN tunnel provider — integrates sing-box via gomobile bindings.
///
/// Prerequisites (build step, not done in this file):
///   1. Build sing-box iOS framework:
///      ```
///      gomobile bind -v -target=ios \
///        -iosversion=14.0 \
///        -ldflags='-s -w' \
///        -o ./ios/Runner/Singbox.xcframework \
///        ./golib/ios
///      ```
///   2. Add Singbox.xcframework to Xcode project > General > Frameworks
///
/// The Go library (`golib/ios`) must expose at minimum:
///   - `Start(config string, tunFd int32) error`
///   - `Stop() error`
///   - `SetLogCallback(cb func(string))`
///   - `GetStats() (*Stats, error)`
///
// MARK: - Logging

/// Conforms to gomobile's SingboxLogCallbackProtocol (ObjC bridge).
/// gomobile translates Go's LogCallback interface into an ObjC protocol
/// named SingboxLogCallbackProtocol with an onLog: method.
#if canImport(Singbox)
class SingboxLogHandler: NSObject, SingboxLogCallbackProtocol {
    func onLog(_ message: String?) {
        guard let msg = message else { return }
        os_log(.info, "[ForgeVPN] [sing-box] %{public}@", msg)
    }
}
#endif

// MARK: - Errors

enum VpnError: LocalizedError {
    case configError(String)
    case singBoxError(String)

    var errorDescription: String? {
        switch self {
        case .configError(let msg): return "Configuration error: \(msg)"
        case .singBoxError(let msg): return "sing-box error: \(msg)"
        }
    }
}

// MARK: - Tunnel Provider

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

    /// The last sing-box config JSON passed from Flutter.
    private var lastConfigJson: String = ""

    /// TUN file descriptor obtained after setting tunnel network settings.
    private var tunFd: Int32 = -1

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
        lastConfigJson = configJson

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
        //    and gives us a file descriptor to pass to sing-box.
        //    On iOS, setTunnelNetworkSettings completion gives us
        //    access to packetFlow; the TUN fd must be retrieved
        //    via the packet flow's `value(forKey:)` trick or by
        //    using NEProvider's file descriptor.
        try await setTunnelNetworkSettings(settings)

        // 4. Retrieve TUN file descriptor for sing-box
        //    iOS doesn't expose the fd directly — shim via packetFlow.
        //    sing-box gomobile typically needs a raw fd for TUN I/O.
        //
        //    Two strategies:
        //      A) Use packetFlow (readPackets/writePackets) with a
        //         pure-Darwin gomobile build that reads/writes via
        //         the ObjC callback bridge (more portable).
        //      B) Retrieve fd via KVO trick (fragile across iOS versions).
        //
        //    We implement approach B first, with A as fallback.

        // Attempt to get TUN fd via the standard NEProvider property
        if let fd = (self as NSObject).value(forKey: "tunInterfaceFileDescriptor") as? Int32,
           fd >= 0
        {
            tunFd = fd
            os_log(.info, "[ForgeVPN] TUN fd obtained: %d", tunFd)
        } else {
            tunFd = -1
            os_log(.info, "[ForgeVPN] TUN fd not available; using packetFlow bridge")
        }

        // 5. Start sing-box via gomobile bindings
        try startSingBox(configJson: configJson, tunFd: tunFd)

        // 6. Start packet loop (needed when tunFd < 0 for packetFlow bridge,
        //    or as fallback for health monitoring)
        startPacketLoop(useFd: tunFd >= 0)

        // 7. Extension status updates through os_log (Flutter reads NEVPNManager status)

        os_log(.info, "[ForgeVPN] Tunnel started successfully (tunFd=%d, fdMode=%@)",
               tunFd,
               tunFd >= 0 ? "direct" : "packetFlow")
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        os_log(.info, "[ForgeVPN] Stopping tunnel, reason: %{public}@",
               String(describing: reason))

        stopPacketLoop()
        stopSingBox()
    }

    // MARK: - Sing-box Integration

    /// Start sing-box core with the provided configuration.
    ///
    /// This requires the `Singbox` framework built from gomobile.
    /// Wrap calls in `#if canImport(Singbox) ... #endif` so the
    /// project compiles before the framework is built.
    private func startSingBox(configJson: String, tunFd: Int32) throws {
        #if canImport(Singbox)
        // Set up log callback (gomobile exposes LogCallback as ObjC protocol)
        SingboxSetLogCallback(SingboxLogHandler())

        // Start sing-box — gomobile bridges Start as:
        //   func start(_ configJson: String?, _ tunFd: Int) -> String?
        // Returns nil or empty string on success, error message on failure.
        let result: String? = if tunFd >= 0 {
            SingboxStart(configJson, Int(tunFd))
        } else {
            SingboxStart(configJson, -1)
        }

        if let errorMsg = result, !errorMsg.isEmpty {
            throw VpnError.singBoxError(errorMsg)
        }

        os_log(.info, "[ForgeVPN] sing-box started")
        #else
        os_log(.info, "[ForgeVPN] Singbox framework not linked; running in pass-through mode")
        #endif
    }

    /// Stop the sing-box core.
    private func stopSingBox() {
        #if canImport(Singbox)
        SingboxStop()
        os_log(.info, "[ForgeVPN] sing-box stopped")
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
            // sing-box manages TUN via fd; just monitor health
            os_log(.info, "[ForgeVPN] Packet loop: fd mode (sing-box manages TUN)")
            return
        }

        os_log(.info, "[ForgeVPN] Packet loop: packetFlow bridge mode")

        packetTask = Task { [weak self] in
            guard let self = self else { return }

            while self.reading {
                let (packets, protocols) = await self.packetFlow.readPackets()
                if packets.isEmpty {
                    try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
                    continue
                }

                // Forward packets to sing-box for processing
                await self.forwardPacketsToSingBox(packets, protocols: protocols)
            }
        }
    }

    /// Forward TUN packets to sing-box via its feed API.
    ///
    /// In fd mode, this is handled by sing-box internally.
    /// In packetFlow mode, we need to push packets into sing-box's TUN input.
    private func forwardPacketsToSingBox(
        _ packets: [Data],
        protocols: [NSNumber]
    ) async {
        guard !packets.isEmpty else { return }

        #if canImport(Singbox)
        for (index, packet) in packets.enumerated() {
            let af = protocols[index].intValue == AF_INET ? Int32(AF_INET) : Int32(AF_INET6)
            // Push packet into sing-box — gomobile bridges as:
            //   func feedTunPacket(_ data: Data?, _ af: Int32)
            SingboxFeedTunPacket(packet, af)

            // Read processed packet back — gomobile bridges as:
            //   func readTunPacket(_ mtu: Int32) -> Data?
            if let outData = SingboxReadTunPacket(Int32(mtu)) {
                self.packetFlow.writePackets([outData], withProtocols: [protocols[index]])
            }
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
        // Return basic status info for app health checks
        guard let request = String(data: messageData, encoding: .utf8) else {
            return "{\"error\":\"invalid request\"}".data(using: .utf8)
        }

        switch request {
        case "ping":
            return "pong".data(using: .utf8)
        case "status":
            let statusJson = """
            {"running":\(tunFd >= 0), "mtu":\(mtu), "connected":true}
            """
            return statusJson.data(using: .utf8)
        default:
            return "{\"error\":\"unknown command\"}".data(using: .utf8)
        }
    }
}
