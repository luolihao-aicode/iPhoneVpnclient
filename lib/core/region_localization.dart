import '../l10n/app_localizations.dart';

extension RegionLocalization on String {
  String localizedRegionName(AppLocalizations l10n) {
    final code = toUpperCase();
    if (code == 'OTHER') return l10n.otherRegion;
    final chinese = l10n.localeName.toLowerCase().startsWith('zh');
    const names = <String, (String, String)>{
      'HKG': ('香港', 'Hong Kong'), 'HK': ('香港', 'Hong Kong'),
      'SGP': ('新加坡', 'Singapore'), 'SG': ('新加坡', 'Singapore'),
      'USA': ('美国', 'United States'), 'US': ('美国', 'United States'),
      'JPN': ('日本', 'Japan'), 'JP': ('日本', 'Japan'),
      'KOR': ('韩国', 'South Korea'), 'KR': ('韩国', 'South Korea'),
      'DEU': ('德国', 'Germany'), 'DE': ('德国', 'Germany'),
      'GBR': ('英国', 'United Kingdom'), 'UK': ('英国', 'United Kingdom'),
      'FRA': ('法国', 'France'), 'CAN': ('加拿大', 'Canada'),
      'TWN': ('台湾', 'Taiwan'), 'TW': ('台湾', 'Taiwan'),
    };
    final name = names[code];
    return name == null ? this : (chinese ? name.$1 : name.$2);
  }
}
