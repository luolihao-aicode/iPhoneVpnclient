import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../core/models/node.dart';
import '../core/node_latency.dart';
import '../widgets/responsive.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final node = provider.selectedNode;
        final rt = provider.runtime;
        final isSwitching = provider.isSwitching;

        return SingleChildScrollView(
          padding: Responsive.screenPadding(context),
          child: Column(
            children: [
              _StatusCard(
                node: node,
                runtime: rt,
                isSwitching: isSwitching,
                onToggle: () async {
                  if (isSwitching) return;
                  if (rt.connected) {
                    await provider.disconnect();
                  } else {
                    try {
                      await provider.connect();
                    } catch (e) {
                      _err(context, e.toString());
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              _MetricsRow(rt: rt, node: node),
              const SizedBox(height: 12),
              _ServerTable(
                nodes: nodes,
                selectedId: provider.selectedNodeId,
                connected: rt.connected,
                checkingNodes: rt.checkingNodes,
                availableCount: availableCount,
                onSelect: (id) => provider.selectNode(id),
                onDoubleTap: (id) async {
                  provider.selectNode(id);
                  try {
                    await provider.connect();
                  } catch (e) {
                    _err(context, e.toString());
                  }
                },
                onCheckAll: () async {
                  if (rt.checkingNodes) return;
                  await provider.checkAllNodes();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _err(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE15D52)),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final VpnNode? node;
  final dynamic runtime;
  final bool isSwitching;
  final VoidCallback onToggle;

  const _StatusCard({
    required this.node,
    required this.runtime,
    required this.isSwitching,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final connected = runtime.connected;
    final radius = Responsive.cardRadius(context);
    final pad = Responsive.cardPadding(context);

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: connected
              ? [const Color(0xFF21B892).withValues(alpha: 0.1), Responsive.bgColor]
              : [const Color(0xFF1D2530), Responsive.bgColor],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: connected
              ? const Color(0xFF21B892).withValues(alpha: 0.3)
              : Responsive.borderColor,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node?.name ?? 'No node selected',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEEF3F8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      node != null
                          ? '${node!.type.label} · ${node!.server}:${node!.port}'
                          : 'Import a subscription first.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: isSwitching || node == null ? null : onToggle,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? const Color(0xFFE15D52) : const Color(0xFF21B892),
                    boxShadow: [
                      BoxShadow(
                        color: (connected ? const Color(0xFFE15D52) : const Color(0xFF21B892))
                            .withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      connected ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: connected ? Colors.white : const Color(0xFF062019),
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (runtime.proxyWarning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(runtime.proxyWarning,
                  style: const TextStyle(color: Color(0xFFFFBAB4), fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final dynamic rt;
  final VpnNode? node;

  const _MetricsRow({required this.rt, required this.node});

  String _fmt(int v) {
    if (v < 1024) return '$v B/s';
    if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB/s';
    return '${(v / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }

  String _lat() {
    final l = node?.latencyMs;
    if (l != null && l > 0) return '$l ms';
    if (node?.healthStatus == HealthStatus.checking) return '...';
    return '--';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MCard(label: 'Ping', value: _lat()),
        const SizedBox(width: 8),
        _MCard(label: 'Download', value: _fmt(rt.downSpeed)),
        const SizedBox(width: 8),
        _MCard(label: 'Upload', value: _fmt(rt.upSpeed)),
      ],
    );
  }
}

class _MCard extends StatelessWidget {
  final String label;
  final String value;
  const _MCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Responsive.surfaceColor,
          borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
          border: Border.all(color: Responsive.borderColor),
        ),
        child: Column(
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEEF3F8))),
          ],
        ),
      ),
    );
  }
}

/// Full-width server table matching the desktop template:
/// Columns: Node | Protocol | Endpoint | Ping | Available | Status
class _ServerTable extends StatelessWidget {
  final List<VpnNode> nodes;
  final String selectedId;
  final bool connected;
  final bool checkingNodes;
  final int availableCount;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDoubleTap;
  final VoidCallback onCheckAll;

  const _ServerTable({
    required this.nodes,
    required this.selectedId,
    required this.connected,
    required this.checkingNodes,
    required this.availableCount,
    required this.onSelect,
    required this.onDoubleTap,
    required this.onCheckAll,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = Responsive.isPhone(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Responsive.surfaceColor,
        borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
        border: Border.all(color: Responsive.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading: "Subscription servers" + Check button + available count
          Row(
            children: [
              const Text('Subscription servers',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEEF3F8))),
              const Spacer(),
              SizedBox(
                height: 30,
                child: TextButton(
                  onPressed: checkingNodes || nodes.isEmpty ? null : onCheckAll,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEEF3F8),
                    backgroundColor: const Color(0xFF1D2530),
                    side: const BorderSide(color: Color(0xFF2D3643)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    checkingNodes ? 'Checking' : 'Check',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$availableCount available',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Empty state
          if (nodes.isEmpty)
            Container(
              height: 86,
              alignment: Alignment.center,
              child: Text('No subscription servers',
                  style: TextStyle(color: Colors.grey[600])),
            )
          else
            isPhone
                ? _PhoneNodeList(
                    nodes: nodes,
                    selectedId: selectedId,
                    connected: connected,
                    onSelect: onSelect,
                    onDoubleTap: onDoubleTap,
                  )
                : _TableNodeList(
                    nodes: nodes,
                    selectedId: selectedId,
                    connected: connected,
                    onSelect: onSelect,
                    onDoubleTap: onDoubleTap,
                  ),
        ],
      ),
    );
  }
}

// ── Tablet/Desktop: full grid table ──────────────────────────────
class _TableNodeList extends StatelessWidget {
  final List<VpnNode> nodes;
  final String selectedId;
  final bool connected;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDoubleTap;

  const _TableNodeList({
    required this.nodes,
    required this.selectedId,
    required this.connected,
    required this.onSelect,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Responsive.borderColor),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF10161F),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header row
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF121923),
              border: Border(bottom: BorderSide(color: Color(0xFF2D3643))),
            ),
            child: _buildHeader(),
          ),
          // Body
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: nodes.length,
              itemBuilder: (_, i) => _buildRow(context, nodes[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _col('Node', flex: 14),
        _col('Protocol', width: 104),
        _col('Endpoint', flex: 12),
        _col('Ping', width: 90),
        _col('Available', width: 104),
        _col('Status', width: 102),
      ],
    );
  }

  Widget _col(String label, {double? width, int? flex}) {
    final widget = Text(label,
        style: TextStyle(fontSize: 12, color: Colors.grey[500]));
    if (flex != null) {
      return Expanded(flex: flex, child: widget);
    }
    return SizedBox(width: width, child: widget);
  }

  Widget _buildRow(BuildContext context, VpnNode node) {
    final isSelected = node.id == selectedId;
    final isActive = connected && isSelected;
    final avail = _availabilityInfo(node);

    Color bgColor;
    if (isSelected && connected) {
      bgColor = const Color(0xFF21B892).withValues(alpha: 0.08);
    } else if (isSelected) {
      bgColor = const Color(0xFF21B892).withValues(alpha: 0.04);
    } else if (node.healthStatus == HealthStatus.available) {
      bgColor = const Color(0xFF21B892).withValues(alpha: 0.035);
    } else if (node.healthStatus == HealthStatus.unavailable) {
      bgColor = const Color(0xFFE15D52).withValues(alpha: 0.045);
    } else {
      bgColor = Colors.transparent;
    }

    return GestureDetector(
      onTap: () => onSelect(node.id),
      onDoubleTap: () => onDoubleTap(node.id),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(
              color: Responsive.borderColor.withValues(alpha: 0.6),
            ),
            left: BorderSide(
              color: isSelected
                  ? Responsive.accent
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Node name
            Expanded(
              flex: 14,
              child: Text(
                node.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEEF3F8)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Protocol pill
            SizedBox(
              width: 104,
              child: Container(
                constraints: const BoxConstraints(minWidth: 72),
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF5D8CFF).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  node.type.label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFDCE8FF)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Endpoint
            Expanded(
              flex: 12,
              child: Text(
                '${node.server}:${node.port}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Ping
            SizedBox(
              width: 90,
              child: Text(
                _latencyText(node),
                style: TextStyle(
                  fontSize: 13,
                  color: node.healthStatus == HealthStatus.available &&
                          node.latencyMs != null
                      ? const Color(0xFF21B892)
                      : Colors.grey[500],
                ),
              ),
            ),
            // Available pill
            SizedBox(
              width: 104,
              child: _AvailabilityPill(node: node, avail: avail),
            ),
            // Status pill
            SizedBox(
              width: 102,
              child: _StatusPill(
                node: node,
                isSelected: isSelected,
                isActive: isActive,
                connected: connected,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _latencyText(VpnNode node) {
    final l = node.latencyMs;
    if (l != null && l > 0) return '$l ms';
    if (node.healthStatus == HealthStatus.checking) return '...';
    return '--';
  }

  ({String text, String className}) _availabilityInfo(VpnNode node) {
    switch (node.healthStatus) {
      case HealthStatus.available:
        return (text: 'Yes', className: 'available');
      case HealthStatus.unavailable:
        return (text: 'No', className: 'unavailable');
      case HealthStatus.checking:
        return (text: 'Checking', className: 'checking');
      case HealthStatus.unknown:
        return (text: 'Unknown', className: 'unknown');
    }
  }
}

// ── Phone: simplified card list ──────────────────────────────────
class _PhoneNodeList extends StatelessWidget {
  final List<VpnNode> nodes;
  final String selectedId;
  final bool connected;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDoubleTap;

  const _PhoneNodeList({
    required this.nodes,
    required this.selectedId,
    required this.connected,
    required this.onSelect,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: nodes.map((node) => _NodeRow(
        node: node,
        selected: node.id == selectedId,
        connected: connected,
        onTap: () => onSelect(node.id),
        onDoubleTap: () => onDoubleTap(node.id),
      )).toList(),
    );
  }
}

class _NodeRow extends StatelessWidget {
  final VpnNode node;
  final bool selected;
  final bool connected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _NodeRow({
    required this.node,
    required this.selected,
    required this.connected,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = connected && selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1D2530),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Responsive.accent : Responsive.borderColor,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEEF3F8))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('${node.type.label} · ${node.server}:${node.port}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                        const SizedBox(width: 8),
                        Text(
                          _latencyText(node),
                          style: TextStyle(
                            fontSize: 12,
                            color: node.latencyMs != null && node.latencyMs! > 0
                                ? const Color(0xFF21B892)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StatusPill(
                node: node,
                isSelected: selected,
                isActive: isActive,
                connected: connected,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _latencyText(VpnNode node) {
    final l = node.latencyMs;
    if (l != null && l > 0) return '${l}ms';
    if (node.healthStatus == HealthStatus.checking) return '...';
    return '--';
  }
}

// ── Availability pill ────────────────────────────────────────────
class _AvailabilityPill extends StatelessWidget {
  final VpnNode node;
  final ({String text, String className}) avail;
  const _AvailabilityPill({required this.node, required this.avail});

  Color _bg() {
    switch (node.healthStatus) {
      case HealthStatus.available:
        return const Color(0xFF21B892).withValues(alpha: 0.2);
      case HealthStatus.unavailable:
        return const Color(0xFFE15D52).withValues(alpha: 0.18);
      case HealthStatus.checking:
        return const Color(0xFFE5A63D).withValues(alpha: 0.17);
      case HealthStatus.unknown:
        return Colors.grey.withValues(alpha: 0.12);
    }
  }

  Color _fg() {
    switch (node.healthStatus) {
      case HealthStatus.available:
        return const Color(0xFFBDFFED);
      case HealthStatus.unavailable:
        return const Color(0xFFFFBAB4);
      case HealthStatus.checking:
        return const Color(0xFFFFE1AD);
      case HealthStatus.unknown:
        return Colors.grey[500]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _bg(),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        avail.text,
        style: TextStyle(fontSize: 12, color: _fg()),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Status pill ──────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final VpnNode node;
  final bool isSelected;
  final bool isActive;
  final bool connected;

  const _StatusPill({
    required this.node,
    required this.isSelected,
    required this.isActive,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo();
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: info.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        info.label,
        style: TextStyle(fontSize: 12, color: info.fg),
        textAlign: TextAlign.center,
      ),
    );
  }

  ({String label, Color bg, Color fg}) _statusInfo() {
    if (isActive) {
      return (
        label: 'Connected',
        bg: const Color(0xFF21B892).withValues(alpha: 0.18),
        fg: const Color(0xFFBDFFED),
      );
    }
    if (isSelected) {
      return (
        label: 'Selected',
        bg: const Color(0xFF5D8CFF).withValues(alpha: 0.22),
        fg: const Color(0xFFDCE8FF),
      );
    }
    return (
      label: 'Ready',
      bg: const Color(0xFF5D8CFF).withValues(alpha: 0.16),
      fg: const Color(0xFFCFE6FF),
    );
  }
}
