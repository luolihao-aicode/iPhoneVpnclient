import 'dart:convert';

import 'models/node.dart';

/// Encode imported nodes for local persistence.
String encodeNodes(List<VpnNode> nodes) {
  return jsonEncode(nodes.map((node) => node.toJson()).toList());
}

/// Decode persisted nodes, ignoring malformed entries instead of blocking app startup.
List<VpnNode> decodeNodes(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((entry) => VpnNode.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  } catch (_) {
    return [];
  }
}
