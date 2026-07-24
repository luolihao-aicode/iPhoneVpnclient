import 'package:flutter_test/flutter_test.dart';
import 'package:forge_vpn_flutter/core/models/node.dart';
import 'package:forge_vpn_flutter/core/node_storage.dart';

void main() {
  test('round-trips imported node fields through persistent JSON', () {
    const node = VpnNode(
      id: 'node-1',
      type: NodeType.vmess,
      name: 'Test node',
      server: 'example.com',
      port: 443,
      uuid: 'uuid-1',
      security: 'aes-128-gcm',
      alterId: 4,
      transport: 'ws',
      host: 'example.com',
      path: '/vpn',
      tls: true,
      serverName: 'example.com',
      insecure: true,
    );

    final encoded = encodeNodes([node]);
    final restored = decodeNodes(encoded);

    expect(restored, hasLength(1));
    expect(restored.single.id, node.id);
    expect(restored.single.security, node.security);
    expect(restored.single.alterId, node.alterId);
    expect(restored.single.transport, node.transport);
    expect(restored.single.insecure, node.insecure);
  });
}
