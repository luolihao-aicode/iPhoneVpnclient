import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../core/models/node.dart';
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
              _NodeChips(
                nodes: provider.nodes,
                selectedId: provider.selectedNodeId,
                onSelect: (id) => provider.selectNode(id),
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

class _NodeChips extends StatelessWidget {
  final List<VpnNode> nodes;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _NodeChips({
    required this.nodes,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              const Text('Nodes',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEEF3F8))),
              const Spacer(),
              Text('${nodes.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 12),
          if (nodes.isEmpty)
            Container(
              height: 60,
              alignment: Alignment.center,
              child: Text('Import a subscription first.',
                  style: TextStyle(color: Colors.grey[600])),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: nodes.length,
                separatorBuilder: (_, _2) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _NodeChip(
                  node: nodes[i],
                  selected: nodes[i].id == selectedId,
                  onTap: () => onSelect(nodes[i].id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NodeChip extends StatelessWidget {
  final VpnNode node;
  final bool selected;
  final VoidCallback onTap;

  const _NodeChip({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: Responsive.nodeChipWidth(context),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF21B892).withValues(alpha: 0.1)
              : Responsive.bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF21B892)
                : Responsive.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(node.name,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEEF3F8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(node.type.label,
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            const SizedBox(height: 2),
            Text(
              node.latencyMs != null && node.latencyMs! > 0
                  ? '${node.latencyMs} ms'
                  : '--',
              style: TextStyle(
                fontSize: 11,
                color: node.healthStatus == HealthStatus.available
                    ? const Color(0xFF21B892)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
