import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_vpn_flutter/providers/app_provider.dart';
import 'package:forge_vpn_flutter/screens/dashboard_screen.dart';

void main() {
  testWidgets('phone dashboard does not overflow the server header',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();
    await provider.importSubscriptionText(
      '[{"type":"vmess","name":"Test","server":"example.com","port":443,"id":"test-id"}]',
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
        child: ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
