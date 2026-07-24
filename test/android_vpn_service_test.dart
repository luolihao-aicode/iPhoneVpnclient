import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_vpn_flutter/services/android_vpn_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.forge.vpn/vpn_service');

  Future<void> sendPlatformCall(String method, dynamic arguments) async {
    final completer = Completer<void>();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec()
          .encodeMethodCall(MethodCall(method, arguments)),
      (_) => completer.complete(),
    );
    await completer.future;
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('keeps the shared event handler while awaiting permission', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'requestPermission') {
        await sendPlatformCall('onLog', 'permission screen opened');
        await sendPlatformCall('onStatus', {
          'status': 'permission_granted',
          'message': '',
        });
        return true;
      }
      return false;
    });

    final service = AndroidVpnService();
    final logs = <String>[];
    service.onLog = logs.add;

    final permission = service.requestPermission();

    expect(await permission, isTrue);
    expect(logs, ['permission screen opened']);
  });

  test('restores permission and running state from the native bridge',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getState') {
        return {
          'status': 'connected',
          'message': 'Restored native service state',
          'permissionGranted': true,
        };
      }
      if (call.method == 'isRunning') return true;
      return false;
    });

    final service = AndroidVpnService();
    final statuses = <String>[];
    service.onStatus = (status, _) => statuses.add(status);

    await service.restoreState();

    expect(service.hasPermission, isTrue);
    expect(await service.isRunning(), isTrue);
    expect(statuses, contains('connected'));
  });

  test('requests diagnostics through the Android bridge', () async {
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'diagnose') {
        called = true;
        return {'platform': 'android', 'abi': 'x86_64'};
      }
      return false;
    });

    final diagnostics = await AndroidVpnService().diagnose();

    expect(called, isTrue);
    expect(diagnostics['platform'], 'android');
    expect(diagnostics['abi'], 'x86_64');
  });
}
