// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Forge VPN';

  @override
  String get dashboard => '仪表盘';

  @override
  String get nodes => '节点';

  @override
  String get settings => '设置';

  @override
  String get logs => '日志';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '未连接';

  @override
  String get connecting => '连接中';

  @override
  String get disconnecting => '断开中';

  @override
  String get noNodeSelected => '未选择节点';

  @override
  String get importSubscriptionFirst => '请先导入订阅。';

  @override
  String get ping => '延迟';

  @override
  String get download => '下载';

  @override
  String get upload => '上传';

  @override
  String get protocol => '协议';

  @override
  String get endpoint => '地址';

  @override
  String get status => '状态';

  @override
  String get subscriptionServers => '订阅服务器';

  @override
  String get check => '检查';

  @override
  String get checking => '检查中';

  @override
  String availableCount(int count) {
    return '$count 个可用';
  }

  @override
  String totalCount(int count) {
    return '共 $count 个';
  }

  @override
  String get noSubscriptionServers => '暂无订阅服务器';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get unknown => '未知';

  @override
  String get ready => '就绪';

  @override
  String get selected => '已选择';

  @override
  String get subscriptionUrl => '订阅地址';

  @override
  String get importAction => '导入';

  @override
  String get noNodesPasteUrl => '暂无节点，请在上方粘贴订阅地址并导入。';

  @override
  String get importedSuccessfully => '导入成功';

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get connection => '连接';

  @override
  String get routeMode => '路由模式';

  @override
  String get globalProxy => '全局代理';

  @override
  String get smartSplit => '智能分流';

  @override
  String get systemProxy => '系统代理';

  @override
  String get systemProxyManaged => 'Forge VPN 连接期间自动管理。';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get engine => '核心';

  @override
  String get noLogsYet => '暂无日志。';

  @override
  String get checkVpn => '检查 VPN';

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
  String get otherRegion => '其他';
}
