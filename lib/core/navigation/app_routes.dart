import 'package:flutter/material.dart';
import '../../data/models/language_model.dart';
import '../../ui/features/about/views/about_screen.dart';
import '../../ui/features/connection_mode/views/connection_mode_screen.dart';
import '../../ui/features/home/views/home_screen.dart';
import '../../ui/features/language_selection/views/language_selection_screen.dart';
import '../../ui/features/live_translation/views/live_translation_screen.dart';
import '../../ui/features/offline_packs/views/offline_packs_screen.dart';
import '../../ui/features/settings/views/settings_screen.dart';
import '../../ui/features/splash/views/splash_screen.dart';

/// Centralized routing configuration for all 8 Matladu AI screens.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
  static const String liveTranslation = '/live-translation';
  static const String languageSelection = '/language-selection';
  static const String offlinePacks = '/offline-packs';
  static const String settings = '/settings';
  static const String about = '/about';
  static const String connectionMode = '/connection-mode';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return _buildPageRoute(const SplashScreen(), routeSettings);
      case home:
        return _buildPageRoute(const HomeScreen(), routeSettings);
      case liveTranslation:
        return _buildPageRoute(const LiveTranslationScreen(), routeSettings);
      case languageSelection:
        final args = routeSettings.arguments as Map<String, dynamic>? ?? {};
        final isSelectingSource = args['isSelectingSource'] as bool? ?? true;
        final currentLanguage = args['currentLanguage'] as LanguageModel?;
        return _buildPageRoute(
          LanguageSelectionScreen(
            isSelectingSource: isSelectingSource,
            currentLanguage: currentLanguage,
          ),
          routeSettings,
        );
      case offlinePacks:
        return _buildPageRoute(const OfflinePacksScreen(), routeSettings);
      case settings:
        return _buildPageRoute(const SettingsScreen(), routeSettings);
      case about:
        return _buildPageRoute(const AboutScreen(), routeSettings);
      case connectionMode:
        return _buildModalRoute(const ConnectionModeScreen(), routeSettings);
      default:
        return _buildPageRoute(const HomeScreen(), routeSettings);
    }
  }

  static PageRouteBuilder _buildPageRoute(
    Widget child,
    RouteSettings routeSettings,
  ) {
    return PageRouteBuilder(
      settings: routeSettings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
    );
  }

  static PageRouteBuilder _buildModalRoute(
    Widget child,
    RouteSettings routeSettings,
  ) {
    return PageRouteBuilder(
      settings: routeSettings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 240),
    );
  }
}
