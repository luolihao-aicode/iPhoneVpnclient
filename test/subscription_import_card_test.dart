import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_vpn_flutter/l10n/app_localizations.dart';
import 'package:forge_vpn_flutter/providers/app_provider.dart';
import 'package:forge_vpn_flutter/widgets/subscription_import_card.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('已导入订阅时卡片默认折叠，点击标题后展开', (tester) async {
    final provider = _SubscriptionProvider('https://example.com/subscription');

    await _pumpCard(tester, provider);

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('subscription-import-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('键盘完成会导入订阅、收起键盘和卡片', (tester) async {
    final provider = _SubscriptionProvider('');
    await _pumpCard(tester, provider);

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'https://example.com/new');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(provider.lastImportedUrl, 'https://example.com/new');
    expect(tester.binding.focusManager.primaryFocus?.hasFocus, isNot(isTrue));
    expect(find.byType(TextField), findsNothing);
  });
}

Future<void> _pumpCard(WidgetTester tester, AppProvider provider) {
  return tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: provider,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SubscriptionImportCard()),
      ),
    ),
  );
}

class _SubscriptionProvider extends AppProvider {
  _SubscriptionProvider(this._subscriptionUrl);

  String _subscriptionUrl;
  String lastImportedUrl = '';

  @override
  String get subscriptionUrl => _subscriptionUrl;

  @override
  Future<void> importSubscription(String url) async {
    lastImportedUrl = url;
    _subscriptionUrl = url;
    notifyListeners();
  }
}
