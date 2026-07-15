import 'dart:async';
import 'package:flutter/services.dart';

/// Callbacks for iOS VPN service events.
typedef VpnStatusCallback = void Function(String status, String message);
typedef VpnLogCallback = void Function(String line);

/// MethodChannel wrapper for the iOS PacketTunnelProvider.
///
/// Channels bridge between Flutter (Dart) and the native Swift
/// [VpnPlugin] / [PacketTunnelProvider] via NEVPNTunnelManager.
class IosVpnService {
  static const _channel = MethodChannel('dev.forge.vpn/vpn_service');

  static IosVpnService? _instance;
  factory IosVpnService() => _instance ??= IosVpnService._();

  IosVpnService._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  VpnStatusCallback? onStatus;
  VpnLogCallback? onLog;

  /// VPN permission on iOS is managed by the provisioning profile.
  /// No runtime dialog like Android — entitlement is compile-time.
  bool get hasPermission => true;

  /// Request VPN permission — no-op on iOS (entitlement-based).
  Future<bool> requestPermission() async => true;

  /// Start the VPN with the given sing-box configuration.
  Future<bool> connect(String configJson) async {
    try {
      final result = await _channel.invokeMethod<bool>('connect', {
        'config': configJson,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      onStatus?.call('error', e.message ?? 'Connection failed');
      return false;
    }
  }

  /// Stop the VPN.
  Future<bool> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Check if the VPN service is currently running.
  Future<bool> isRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onStatus':
        final args = call.arguments as Map<dynamic, dynamic>;
        final status = args['status'] as String? ?? '';
        final message = args['message'] as String? ?? '';
        onStatus?.call(status, message);
        break;
      case 'onLog':
        final line = call.arguments as String? ?? '';
        onLog?.call(line);
        break;
      default:
        throw MissingPluginException();
    }
  }
}
