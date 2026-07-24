import 'package:flutter_test/flutter_test.dart';
import 'package:forge_vpn_flutter/main.dart';

void main() {
  testWidgets('main navigation keeps import on dashboard without Nodes tab',
      (tester) async {
    await tester.pumpWidget(const ForgeVpnApp());
    await tester.pump();

    expect(find.text('Nodes'), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
  });
}
