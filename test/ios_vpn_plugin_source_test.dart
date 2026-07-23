import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('保存 Packet Tunnel 配置后重新加载再启动', () {
    final source = File('ios/Runner/VpnPlugin.swift').readAsStringSync();
    final saveIndex = source.indexOf('try await manager.saveToPreferences()');
    final reloadIndex = source.indexOf('try await manager.loadFromPreferences()');
    final startIndex = source.indexOf('try manager.connection.startVPNTunnel');

    expect(saveIndex, isNonNegative);
    expect(reloadIndex, greaterThan(saveIndex));
    expect(startIndex, greaterThan(reloadIndex));
  });

  test('优先使用系统 Packet Flow 的 TUN 描述符', () {
    final source =
        File('ios/Runner/LibboxPlatformInterface.swift').readAsStringSync();
    final packetFlowIndex = source.indexOf('socket.fileDescriptor');
    final libboxFallbackIndex = source.indexOf('LibboxGetTunnelFileDescriptor()');

    expect(packetFlowIndex, isNonNegative);
    expect(libboxFallbackIndex, greaterThan(packetFlowIndex));
  });

  test('iOS Tunnel 不启动受沙盒限制的 libbox 命令 Socket', () {
    final source = File('ios/Runner/PacketTunnelProvider.swift').readAsStringSync();

    expect(source, contains('Do not start libbox\'s optional CommandServer'));
    expect(source, isNot(contains('LibboxNewCommandServer(')));
    expect(source, isNot(contains('private var commandServer')));
    expect(source, isNot(contains('commandServer.')));
  });
}
