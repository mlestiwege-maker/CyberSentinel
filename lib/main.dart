import 'package:flutter/material.dart';
import 'data/threat_feed_service.dart';
import 'screens/alerts_screen.dart';
import 'screens/command_center_dashboard_screen.dart';
import 'screens/incidents_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/terminal_screen.dart';

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
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    ThreatFeedService().initialize();
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isLight ? const Color(0xFF245DFF) : const Color(0xFF4E89FF),
      onPrimary: Colors.white,
      primaryContainer: isLight ? const Color(0xFFDEE4FF) : const Color(0xFF1C3AA3),
      onPrimaryContainer: isLight ? const Color(0xFF001B7A) : const Color(0xFFDEE4FF),
      secondary: isLight ? const Color(0xFF576E7F) : const Color(0xFF8A63FF),
      onSecondary: Colors.white,
      secondaryContainer: isLight ? const Color(0xFFDDE5F7) : const Color(0xFF5D4DB2),
      onSecondaryContainer: isLight ? const Color(0xFF142F44) : const Color(0xFFE9DDFF),
      tertiary: isLight ? const Color(0xFF00B8D9) : const Color(0xFFFFB74D),
      onTertiary: isLight ? Colors.white : Colors.black,
      tertiaryContainer: isLight ? const Color(0xFFB2F0FF) : const Color(0xFFFF8D3F),
      onTertiaryContainer: isLight ? const Color(0xFF003545) : const Color(0xFF4D2D00),
      error: const Color(0xFFFF4D4D),
      onError: Colors.white,
      errorContainer: isLight ? const Color(0xFFFFDAD6) : const Color(0xFF93000A),
      onErrorContainer: isLight ? const Color(0xFF410E0B) : const Color(0xFFFFDAD6),
      surfaceDim: isLight ? const Color(0xFFDEE3EB) : const Color(0xFF0A0F1A),
      surface: isLight ? const Color(0xFFFBFCFF) : const Color(0xFF0A0F1A),
      surfaceBright: isLight ? const Color(0xFFFBFCFF) : const Color(0xFF30394A),
      surfaceContainerLowest: isLight ? Colors.white : const Color(0xFF05090E),
      surfaceContainerLow: isLight ? const Color(0xFFF4F8FF) : const Color(0xFF121A2B),
      surfaceContainer: isLight ? const Color(0xFFEEF2FA) : const Color(0xFF181E2E),
      surfaceContainerHigh: isLight ? const Color(0xFFE8ECFC) : const Color(0xFF222D3E),
      surfaceContainerHighest: isLight ? const Color(0xFFE2E7F0) : const Color(0xFF2D3B4F),
      onSurface: isLight ? const Color(0xFF1A1C1F) : const Color(0xFFE3E3E6),
      onSurfaceVariant: isLight ? const Color(0xFF49454E) : const Color(0xFFC7C7CC),
      outline: isLight ? const Color(0xFF79747E) : const Color(0xFF91919B),
      outlineVariant: isLight ? const Color(0xFFC9C7CC) : const Color(0xFF49454E),
      scrim: Colors.black,
      inverseSurface: isLight ? const Color(0xFF313033) : const Color(0xFFE3E3E6),
      onInverseSurface: isLight ? const Color(0xFFF1F0F4) : const Color(0xFF1A1C1F),
      inversePrimary: isLight ? const Color(0xFFB9C6FF) : const Color(0xFFDEE4FF),
      shadow: Colors.black.withValues(alpha: 0.4),
      surfaceTint: isLight ? const Color(0xFF245DFF) : const Color(0xFF4E89FF),
    );

    final baseTextTheme = isLight ? 
      Typography.material2021().black : 
      Typography.material2021().white;
    
    final textTheme = baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        height: 1.35,
        color: colorScheme.onSurface,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        height: 1.3,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.30)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        labelStyle: textTheme.labelMedium?.copyWith(color: colorScheme.onSurface),
        backgroundColor: colorScheme.surfaceContainer,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 140),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 1.5;
            return 0.5;
          }),
          backgroundColor: WidgetStatePropertyAll(colorScheme.primary),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.16);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.08);
            }
            return null;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 140),
          backgroundColor: WidgetStatePropertyAll(colorScheme.primary),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.06);
            }
            return null;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 140),
          side: WidgetStateProperty.resolveWith((states) {
            final alpha = states.contains(WidgetState.hovered) ? 0.7 : 0.45;
            return BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: alpha),
              width: 1.5,
            );
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colorScheme.primary.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.hovered)) {
              return colorScheme.primary.withValues(alpha: 0.07);
            }
            return null;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? const Color(0xFF20283A) : const Color(0xFF121A2B),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.992,
              end: 1,
            ).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.016, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
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
            return _buildRoute(const CommandCenterDashboardScreen(), settings);
          case '/alerts':
            return _buildRoute(const AlertsScreen(), settings);
          case '/monitoring':
            return _buildRoute(const MonitoringScreen(), settings);
          case '/reports':
            return _buildRoute(const ReportsScreen(), settings);
          case '/incidents':
            return _buildRoute(const IncidentsScreen(), settings);
          case '/terminal':
            return _buildRoute(const TerminalScreen(), settings);
          case '/settings':
            return _buildRoute(
              SettingsScreen(
                isDarkMode: _themeMode == ThemeMode.dark,
                onThemeModeChanged: _setDarkMode,
              ),
              settings,
            );
          default:
            return _buildRoute(const CommandCenterDashboardScreen(), settings);
        }
      },
    );
  }
}