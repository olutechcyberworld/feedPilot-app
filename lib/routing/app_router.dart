// lib/routing/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/device_provider.dart';
import '../routing/router_notifier.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/setup/setup_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/control/control_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/about/about_screen.dart';
import '../widgets/shell_scaffold.dart';

// ── Route path constants ───────────────────────────────────────────────────
// Defined as constants so screens can push/replace by name without
// hardcoding strings. Any path change here propagates automatically.

class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const setup = '/setup';
  static const dashboard = '/dashboard';
  static const control = '/control';
  static const history = '/history';
  static const settings = '/settings';
  static const about = '/about';
}

/// GoRouter instance provider.
/// refreshListenable: routerNotifierProvider — re-evaluates redirect
/// whenever deviceIdProvider changes (see RouterNotifier).
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    debugLogDiagnostics: false, // set true temporarily during routing debug

    // ── Redirect logic ─────────────────────────────────────────────────────
    // Evaluated on every navigation event and on every notifyListeners()
    // call from RouterNotifier (i.e. every deviceIdProvider change).
    redirect: (BuildContext context, GoRouterState state) {
      final deviceId = ref.read(deviceIdProvider);
      final location = state.matchedLocation;

      // Splash is always allowed — it handles its own routing decision
      // after reading SharedPreferences.
      if (location == AppRoutes.splash) return null;

      // No deviceId stored — must complete Setup before accessing any
      // main screen. Allow /setup through; redirect everything else.
      if (deviceId == null) {
        return location == AppRoutes.setup ? null : AppRoutes.setup;
      }

      // deviceId is set — Setup screen is no longer needed.
      // Redirect /setup and / to /dashboard.
      if (location == AppRoutes.setup || location == AppRoutes.splash) {
        return AppRoutes.dashboard;
      }

      // All other routes are allowed.
      return null;
    },

    routes: [
      // ── Splash ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Setup / Onboarding ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => const SetupScreen(),
      ),

      // ── Main shell — persistent BottomNavigationBar ───────────────────────
      // ShellRoute wraps the four main screens in a shared scaffold so the
      // bottom nav bar persists across tab switches without rebuilding.
      ShellRoute(
        builder: (context, state, child) {
          return ShellScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.control,
            builder: (context, state) => const ControlScreen(),
          ),
          GoRoute(
            path: AppRoutes.history,
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),

      // ── About — pushed from Settings, not a shell tab ─────────────────────
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutScreen(),
      ),
    ],
  );
});
