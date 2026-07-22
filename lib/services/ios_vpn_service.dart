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
  bool _running = false;

  /// Request VPN permission — no-op on iOS (entitlement-based).
  Future<bool> requestPermission() async => true;

  /// Restore the system Packet Tunnel state after Flutter initialization.
  Future<void> restoreState() async {
    try {
      final result = await _channel.invokeMethod<Map>('getState');
      final state = Map<String, dynamic>.from(result ?? const {});
      final status = state['status'] as String? ?? 'idle';
      final message = state['message'] as String? ?? '';
      _running = status == 'connected';
      if (status != 'idle') onStatus?.call(status, message);
    } on PlatformException catch (e) {
      final message = e.message ?? 'Unable to restore VPN state';
      onLog?.call('[error] state restore failed: $message');
      onStatus?.call('error', message);
    } on MissingPluginException catch (e) {
      onLog?.call('[error] VpnPlugin not registered: $e');
    } catch (e) {
      onLog?.call('[error] state restore unexpected: $e');
    }
  }

  /// Start the VPN with the given sing-box configuration.
  Future<bool> connect(String configJson) async {
    try {
      final result = await _channel.invokeMethod<bool>('connect', {
        'config': configJson,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      final msg = e.message ?? 'Connection failed';
      onLog?.call('[error] connect failed: code=${e.code}, message=$msg');
      onStatus?.call('error', msg);
      return false;
    } on MissingPluginException catch (e) {
      onLog?.call('[error] VpnPlugin not registered: $e');
      onStatus?.call('error', 'VpnPlugin not registered in AppDelegate');
      return false;
    } catch (e) {
      onLog?.call('[error] connect unexpected: $e');
      onStatus?.call('error', e.toString());
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
      _running = result ?? false;
      return _running;
    } catch (_) {
      return false;
    }
  }

  /// Diagnose VPN configuration status (iOS only).
  Future<Map<String, dynamic>> diagnose() async {
    try {
      final result = await _channel.invokeMethod<Map>('diagnose');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onStatus':
        final args = call.arguments as Map<dynamic, dynamic>;
        final status = args['status'] as String? ?? '';
        final message = args['message'] as String? ?? '';
        _running = status == 'connected';
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
