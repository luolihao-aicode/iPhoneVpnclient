import Flutter
import UIKit
import NetworkExtension
import os.log

/// MethodChannel bridge between Flutter and iOS native VPN code.
///
/// Channels:
///   - `dev.forge.vpn/vpn_service` — main VPN control
@available(iOS 15.0, *)
class VpnPlugin: NSObject {

    // MARK: - Singleton

    static let shared = VpnPlugin()

    private static let channelName = "dev.forge.vpn/vpn_service"
    private var channel: FlutterMethodChannel?
    private weak var observedConnection: NEVPNConnection?

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
                    let errDesc = error.localizedDescription
                    os_log(.error, "[ForgeVPN] startVPN failed: %{public}@", errDesc)
                    // Send detailed error back to Flutter
                    result(FlutterError(code: "VPN_ERROR",
                                       message: errDesc,
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

        case "getState":
            Task {
                result(await vpnState())
            }

        case "diagnose":
            Task {
                let info = await diagnoseVPN()
                result(info)
            }

        case "requestPermission":
            // On iOS, VPN permission is system-granted via provisioning profile
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Diagnostics

    private func diagnoseVPN() async -> [String: Any] {
        var info: [String: Any] = [:]
        info["bundleId"] = Bundle.main.bundleIdentifier ?? "nil"
        info["appName"] = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "unknown"

        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            info["managersCount"] = managers.count
            let manager = matchingManager(in: managers)
            info["hasVPNConfig"] = manager != nil
            if let manager {
                info["status"] = self.vpnStatusString(manager.connection.status)
                info["isEnabled"] = manager.isEnabled
                info["localizedDesc"] = manager.localizedDescription ?? "nil"
                if let proto = manager.protocolConfiguration as? NETunnelProviderProtocol {
                    info["providerBundleID"] = proto.providerBundleIdentifier ?? "nil"
                    info["serverAddress"] = proto.serverAddress ?? "nil"
                }
                if manager.connection.status == .connected {
                    info["providerDiagnostics"] = await providerMessage("diagnose", manager: manager)
                    info["providerLogs"] = await providerMessage("logs", manager: manager)
                }
            }
        } catch {
            info["loadError"] = error.localizedDescription
        }

        return info
    }

    private func providerMessage(
        _ request: String,
        manager: NETunnelProviderManager
    ) async -> String {
        guard let session = manager.connection as? NETunnelProviderSession else {
            return "Packet Tunnel session is unavailable"
        }
        let requestData = Data(request.utf8)
        return await withCheckedContinuation { continuation in
            do {
                try session.sendProviderMessage(requestData) { responseData in
                    guard let responseData,
                          let response = String(data: responseData, encoding: .utf8) else {
                        continuation.resume(returning: "No response from Packet Tunnel")
                        return
                    }
                    continuation.resume(returning: response)
                }
            } catch {
                continuation.resume(returning: "Packet Tunnel message failed: \(error.localizedDescription)")
            }
        }
    }

    private func vpnState() async -> [String: Any] {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            guard let manager = matchingManager(in: managers) else {
                return [
                    "status": "idle",
                    "message": "No Forge VPN tunnel configuration",
                    "permissionGranted": true,
                ]
            }
            return [
                "status": vpnStatusString(manager.connection.status),
                "message": manager.isEnabled ? "Restored Packet Tunnel state" : "Packet Tunnel disabled",
                "permissionGranted": true,
            ]
        } catch {
            return [
                "status": "error",
                "message": error.localizedDescription,
                "permissionGranted": false,
            ]
        }
    }

    private func matchingManager(
        in managers: [NETunnelProviderManager]
    ) -> NETunnelProviderManager? {
        managers.first { manager in
            guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol else {
                return false
            }
            return proto.providerBundleIdentifier == providerBundleIdentifier
        }
    }

    private var providerBundleIdentifier: String {
        Bundle.main.bundleIdentifier.map { "\($0).tunnel" } ?? "dev.forge.vpn.tunnel"
    }

    private func vpnStatusString(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid: return "invalid"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reasserting: return "reasserting"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown"
        }
    }

    private func observeStatus(of connection: NEVPNConnection) {
        if observedConnection === connection { return }
        if let observedConnection {
            NotificationCenter.default.removeObserver(
                self,
                name: Notification.Name.NEVPNStatusDidChange,
                object: observedConnection
            )
        }
        observedConnection = connection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange(_:)),
            name: Notification.Name.NEVPNStatusDidChange,
            object: connection
        )
    }

    @objc private func vpnStatusDidChange(_ notification: Notification) {
        guard let connection = notification.object as? NEVPNConnection else { return }
        let status = vpnStatusString(connection.status)
        VpnPlugin.sendStatus(status, message: "System tunnel status: \(status)")
    }

    // MARK: - VPN Control

    private func startVPN(configJson: String) async throws {
        // Load existing or create new tunnel manager
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()

        let manager: NETunnelProviderManager
        if let existing = matchingManager(in: managers) {
            manager = existing
        } else {
            manager = NETunnelProviderManager()
            manager.localizedDescription = "Forge VPN"

            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = providerBundleIdentifier
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

        // NetworkExtension persists the configuration asynchronously. Reload the
        // manager before starting so its connection uses the committed profile.
        try await manager.loadFromPreferences()
        observeStatus(of: manager.connection)

        switch manager.connection.status {
        case .connected, .connecting, .reasserting:
            let status = vpnStatusString(manager.connection.status)
            VpnPlugin.sendStatus(status, message: "System tunnel status: \(status)")
            return
        default:
            break
        }

        // Start the tunnel
        VpnPlugin.sendStatus("connecting", message: "Starting iOS Packet Tunnel")
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
              let manager = matchingManager(in: managers) else {
            return false
        }
        return manager.connection.status == .connected
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
