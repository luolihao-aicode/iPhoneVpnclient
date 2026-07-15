import 'node_health.dart';
import 'models/node.dart';

/// Sort nodes by latency: available → checking → unknown → unavailable.
List<VpnNode> sortNodesByLatency(List<VpnNode> nodes) {
  final sorted = List<VpnNode>.from(nodes);
  sorted.sort((a, b) {
    final aRank = _latencyRank(a);
    final bRank = _latencyRank(b);
    if (aRank.bucket != bRank.bucket) return aRank.bucket.compareTo(bRank.bucket);
    if (aRank.value != bRank.value) return aRank.value.compareTo(bRank.value);
    return 0;
  });
  return sorted;
}

int countAvailableNodes(List<VpnNode> nodes) {
  return nodes.where((n) => n.healthStatus == HealthStatus.available).length;
}

({int bucket, int value}) _latencyRank(VpnNode node) {
  final value = node.latencyMs;
  if (node.healthStatus == HealthStatus.available && value != null && value > 0) {
    return (bucket: 0, value: value);
  }
  if (node.healthStatus == HealthStatus.checking) {
    return (bucket: 1, value: 0);
  }
  if (value != null && value > 0) return (bucket: 2, value: value);
  if (node.healthStatus == HealthStatus.unavailable) return (bucket: 4, value: 0);
  return (bucket: 3, value: 0);
}

/// Prepare nodes for latency testing by resetting their health status.
List<VpnNode> prepareNodesForLatencyTest(List<VpnNode> nodes) {
  return nodes.map((node) {
    return node.copyWith(
      latencyMs: null,
      healthStatus: HealthStatus.checking,
    );
  }).toList();
}

/// Update a single node's latency after a health check.
List<VpnNode> updateNodeLatency(List<VpnNode> nodes, String nodeId, HealthCheckResult result) {
  return nodes.map((node) {
    if (node.id != nodeId) return node;
    if (result.ok && result.latency != null && result.latency! > 0) {
      return node.copyWith(
        latencyMs: result.latency,
        healthStatus: HealthStatus.available,
        healthTarget: result.target,
        latencyCheckedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return node.copyWith(
      latencyMs: null,
      healthStatus: HealthStatus.unavailable,
      healthError: result.error,
      latencyCheckedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }).toList();
}
