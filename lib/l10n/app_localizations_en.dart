// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Forge VPN';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get nodes => 'Nodes';

  @override
  String get settings => 'Settings';

  @override
  String get logs => 'Logs';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connecting => 'Connecting';

  @override
  String get disconnecting => 'Disconnecting';

  @override
  String get noNodeSelected => 'No node selected';

  @override
  String get importSubscriptionFirst => 'Import a subscription first.';

  @override
  String get ping => 'Ping';

  @override
  String get download => 'Download';

  @override
  String get upload => 'Upload';

  @override
  String get protocol => 'Protocol';

  @override
  String get endpoint => 'Endpoint';

  @override
  String get status => 'Status';

  @override
  String get subscriptionServers => 'Subscription servers';

  @override
  String get check => 'Check';

  @override
  String get checking => 'Checking';

  @override
  String availableCount(int count) {
    return '$count available';
  }

  @override
  String totalCount(int count) {
    return '$count total';
  }

  @override
  String get noSubscriptionServers => 'No subscription servers';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get unknown => 'Unknown';

  @override
  String get ready => 'Ready';

  @override
  String get selected => 'Selected';

  @override
  String get subscriptionUrl => 'Subscription URL';

  @override
  String get importAction => 'Import';

  @override
  String get noNodesPasteUrl => 'No nodes. Paste URL & import above.';

  @override
  String get importedSuccessfully => 'Imported successfully';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get connection => 'Connection';

  @override
  String get routeMode => 'Route mode';

  @override
  String get globalProxy => 'Global proxy';

  @override
  String get smartSplit => 'Smart split';

  @override
  String get systemProxy => 'System proxy';

  @override
  String get systemProxyManaged =>
      'Managed automatically while Forge VPN is connected.';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get engine => 'Engine';

  @override
  String get noLogsYet => 'No logs yet.';

  @override
  String get checkVpn => 'Check VPN';

  @override
  String get anyTls => 'AnyTLS';

  @override
  String get vmess => 'VMess';

  @override
  String get vless => 'VLESS';

  @override
  String get trojan => 'Trojan';

  @override
  String get shadowsocks => 'Shadowsocks';

  @override
  String get wireguard => 'WireGuard';

  @override
  String get otherRegion => 'Other';
}
