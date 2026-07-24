import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_vpn_flutter/l10n/app_localizations.dart';
import 'package:forge_vpn_flutter/l10n/app_localizations_en.dart';
import 'package:forge_vpn_flutter/l10n/app_localizations_zh.dart';
import 'package:forge_vpn_flutter/core/models/node.dart';
import 'package:forge_vpn_flutter/core/region_localization.dart';
import 'package:forge_vpn_flutter/l10n/node_type_localization.dart';
import 'package:forge_vpn_flutter/main.dart';

void main() {
  test('loads Chinese and English translations', () async {
    final zh = await AppLocalizations.delegate.load(const Locale('zh'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(zh.dashboard, '仪表盘');
    expect(zh.nodes, '节点');
    expect(en.dashboard, 'Dashboard');
    expect(en.nodes, 'Nodes');
    expect(NodeType.anytls.localizedLabel(zh), 'AnyTLS');
  });

  test('only Chinese and English are supported so other locales can fall back',
      () {
    expect(AppLocalizations.delegate.isSupported(const Locale('zh')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('ja')), isFalse);
    expect(resolveForgeLocale([const Locale('ja')]), const Locale('en'));
    expect(resolveForgeLocale([const Locale('zh', 'CN')]), const Locale('zh'));
  });

  test('localizes common region codes and falls back for unknown regions', () {
    expect('HKG'.localizedRegionName(AppLocalizationsZh()), '香港');
    expect('HKG'.localizedRegionName(AppLocalizationsEn()), 'Hong Kong');
    expect('XYZ'.localizedRegionName(AppLocalizationsEn()), 'XYZ');
    expect('OTHER'.localizedRegionName(AppLocalizationsZh()), '其他');
  });
}
