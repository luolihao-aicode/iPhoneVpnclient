import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/responsive.dart';
import '../services/android_vpn_service.dart';
import '../services/ios_vpn_service.dart';
import '../l10n/app_localizations.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final logs = provider.runtime.logs;
        final l10n = AppLocalizations.of(context);

        return Column(
          children: [
            // Diagnostic button (iOS only)
            _DiagnosticBar(provider: provider),
            // Logs
            Expanded(
              child: Container(
                margin: Responsive.screenPadding(context),
                decoration: BoxDecoration(
                  color: Responsive.bgColor,
                  borderRadius:
                      BorderRadius.circular(Responsive.cardRadius(context)),
                  border: Border.all(color: Responsive.borderColor),
                ),
                child: logs.isEmpty
                    ? Center(
                        child: Text(l10n.noLogsYet,
                            style: TextStyle(color: Color(0xFF8B949E))))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: logs.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            logs[i],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFF8B949E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiagnosticBar extends StatelessWidget {
  final AppProvider provider;
  const _DiagnosticBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                provider.log('[diag] Running VPN diagnostics...');
                try {
                  final diag = Platform.isAndroid
                      ? await AndroidVpnService().diagnose()
                      : await IosVpnService().diagnose();
                  for (final entry in diag.entries) {
                    provider.log('[diag] ${entry.key}: ${entry.value}');
                  }
                } catch (e) {
                  provider.log('[diag] Error: $e');
                }
              },
              icon: const Icon(Icons.bug_report_outlined, size: 16),
              label: Text(AppLocalizations.of(context).checkVpn,
                  style: const TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D2530),
                foregroundColor: const Color(0xFFEEF3F8),
                side: const BorderSide(color: Color(0xFF2D3643)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
