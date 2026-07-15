import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/responsive.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;
        final connected = provider.runtime.connected;

        return ListView(
          padding: Responsive.screenPadding(context),
          children: [
            _GroupHeader(title: 'Connection'),
            const SizedBox(height: 8),
            _Card(
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.language,
                    title: 'Route mode',
                    trailing: DropdownButton<String>(
                      value: settings.routeMode,
                      underline: const SizedBox(),
                      dropdownColor: const Color(0xFF161B22),
                      style: const TextStyle(
                          color: Color(0xFFEEF3F8), fontSize: 14),
                      items: const [
                        DropdownMenuItem(
                            value: 'global', child: Text('Global proxy')),
                        DropdownMenuItem(
                            value: 'rule', child: Text('Smart split')),
                      ],
                      onChanged: connected
                          ? null
                          : (v) => provider.saveSettings(
                              settings.copyWith(routeMode: v)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _GroupHeader(title: 'About'),
            const SizedBox(height: 8),
            _Card(
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.info_outline,
                    title: 'Version',
                    trailing: const Text('0.1.0',
                        style: TextStyle(color: Color(0xFF8B949E))),
                  ),
                  const Divider(color: Color(0xFF2D3643), height: 1),
                  _SettingRow(
                    icon: Icons.code,
                    title: 'Engine',
                    trailing: const Text('sing-box',
                        style: TextStyle(color: Color(0xFF8B949E))),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              letterSpacing: 1)),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Responsive.surfaceColor,
        borderRadius:
            BorderRadius.circular(Responsive.cardRadius(context)),
        border: Border.all(color: Responsive.borderColor),
      ),
      child: child,
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Color(0xFFEEF3F8), fontSize: 14)),
          ),
          trailing,
        ],
      ),
    );
  }
}
