import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_vpn_flutter/widgets/responsive.dart';

void main() {
  testWidgets('classifies a narrow landscape phone by its shortest side',
      (tester) async {
    ScreenType? type;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(900, 400)),
        child: Builder(
          builder: (context) {
            type = Responsive.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(type, ScreenType.phone);
  });
}
