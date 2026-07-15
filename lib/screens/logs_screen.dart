import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/responsive.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final logs = provider.runtime.logs;

        return Container(
          margin: Responsive.screenPadding(context),
          decoration: BoxDecoration(
            color: Responsive.bgColor,
            borderRadius:
                BorderRadius.circular(Responsive.cardRadius(context)),
            border: Border.all(color: Responsive.borderColor),
          ),
          child: logs.isEmpty
              ? const Center(
                  child: Text('No logs yet.',
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
        );
      },
    );
  }
}
