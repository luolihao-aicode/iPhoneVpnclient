import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../core/models/node.dart';
import '../widgets/responsive.dart';

class NodesScreen extends StatefulWidget {
  const NodesScreen({super.key});

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (_urlController.text != provider.subscriptionUrl &&
            provider.subscriptionUrl.isNotEmpty) {
          _urlController.text = provider.subscriptionUrl;
        }

        return SingleChildScrollView(
          padding: Responsive.screenPadding(context),
          child: Column(
            children: [
              // Subscription input
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
                    Text('Subscription URL',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        hintStyle: TextStyle(color: Colors.grey[700]),
                        filled: true,
                        fillColor: Responsive.bgColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF2D3643)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF2D3643)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF21B892)),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      style: const TextStyle(fontSize: 14, color: Color(0xFFEEF3F8)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final url = _urlController.text.trim();
                          if (url.isEmpty) return;
                          try {
                            await provider.importSubscription(url);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Imported successfully'),
                                  backgroundColor: Color(0xFF21B892),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Import failed: $e'),
                                    backgroundColor: const Color(0xFFE15D52)),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF21B892),
                          foregroundColor: const Color(0xFF062019),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Import',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

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
                        const Text('Nodes',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEEF3F8))),
                        const Spacer(),
                        Text('${provider.nodes.length} total',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (provider.nodes.isEmpty)
                      Container(
                        height: 80,
                        alignment: Alignment.center,
                        child: Text('No nodes. Paste URL & import above.',
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
              color: selected
                  ? const Color(0xFF21B892)
                  : Responsive.borderColor,
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
                        '${node.type.label} · ${node.server}:${node.port}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF21B892).withValues(alpha: 0.18)
                      : const Color(0xFF5D8CFF).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  selected ? 'Selected' : 'Tap',
                  style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? const Color(0xFFBDFFED)
                        : const Color(0xFFCFE6FF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
