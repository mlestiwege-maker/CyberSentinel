import 'package:flutter/material.dart';
import 'data/threat_feed_service.dart';
import 'screens/alerts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/incidents_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  ThreatFeedService().initialize();
  runApp(const CyberSentinelApp());
}

class CyberSentinelApp extends StatefulWidget {
  const CyberSentinelApp({super.key});

  @override
  State<CyberSentinelApp> createState() => _CyberSentinelAppState();
}

class _CyberSentinelAppState extends State<CyberSentinelApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    ThreatFeedService().initialize();
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B3D91),
      brightness: brightness,
    );
    final baseTextTheme = Typography.material2021().black;
    final textTheme = baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        height: 1.35,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        height: 1.3,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      scaffoldBackgroundColor:
          brightness == Brightness.light ? const Color(0xFFF3F6FB) : const Color(0xFF0E141F),
      cardTheme: CardThemeData(
        elevation: 1.2,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.white
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        labelStyle: textTheme.labelMedium,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        thickness: 0.8,
      ),
    );
  }

  void _setDarkMode(bool isDarkMode) {
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  PageRouteBuilder<void> _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CyberSentinel',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return _buildRoute(const DashboardScreen(), settings);
          case '/alerts':
            return _buildRoute(const AlertsScreen(), settings);
          case '/monitoring':
            return _buildRoute(const MonitoringScreen(), settings);
          case '/reports':
            return _buildRoute(const ReportsScreen(), settings);
          case '/incidents':
            return _buildRoute(const IncidentsScreen(), settings);
          case '/settings':
            return _buildRoute(
              SettingsScreen(
                isDarkMode: _themeMode == ThemeMode.dark,
                onThemeModeChanged: _setDarkMode,
              ),
              settings,
            );
          default:
            return _buildRoute(const DashboardScreen(), settings);
        }
      },
    );
  }
}