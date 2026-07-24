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

  test('iOS Tunnel 用新版 CommandServer 启动核心但不启动受限的命令 Socket', () {
    final source = File('ios/Runner/PacketTunnelProvider.swift').readAsStringSync();

    expect(source, contains('private var commandServer: LibboxCommandServer?'));
    expect(source, contains('LibboxCommandServer(self, platformInterface: platformInterface)'));
    expect(source, contains('startOrReloadService'));
    expect(source, contains('Do not call server.start()'));
  });

  test('iOS 主应用监听系统 Tunnel 状态并避免重复启动', () {
    final source = File('ios/Runner/VpnPlugin.swift').readAsStringSync();

    expect(source, contains('Notification.Name.NEVPNStatusDidChange'));
    expect(source, contains('vpnStatusDidChange'));
    expect(source, contains('case .connected, .connecting, .reasserting:'));
  });

  test('iOS Tunnel 向新版 libbox 提供真实默认网络接口', () {
    final source =
        File('ios/Runner/LibboxPlatformInterface.swift').readAsStringSync();

    expect(source, contains('import Network'));
    expect(source, contains('func usePlatformDefaultInterfaceMonitor() -> Bool { true }'));
    expect(source, contains('NWPathMonitor()'));
    expect(source, contains('isExpensive:'));
    expect(source, contains('isConstrained:'));
  });

  test('iOS 诊断会读取运行中 Tunnel 的内部日志', () {
    final source = File('ios/Runner/VpnPlugin.swift').readAsStringSync();

    expect(source, contains('sendProviderMessage'));
    expect(source, contains('providerDiagnostics'));
    expect(source, contains('providerLogs'));
  });

  test('iOS Tunnel routes normal DNS through the proxy', () {
    final source = File('ios/Runner/PacketTunnelProvider.swift').readAsStringSync();

    expect(source, contains('private func proxyDNSConfiguration'));
    expect(source, contains('dns["final"] = "remote"'));
    expect(source, contains(r'$0 != "1.1.1.1/32"'));
  });

  test('iOS Tunnel uses the v1.13 DNS hijack route action', () {
    final source = File('ios/Runner/PacketTunnelProvider.swift').readAsStringSync();

    expect(source, contains('"action": "hijack-dns", "port": [53]'));
    expect(source, isNot(contains('"type": "dns", "tag": "ios-dns"')));
  });
}
