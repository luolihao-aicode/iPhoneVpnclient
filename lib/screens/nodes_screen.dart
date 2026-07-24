import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../core/models/node.dart';
import '../widgets/responsive.dart';
import '../l10n/app_localizations.dart';
import '../l10n/node_type_localization.dart';
import '../widgets/subscription_import_card.dart';

class NodesScreen extends StatefulWidget {
  const NodesScreen({super.key});

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final l10n = AppLocalizations.of(context);
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: Responsive.screenPadding(context),
            child: Column(
              children: [
                const SubscriptionImportCard(),

                const SizedBox(height: 16),

                // Node list
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Responsive.surfaceColor,
                    borderRadius:
                        BorderRadius.circular(Responsive.cardRadius(context)),
                    border: Border.all(color: Responsive.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(l10n.nodes,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEEF3F8))),
                          const Spacer(),
                          Text(l10n.totalCount(provider.nodes.length),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (provider.nodes.isEmpty)
                        Container(
                          height: 80,
                          alignment: Alignment.center,
                          child: Text(l10n.noNodesPasteUrl,
                              style: TextStyle(color: Colors.grey[600])),
                        )
                      else
                        ...provider.nodes.map((node) => _NodeTile(
                              node: node,
                              selected: node.id == provider.selectedNodeId,
                              onTap: () => provider.selectNode(node.id),
                              onDoubleTap: () async {
                                provider.selectNode(node.id);
                                try {
                                  await provider.connect();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                }
                              },
                            )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NodeTile extends StatelessWidget {
  final VpnNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _NodeTile({
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Responsive.bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected ? const Color(0xFF21B892) : Responsive.borderColor,
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
                    Text(
                        '${node.type.localizedLabel(l10n)} · ${node.server}:${node.port}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              const Spacer(),
              _NodeStatusBadge(
                  node: node, selected: selected, connected: false),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status badge matching desktop template:
///   Connected (green) | Selected (blue) | Ready (default)
class _NodeStatusBadge extends StatelessWidget {
  final VpnNode node;
  final bool selected;
  final bool connected;

  const _NodeStatusBadge({
    required this.node,
    required this.selected,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo(AppLocalizations.of(context));
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

  ({String label, Color bg, Color fg}) _statusInfo(AppLocalizations l10n) {
    if (connected && selected) {
      return (
        label: l10n.connected,
        bg: const Color(0xFF21B892).withValues(alpha: 0.18),
        fg: const Color(0xFFBDFFED),
      );
    }
    if (selected) {
      return (
        label: l10n.selected,
        bg: const Color(0xFF5D8CFF).withValues(alpha: 0.22),
        fg: const Color(0xFFDCE8FF),
      );
    }
    return (
      label: l10n.ready,
      bg: const Color(0xFF5D8CFF).withValues(alpha: 0.16),
      fg: const Color(0xFFCFE6FF),
    );
  }
}
