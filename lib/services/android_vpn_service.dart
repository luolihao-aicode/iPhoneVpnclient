import 'dart:async';
import 'package:flutter/services.dart';

/// Callbacks for Android VPN service events.
typedef VpnStatusCallback = void Function(String status, String message);
typedef VpnLogCallback = void Function(String line);

/// MethodChannel wrapper for the Android VpnService.
///
/// Channels bridge between Flutter (Dart) and the Android native
/// [ForgeVpnService] / [VpnBridge] in Kotlin.
class AndroidVpnService {
  static const _channel = MethodChannel('dev.forge.vpn/vpn_service');

  static AndroidVpnService? _instance;
  factory AndroidVpnService() => _instance ??= AndroidVpnService._();

  AndroidVpnService._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  VpnStatusCallback? onStatus;
  VpnLogCallback? onLog;

  /// Whether the VPN permission has been granted.
  bool _permissionGranted = false;
  bool _running = false;
  Completer<bool>? _permissionRequest;
  bool get hasPermission => _permissionGranted;

  /// Request VPN permission from the user.
  Future<bool> requestPermission() async {
    if (_permissionGranted) return true;
    if (_permissionRequest != null) return _permissionRequest!.future;

    try {
      final request = Completer<bool>();
      _permissionRequest = request;
      final accepted = await _channel.invokeMethod<bool>('requestPermission');
      if (accepted != true) {
        _completePermissionRequest(false);
      }
      return await request.future;
    } catch (e) {
      _completePermissionRequest(false);
      onLog?.call('[error] permission request failed: $e');
      onStatus?.call('error', e.toString());
      return false;
    }
  }

  /// Restore the cached native service state after Flutter initialization.
  Future<void> restoreState() async {
    try {
      final result = await _channel.invokeMethod<Map>('getState');
      final state = Map<String, dynamic>.from(result ?? const {});
      _permissionGranted = state['permissionGranted'] == true;
      final status = state['status'] as String? ?? 'idle';
      _running = status == 'connected';
      final message = state['message'] as String? ?? '';
      if (status != 'idle') onStatus?.call(status, message);
    } on PlatformException catch (e) {
      final message = e.message ?? 'Unable to restore VPN state';
      onLog?.call('[error] state restore failed: $message');
      onStatus?.call('error', message);
    } on MissingPluginException catch (e) {
      onLog?.call('[error] VpnBridge not registered: $e');
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
      _running = result ?? false;
      return _running;
    } catch (_) {
      return false;
    }
  }

  /// Return native Android VPN and sing-box asset diagnostics.
  Future<Map<String, dynamic>> diagnose() async {
    try {
      final result = await _channel.invokeMethod<Map>('diagnose');
      return Map<String, dynamic>.from(result ?? const {});
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
        if (status == 'permission_granted') {
          _permissionGranted = true;
          _completePermissionRequest(true);
        } else if (status == 'permission_denied') {
          _permissionGranted = false;
          _completePermissionRequest(false);
        }
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

  void _completePermissionRequest(bool granted) {
    final request = _permissionRequest;
    if (request != null && !request.isCompleted) request.complete(granted);
    _permissionRequest = null;
  }
}
