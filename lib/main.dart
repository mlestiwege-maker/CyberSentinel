import 'package:flutter/material.dart';
import 'screens/alerts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/incidents_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const CyberSentinelApp());
}

class CyberSentinelApp extends StatefulWidget {
  const CyberSentinelApp({super.key});

  @override
  State<CyberSentinelApp> createState() => _CyberSentinelAppState();
}

class _CyberSentinelAppState extends State<CyberSentinelApp> {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B3D91),
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          brightness == Brightness.light ? const Color(0xFFF3F6FB) : const Color(0xFF0E141F),
      cardTheme: const CardThemeData(
        elevation: 1.5,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
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
      pageBuilder: (_, __, ___) => page,
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