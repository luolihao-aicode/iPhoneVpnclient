import NetworkExtension
import os.log

/// iOS VPN tunnel provider — equivalent of Android's ForgeVpnService.
///
/// On iOS, subprocesses (`Process`) are unavailable due to sandbox restrictions.
/// This provider establishes the TUN interface and forwards packets through
/// a simple pass-through tunnel. Sing-box integration requires linking it as
/// a static library or using the NetworkExtension API directly.
@available(iOS 14.0, *)
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Tunnel Lifecycle

    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        os_log(.info, "[ForgeVPN] Starting tunnel...")

        // Build TUN network settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "172.16.0.1")
        settings.mtu = 1500

        // IPv4 — route all traffic through tunnel
        let ipv4 = NEIPv4Settings(addresses: ["172.16.0.2"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        // DNS
        let dns = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        settings.dnsSettings = dns

        // Apply tunnel settings
        try await setTunnelNetworkSettings(settings)

        // Start reading/writing tunnel packets
        // (sing-box integration TBD: link as static library via CGo)
        startPacketLoop()

        // Notify Flutter
        VpnPlugin.sendStatus("connected", message: "Tunnel established")
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        os_log(.info, "[ForgeVPN] Stopping tunnel, reason: %{public}@",
               String(describing: reason))
        VpnPlugin.sendStatus("disconnected",
                             message: "Tunnel stopped: \(reason)")
    }

    // MARK: - Packet Handling

    private var packetQueue: DispatchQueue?
    private var reading = true

    /// Simple packet pass-through loop.
    ///
    /// Reads packets from the TUN interface and writes them back.
    /// In production, packets would be forwarded to sing-box via its C API.
    private func startPacketLoop() {
        let queue = DispatchQueue(label: "dev.forge.vpn.packets")
        packetQueue = queue
        reading = true

        queue.async { [weak self] in
            guard let self = self else { return }
            VpnPlugin.sendLog("[info] Packet loop started (direct pass-through)")

            while self.reading {
                let packets = self.packetFlow.readPackets()
                if packets.packets.isEmpty {
                    // No packets available — sleep briefly
                    Thread.sleep(forTimeInterval: 0.05)
                    continue
                }

                // Direct pass-through: write packets back to TUN
                // (No proxy processing until sing-box is integrated)
                if packets.protocols.count == packets.packets.count {
                    self.packetFlow.writePackets(
                        packets.packets,
                        withProtocols: packets.protocols
                    )
                }
            }
        }
    }

    private func stopPacketLoop() {
        reading = false
        packetQueue = nil
    }

    // MARK: - App Messages

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        return "pong".data(using: .utf8)
    }
}
