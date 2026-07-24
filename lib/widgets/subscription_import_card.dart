import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_provider.dart';
import 'responsive.dart';

/// Subscription URL input shared by the dashboard and the legacy Nodes page.
class SubscriptionImportCard extends StatefulWidget {
  const SubscriptionImportCard({super.key});

  @override
  State<SubscriptionImportCard> createState() => _SubscriptionImportCardState();
}

class _SubscriptionImportCardState extends State<SubscriptionImportCard> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isExpanded = true;
  String _lastSubscriptionUrl = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  Future<void> _import(AppProvider provider, AppLocalizations l10n) async {
    _dismissKeyboard();
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    try {
      await provider.importSubscription(url);
      if (!mounted) return;
      setState(() => _isExpanded = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.importedSuccessfully),
        backgroundColor: const Color(0xFF21B892),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.importFailed(e.toString())),
        backgroundColor: const Color(0xFFE15D52),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final l10n = AppLocalizations.of(context);
        if (provider.subscriptionUrl.isNotEmpty &&
            provider.subscriptionUrl != _lastSubscriptionUrl) {
          _isExpanded = false;
        }
        _lastSubscriptionUrl = provider.subscriptionUrl;
        if (_controller.text != provider.subscriptionUrl &&
            provider.subscriptionUrl.isNotEmpty) {
          _controller.text = provider.subscriptionUrl;
        }

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
              InkWell(
                key: const Key('subscription-import-toggle'),
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.subscriptionUrl,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _import(provider, l10n),
                  onTapOutside: (_) => _dismissKeyboard(),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    hintStyle: TextStyle(color: Colors.grey[700]),
                    filled: true,
                    fillColor: Responsive.bgColor,
                    border: _border(),
                    enabledBorder: _border(),
                    focusedBorder: _border(const Color(0xFF21B892)),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFFEEF3F8)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _import(provider, l10n),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF21B892),
                      foregroundColor: const Color(0xFF062019),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(l10n.importAction,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  OutlineInputBorder _border([Color color = const Color(0xFF2D3643)]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );
  }
}
