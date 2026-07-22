import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_vpn_flutter/services/ios_vpn_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.forge.vpn/vpn_service');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('restores the connected iOS tunnel state from the native bridge',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getState') {
        return {
          'status': 'connected',
          'message': 'Restored Packet Tunnel state',
          'permissionGranted': true,
        };
      }
      if (call.method == 'isRunning') return true;
      return false;
    });

    final service = IosVpnService();
    final statuses = <String>[];
    service.onStatus = (status, _) => statuses.add(status);

    await service.restoreState();

    expect(await service.isRunning(), isTrue);
    expect(statuses, contains('connected'));
  });
}
