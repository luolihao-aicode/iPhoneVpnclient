import 'models/node.dart';

/// A stable region bucket used by the node list UI.
class NodeRegionGroup {
  final String regionCode;
  final List<VpnNode> nodes;

  const NodeRegionGroup({required this.regionCode, required this.nodes});
}

/// Groups nodes by the leading code in their display name.
///
/// A name such as `HKG-hk-vip-2` belongs to `HKG`. Names without a
/// letter/number prefix followed by `-` are placed in `OTHER`. Both the
/// groups and the nodes inside each group retain their source order.
List<NodeRegionGroup> groupNodesByRegion(List<VpnNode> nodes) {
  final grouped = <String, List<VpnNode>>{};
  final order = <String>[];

  for (final node in nodes) {
    final region = extractNodeRegion(node.name);
    if (!grouped.containsKey(region)) {
      grouped[region] = <VpnNode>[];
      order.add(region);
    }
    grouped[region]!.add(node);
  }

  return [
    for (final region in order)
      NodeRegionGroup(regionCode: region, nodes: List.unmodifiable(grouped[region]!)),
  ];
}

String extractNodeRegion(String name) {
  final normalized = name.trim();
  final match = RegExp(r'^([A-Za-z][A-Za-z0-9]*)-').firstMatch(normalized);
  if (match != null) return _canonicalRegion(match.group(1)!);

  final lower = normalized.toLowerCase();
  const countryNames = <String, String>{
    'hong kong': 'HKG',
    'macau': 'MAC',
    'macao': 'MAC',
    'singapore': 'SGP',
    'south korea': 'KOR',
    'korea': 'KOR',
    'japan': 'JPN',
    'united states': 'USA',
    'usa': 'USA',
    'canada': 'CAN',
    'united kingdom': 'GBR',
    'great britain': 'GBR',
    'uk': 'GBR',
    'germany': 'DEU',
    'france': 'FRA',
    'taiwan': 'TWN',
  };
  for (final entry in countryNames.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return 'OTHER';
}

/// Identifies provider metadata entries that look like nodes but are not
/// usable server endpoints (traffic quota, reset and expiry information).
bool isSubscriptionMetadataName(String name) {
  final value = name.trim().toLowerCase();
  return value.contains('traffic reset') ||
      value.contains('traffic used') ||
      value.contains('traffic remaining') ||
      value.contains('expire date') ||
      value.contains('expiry date') ||
      value.contains('expiration date') ||
      value.contains('剩余流量') ||
      value.contains('流量重置') ||
      value.contains('到期时间') ||
      RegExp(r'\b\d+(?:\.\d+)?\s*(?:kb|mb|gb|tb)\s*\|').hasMatch(value);
}

String _canonicalRegion(String value) {
  switch (value.toUpperCase()) {
    case 'HK':
    case 'HONGKONG':
    case 'HONG_KONG':
      return 'HKG';
    case 'SG':
    case 'SINGAPORE':
      return 'SGP';
    case 'US':
    case 'UNITEDSTATES':
      return 'USA';
    case 'JP':
    case 'JAPAN':
      return 'JPN';
    case 'KR':
    case 'KOREA':
    case 'SOUTHKOREA':
      return 'KOR';
    case 'DE':
    case 'GERMANY':
      return 'DEU';
    case 'UK':
    case 'UNITEDKINGDOM':
      return 'GBR';
    case 'TW':
    case 'TAIWAN':
      return 'TWN';
    default:
      return value.toUpperCase();
  }
}
