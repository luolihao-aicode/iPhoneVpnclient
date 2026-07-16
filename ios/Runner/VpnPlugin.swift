import Flutter
import UIKit
import NetworkExtension
import os.log

/// MethodChannel bridge between Flutter and iOS native VPN code.
///
/// Channels:
///   - `dev.forge.vpn/vpn_service` — main VPN control
@available(iOS 14.0, *)
class VpnPlugin: NSObject {

    // MARK: - Singleton

    static let shared = VpnPlugin()

    private static let channelName = "dev.forge.vpn/vpn_service"
    private var channel: FlutterMethodChannel?

    // MARK: - Registration

    /// Called by AppDelegate to register the MethodChannel.
    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VpnPlugin.shared
        instance.channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        instance.channel?.setMethodCallHandler(instance.handle)
    }

    // MARK: - Method Call Handler

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let configJson = args["config"] as? String else {
                result(FlutterError.invalidArgs)
                return
            }
            Task {
                do {
                    try await startVPN(configJson: configJson)
                    result(true)
                } catch {
                    result(FlutterError(code: "VPN_ERROR",
                                       message: error.localizedDescription,
                                       details: nil))
                }
            }

        case "disconnect":
            stopVPN()
            result(true)

        case "isRunning":
            Task {
                result(await isVpnRunning())
            }

        case "requestPermission":
            // On iOS, VPN permission is system-granted via provisioning profile
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - VPN Control

    private func startVPN(configJson: String) async throws {
        // Load existing or create new tunnel manager
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()

        let manager: NETunnelProviderManager
        if let existing = managers.first {
            manager = existing
        } else {
            manager = NETunnelProviderManager()
            manager.localizedDescription = "Forge VPN"

            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = Bundle.main.bundleIdentifier.map {
                "\($0).tunnel"
            } ?? "dev.forge.vpn.tunnel"
            proto.serverAddress = "forge-vpn"
            manager.protocolConfiguration = proto
        }

        // Pass config to tunnel provider
        guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            throw VpnError.configError("Missing protocol configuration")
        }
        proto.providerConfiguration = ["config": configJson]
        manager.isEnabled = true

        // Save to system preferences
        try await manager.saveToPreferences()

        // Start the tunnel
        try manager.connection.startVPNTunnel(options: [
            "config": configJson as NSString
        ])
    }

    private func stopVPN() {
        // Stop all active VPN configurations
        Task {
            let managers = try? await NETunnelProviderManager.loadAllFromPreferences()
            managers?.forEach { $0.connection.stopVPNTunnel() }
        }
    }

    private func isVpnRunning() async -> Bool {
        guard let managers = try? await NETunnelProviderManager.loadAllFromPreferences(),
              let first = managers.first else {
            return false
        }
        return first.connection.status == .connected
    }

    // MARK: - Status Callbacks (called from PacketTunnelProvider)

    static func sendStatus(_ status: String, message: String) {
        DispatchQueue.main.async {
            VpnPlugin.shared.channel?.invokeMethod("onStatus", arguments: [
                "status": status,
                "message": message
            ])
        }
    }

    static func sendLog(_ line: String) {
        DispatchQueue.main.async {
            VpnPlugin.shared.channel?.invokeMethod("onLog", arguments: line)
        }
    }
}

// MARK: - Errors

// Separate from PacketTunnelProvider's VpnError because they're
// in different Xcode targets (Runner vs ForgeVpnPacketTunnel).
// Each target needs its own error type.
enum VpnError: LocalizedError {
    case configError(String)

    var errorDescription: String? {
        switch self {
        case .configError(let msg): return "Configuration error: \(msg)"
        }
    }
}

extension FlutterError {
    static let invalidArgs = FlutterError(code: "INVALID_ARGS",
                                          message: "Invalid arguments",
                                          details: nil)
}
