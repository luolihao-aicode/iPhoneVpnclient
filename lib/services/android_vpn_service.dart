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
  bool get hasPermission => _permissionGranted;

  /// Request VPN permission from the user.
  Future<bool> requestPermission() async {
    if (_permissionGranted) return true;

    try {
      final completer = Completer<bool>();
      // Listen for the permission result callback
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onStatus') {
          final args = call.arguments as Map<dynamic, dynamic>;
          if (args['status'] == 'permission_granted') {
            _permissionGranted = true;
            completer.complete(true);
          } else if (args['status'] == 'permission_denied') {
            completer.complete(false);
          }
        }
        return _handleMethodCall(call);
      });

      // The Kotlin side handles the permission intent
      await _channel.invokeMethod('requestPermission');
      return await completer.future;
    } catch (e) {
      return false;
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
        if (status == 'permission_granted') {
          _permissionGranted = true;
        }
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
