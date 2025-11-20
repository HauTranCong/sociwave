import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import '../providers/monitor_provider.dart';
import '../router/app_router.dart';

/// Splash screen with app initialization
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Wait for providers to initialize
      final authProvider = context.read<AuthProvider>();
      final configProvider = context.read<ConfigProvider>();
      final monitorProvider = context.read<MonitorProvider>();

      // Initialize auth state
      await authProvider.init();
      
      // Load configuration
      await configProvider.init();

      // Initialize monitor status
      await monitorProvider.init();

      // Wait minimum time for splash screen (UX)
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Navigate based on auth status
      if (authProvider.isAuthenticated) {
        context.go(AppRouter.dashboard);
      } else {
        context.go(AppRouter.login);
      }
    } catch (e) {
      if (!mounted) return;
      // On error, go to login
      context.go(AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon
              Icon(
                Icons.dynamic_feed_rounded,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              
              // App Name
              Text(
                'SociWave',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Tagline
              Text(
                'Automate Your Social Media Replies',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),
              
              // Loading Indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
