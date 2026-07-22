# iOS VPN capability parity design

## Goal

Bring the iOS VPN implementation to parity with the Android VPN experience while preserving iOS platform semantics. The supported minimum version is iOS 14. The result is a real Packet Tunnel backed by sing-box, with reliable state, diagnostics, logging, lifecycle handling, and GitHub-built signed IPA delivery for on-device verification through Aisi Assistant.

## Scope

The iOS implementation will provide the following Android-equivalent capabilities:

- A single VPN lifecycle: `idle`, `connecting`, `connected`, `disconnecting`, and `error`.
- Configuration validation, persistence in the tunnel provider configuration, and recovery of the system tunnel state after the Flutter app restarts.
- Serialized connection requests so repeated connect/disconnect actions do not leave duplicate `NETunnelProviderManager` records or orphaned extensions.
- Structured native diagnostics with runtime, signing/configuration, tunnel, provider, and sing-box state.
- Native runtime logs and state events delivered to Flutter through the existing method channel.
- A real sing-box Packet Tunnel only. The existing pass-through / missing-framework fallback is removed.
- A controlled provider-message interface from the containing app to the extension for health, state, and log-summary queries.
- Explicit, user-readable errors for invalid configuration, manager persistence failures, missing provider configuration, extension startup errors, and system tunnel failures.

The Flutter UI and business workflow remain shared. `IosVpnService` gains Android-parity operations such as state restoration and consistent event processing, and `AppProvider` consumes the same normalized state model on both mobile platforms.

## Platform boundaries

Android-specific mechanisms are not emulated on iOS:

- Foreground service notifications are replaced by iOS Network Extension lifecycle handling.
- Android per-application allow/deny lists, `VpnService.protect`, and physical-interface callbacks have no direct iOS equivalent.
- iOS diagnostics label these capabilities as `not_applicable`; they are never reported as working features.

## Architecture

### Flutter service contract

The existing `dev.forge.vpn/vpn_service` channel remains the public contract. Both mobile services expose `connect`, `disconnect`, `isRunning`, `restoreState`, and `diagnose`; they publish normalized `onStatus` and `onLog` callbacks.

`AppProvider` owns UI state. It records transitional status messages, starts traffic statistics only after `connected`, and stops them on `disconnected` or `error`.

### iOS containing app

`VpnPlugin` owns tunnel-manager persistence and status observation. It uses one manager for the Forge bundle identifier, configures the Packet Tunnel provider bundle identifier, stores the sing-box configuration, and serializes lifecycle operations. It observes `NEVPNStatusDidChange`, translates system statuses to the shared contract, and queries the extension through `sendProviderMessage` for live diagnostics and logs.

### Packet Tunnel extension

`PacketTunnelProvider` owns tunnel network settings, starts and stops sing-box, and maintains extension-local runtime state. It reports startup completion only after settings and sing-box initialization have succeeded. It implements provider messages for `ping`, `status`, `diagnose`, and `logs` using JSON responses. On failure it stops sing-box, records the error, and completes the tunnel start with that error.

The extension must never use private KVC to obtain a TUN file descriptor and must never run as a direct/pass-through tunnel when sing-box is missing. The sing-box mobile binding must use the supported packet-flow bridge configured by the iOS binding layer.

## Lifecycle and error handling

1. Flutter validates that a selected node exists and generates sing-box JSON.
2. The containing app validates the JSON and creates or reloads the single tunnel manager.
3. The manager is saved, then the extension is started. The app reports `connecting`.
4. The extension applies network settings, starts sing-box, and publishes `connected` only on success.
5. Stop, revocation, reassertion failure, and extension errors clean up the runtime and publish a final normalized state.
6. On app launch, `restoreState` reloads the manager and maps the system connection state into Flutter without issuing a new connection request.

Every native error includes a stable error code, a safe human-readable message, and a log entry. Sensitive configuration values are never emitted to Flutter logs or diagnostics.

## Signed GitHub Actions delivery

GitHub Actions remains the build authority. It builds the sing-box XCFramework, app, and Packet Tunnel extension together, signs both targets with the paid Apple Developer team, validates the embedded extension and effective entitlements, and uploads a signed IPA artifact.

The workflow reads the signing certificate, private key, certificate password, and the two matching provisioning profiles from GitHub Secrets. It imports them into a temporary keychain, installs profiles by UUID, and fails before packaging if the requested Network Extension / packet-tunnel entitlements are absent from the signed app or extension. Secret names, bundle identifiers, and team ID are documented in the workflow so they can be configured without committing credentials.

The signed artifact is downloaded and installed with Aisi Assistant on a physical device. The verification run checks install, manager creation, connect, traffic routing, disconnect, background/foreground recovery, and the diagnostic report.

## Testing

- Dart MethodChannel tests cover iOS state restoration, status mapping, diagnostics, callback handling, and native error propagation.
- Swift tests cover status mapping, provider message JSON, configuration validation, and lifecycle coordinator behavior that can be isolated from `NetworkExtension`.
- GitHub Actions runs Flutter tests and builds both iOS targets on macOS.
- The signed-artifact inspection validates both bundle IDs, Packet Tunnel extension embedding, executable architectures, and effective signed entitlements.
- Device acceptance testing is performed with the GitHub artifact installed through Aisi Assistant using the paid team profile.

## Acceptance criteria

1. iOS reports the same normalized lifecycle states as Android and restores status after app relaunch.
2. A selected subscription node establishes a real Packet Tunnel through sing-box; no pass-through fallback exists.
3. The app exposes native logs and diagnostics sufficient to identify configuration, signing, manager, extension, or engine failures.
4. Duplicate connection attempts do not create multiple tunnel configurations or leave an extension running after disconnect.
5. GitHub Actions produces a signed IPA whose main app and Packet Tunnel extension contain the required Network Extension entitlement.
6. The IPA installs with Aisi Assistant and passes connect, route, disconnect, and recovery checks on an iOS 14-or-newer device.
