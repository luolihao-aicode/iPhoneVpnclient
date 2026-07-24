import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/logs_screen.dart';
import 'widgets/responsive.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ForgeVpnApp());
}

Locale resolveForgeLocale(List<Locale>? locales) {
  for (final locale in locales ?? const <Locale>[]) {
    if (locale.languageCode == 'zh') return const Locale('zh');
    if (locale.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}

class ForgeVpnApp extends StatelessWidget {
  const ForgeVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'Forge VPN',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: (locales, supportedLocales) =>
            resolveForgeLocale(locales),
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Responsive.bgColor,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF21B892),
            secondary: Color(0xFF5D8CFF),
            error: Color(0xFFE15D52),
            surface: Color(0xFF161B22),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D1117),
            elevation: 0,
            centerTitle: true,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF0D1117),
            selectedItemColor: Color(0xFF21B892),
            unselectedItemColor: Color(0xFF8B949E),
            type: BottomNavigationBarType.fixed,
          ),
          useMaterial3: true,
        ),
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    DashboardScreen(),
    SettingsScreen(),
    LogsScreen(),
  ];

  List<({IconData icon, IconData activeIcon, String label})> _navItems(
      AppLocalizations l10n) {
    return [
      (
        icon: Icons.speed_outlined,
        activeIcon: Icons.speed,
        label: l10n.dashboard
      ),
      (
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: l10n.settings
      ),
      (
        icon: Icons.terminal_outlined,
        activeIcon: Icons.terminal,
        label: l10n.logs
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().initialize('');
    });
  }

  Widget _brand(double size, double fontSize) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF21B892),
            borderRadius: BorderRadius.circular(size * 0.25),
          ),
          child: Center(
            child: Text('FV',
                style: TextStyle(
                    color: const Color(0xFF062019),
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize)),
          ),
        ),
        const SizedBox(width: 8),
        const Text('Forge VPN', style: TextStyle(fontSize: 18)),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(
      bool connected, ScreenType type, AppLocalizations l10n) {
    return AppBar(
      title: _brand(28, 12),
      centerTitle: type == ScreenType.phone,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: connected
                ? const Color(0xFF21B892).withValues(alpha: 0.15)
                : const Color(0xFFE15D52).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: connected
                  ? const Color(0xFF21B892).withValues(alpha: 0.4)
                  : const Color(0xFFE15D52).withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            connected ? l10n.connected : l10n.disconnected,
            style: TextStyle(
              color:
                  connected ? const Color(0xFFBDFFED) : const Color(0xFFFFBAB4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(AppLocalizations l10n) {
    final navItems = _navItems(l10n);
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      items: navItems
          .map((e) => BottomNavigationBarItem(
                icon: Icon(e.icon),
                activeIcon: Icon(e.activeIcon),
                label: e.label,
              ))
          .toList(),
    );
  }

  Widget _buildNavRail(AppLocalizations l10n) {
    final navItems = _navItems(l10n);
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      labelType: NavigationRailLabelType.all,
      backgroundColor: const Color(0xFF111720),
      indicatorColor: const Color(0xFF21B892).withValues(alpha: 0.15),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _brand(36, 14),
      ),
      destinations: navItems
          .map((e) => NavigationRailDestination(
                icon: Icon(e.icon),
                selectedIcon: Icon(e.activeIcon),
                label: Text(e.label),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<AppProvider>().runtime.connected;
    final type = Responsive.of(context);
    final l10n = AppLocalizations.of(context);

    if (type == ScreenType.phone) {
      return Scaffold(
        appBar: _buildAppBar(connected, type, l10n),
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: _buildBottomNav(l10n),
      );
    }

    // Tablet + desktop: NavigationRail + body
    return Scaffold(
      appBar: _buildAppBar(connected, type, l10n),
      body: Row(
        children: [
          _buildNavRail(l10n),
          const VerticalDivider(width: 1, color: Color(0xFF2D3643)),
          Expanded(child: IndexedStack(index: _currentIndex, children: _pages)),
        ],
      ),
    );
  }
}
