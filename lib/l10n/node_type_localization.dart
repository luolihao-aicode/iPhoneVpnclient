import '../core/models/node.dart';
import 'app_localizations.dart';

extension NodeTypeLocalization on NodeType {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case NodeType.anytls:
        return l10n.anyTls;
      case NodeType.vmess:
        return l10n.vmess;
      case NodeType.vless:
        return l10n.vless;
      case NodeType.trojan:
        return l10n.trojan;
      case NodeType.shadowsocks:
        return l10n.shadowsocks;
      case NodeType.wireguard:
        return l10n.wireguard;
    }
  }
}
