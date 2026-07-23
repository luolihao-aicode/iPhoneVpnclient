import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('主应用签名使用描述文件中的完整权限集', () {
    final workflow = File('.github/workflows/build-ios.yml').readAsStringSync();

    expect(
      workflow,
      contains('plutil -extract Entitlements xml1 -o "$APP_ENTITLEMENTS_PATH" -'),
    );
    expect(
      workflow,
      contains('--entitlements "$APP_ENTITLEMENTS_PATH" "$APP_PATH"'),
    );
    expect(
      workflow,
      contains('Main app profile is missing the Personal VPN entitlement'),
    );
    expect(
      workflow,
      contains("PlistBuddy -c 'Print :com.apple.developer.networking.vpn.api'"),
    );
  });
}
