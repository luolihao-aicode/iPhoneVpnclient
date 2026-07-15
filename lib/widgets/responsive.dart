import 'package:flutter/material.dart';

enum ScreenType { phone, tablet, desktop }

/// Responsive breakpoint helpers for adaptive layouts.
class Responsive {
  static ScreenType of(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return ScreenType.phone;
    if (width < 1024) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  static bool isPhone(BuildContext context) => of(context) == ScreenType.phone;
  static bool isTablet(BuildContext context) => of(context) == ScreenType.tablet;
  static bool isDesktop(BuildContext context) => of(context) == ScreenType.desktop;

  /// Vertical + horizontal padding for the outermost scroll content.
  static EdgeInsets screenPadding(BuildContext context) {
    switch (of(context)) {
      case ScreenType.phone:
        return const EdgeInsets.all(16);
      case ScreenType.tablet:
        return const EdgeInsets.all(24);
      case ScreenType.desktop:
        return const EdgeInsets.all(32);
    }
  }

  /// Inner card padding.
  static EdgeInsets cardPadding(BuildContext context) {
    return EdgeInsets.all(isPhone(context) ? 16 : 20);
  }

  /// Dashboard node-chip width.
  static double nodeChipWidth(BuildContext context) {
    return isPhone(context) ? 110 : 130;
  }

  /// Card / container corner radius.
  static double cardRadius(BuildContext context) {
    return isPhone(context) ? 12 : 16;
  }

  /// Border / divider colour used throughout the app.
  static Color get borderColor => const Color(0xFF2D3643);
  static Color get surfaceColor => const Color(0xFF161B22);
  static Color get bgColor => const Color(0xFF0D1117);
  static Color get textPrimary => const Color(0xFFEEF3F8);
  static Color get accent => const Color(0xFF21B892);
  static Color get error => const Color(0xFFE15D52);
}

/// Convenience widget that applies [Responsive.screenPadding].
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  const ResponsivePadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Responsive.screenPadding(context),
      child: child,
    );
  }
}
