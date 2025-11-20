import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/rule_editor_screen.dart';
import '../screens/comments_screen.dart';
import '../widgets/main_layout.dart';
import '../providers/auth_provider.dart';

/// App navigation configuration using go_router
class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String settings = '/settings';
  static const String dashboard = '/dashboard';
  static const String ruleEditor = '/rule-editor';
  static const String comments = '/comments';

  static GoRouter createRouter(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return GoRouter(
      initialLocation: splash,
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isLoading = authProvider.isLoading;
        final isOnLoginPage = state.matchedLocation == login;
        final isOnSplashPage = state.matchedLocation == splash;

        // Still loading, show splash
        if (isLoading && !isOnSplashPage) {
          return splash;
        }

        // Not authenticated and not on login page, redirect to login
        if (!isAuthenticated && !isOnLoginPage && !isOnSplashPage) {
          return login;
        }

        // Authenticated and on login/splash page, redirect to dashboard
        if (isAuthenticated && (isOnLoginPage || isOnSplashPage)) {
          return dashboard;
        }

        return null; // No redirect needed
      },
      routes: [
        GoRoute(
          path: splash,
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: login,
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return MainLayout(child: child);
          },
          routes: [
            GoRoute(
              path: dashboard,
              name: 'dashboard',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const DashboardScreen(),
              ),
            ),
            GoRoute(
              path: settings,
              name: 'settings',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const SettingsScreen(),
              ),
            ),
            GoRoute(
              path: ruleEditor,
              name: 'rule-editor',
              pageBuilder: (context, state) {
                final extra = state.extra as Map<String, dynamic>?;
                return NoTransitionPage(
                  child: RuleEditorScreen(
                    reelId: extra?['reelId'] as String?,
                    reelDescription: extra?['reelDescription'] as String?,
                  ),
                );
              },
            ),
            GoRoute(
              path: comments,
              name: 'comments',
              pageBuilder: (context, state) {
                final extra = state.extra as Map<String, dynamic>?;
                return NoTransitionPage(
                  child: CommentsScreen(
                    reelId: extra?['reelId'] as String? ?? '',
                    reelDescription: extra?['reelDescription'] as String? ?? '',
                  ),
                );
              },
            ),
          ],
        ),
      ],
      errorPageBuilder: (context, state) => NoTransitionPage(
        child: Scaffold(
          body: Center(
            child: Text('Page not found: ${state.uri}'),
          ),
        ),
      ),
    );
  }
}
