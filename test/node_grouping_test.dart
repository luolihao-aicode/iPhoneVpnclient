import 'package:flutter_test/flutter_test.dart';
import 'package:forge_vpn_flutter/core/models/node.dart';
import 'package:forge_vpn_flutter/core/node_grouping.dart';

VpnNode node(String id, String name) => VpnNode(
      id: id,
      type: NodeType.vmess,
      name: name,
      server: '$id.example.com',
      port: 443,
      uuid: id,
    );

void main() {
  test('groups nodes by the leading region code while preserving order', () {
    final groups = groupNodesByRegion([
      node('hkg-1', 'HKG-hk-vip-2'),
      node('sgp-1', 'SGP-sg-vip-yy'),
      node('hkg-2', 'HKG-hk-vip-3'),
    ]);

    expect(groups.map((group) => group.regionCode), ['HKG', 'SGP']);
    expect(groups[0].nodes.map((item) => item.id), ['hkg-1', 'hkg-2']);
    expect(groups[1].nodes.single.id, 'sgp-1');
  });

  test('puts names without a leading region code into the other group', () {
    final groups = groupNodesByRegion([
      node('plain', 'Best server'),
      node('usa', 'USA-us-vip-ba'),
      node('plain-2', '备用节点'),
    ]);

    expect(groups.map((group) => group.regionCode), ['OTHER', 'USA']);
    expect(groups.first.nodes.map((item) => item.id), ['plain', 'plain-2']);
  });

  test('merges scattered country-name and region-code nodes', () {
    final groups = groupNodesByRegion([
      node('hkg-1', 'HKG-hk-vip-2'),
      node('jpn-1', '🇯🇵 Japan | 02'),
      node('hkg-2', '🇭🇰 Hong Kong | 03'),
      node('kor-1', 'Korea-kr-vip-1'),
      node('kor-2', '🇰🇷 South Korea | 01'),
      node('gbr-1', '🇬🇧 Great Britain | 01'),
    ]);

    expect(groups.map((group) => group.regionCode), ['HKG', 'JPN', 'KOR', 'GBR']);
    expect(groups.first.nodes.map((item) => item.id), ['hkg-1', 'hkg-2']);
    expect(groups.last.nodes.map((item) => item.id), ['kor-1', 'kor-2']);
  });
}
