import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';
import 'api_client_provider.dart';
import './auth_provider.dart';
import './config_provider.dart';
import './reels_provider.dart';
import './rules_provider.dart';
import './comments_provider.dart';
import './monitor_provider.dart';
import './theme_provider.dart';

/// Sets up all providers for the application
class ProviderSetup {
  /// Creates a MultiProvider with all application providers
  ///
  /// Note: storageService must be initialized using StorageService.init()
  static Widget create({
    required Widget child,
    required StorageService storageService,
  }) {
    return MultiProvider(
      providers: [
        // Storage Service (for DI)
        Provider<StorageService>.value(value: storageService),

        // Theme Provider
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),

        // Shared ApiClient provider
        ChangeNotifierProvider<ApiClientProvider>(
          create: (_) => ApiClientProvider(),
        ),

        // Auth Provider (injected with ApiClientProvider so token can be set)
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(storageService, context.read<ApiClientProvider>())..init(),
        ),

        // Config Provider
        ChangeNotifierProvider<ConfigProvider>(
          create: (_) => ConfigProvider(storageService)..init(),
        ),

        // Rules Provider (use shared ApiClientProvider)
        ChangeNotifierProvider<RulesProvider>(
          create: (context) => RulesProvider(storageService, context.read<ApiClientProvider>())..init(),
        ),

        // Reels Provider
        ChangeNotifierProvider<ReelsProvider>(
          create: (_) => ReelsProvider(storageService),
        ),

        // Comments Provider
        ChangeNotifierProvider<CommentsProvider>(
          create: (_) => CommentsProvider(),
        ),

        // Monitor Provider (inject shared ApiClient)
        ChangeNotifierProvider<MonitorProvider>(
          create: (context) {
            final apiClientProvider = context.read<ApiClientProvider>();
            return MonitorProvider(storageService, apiClientProvider)..init();
          },
        ),
      ],
      child: child,
    );
  }

  /// Creates a MultiProvider with all providers initialized from config
  /// Use this after config is loaded
  static Widget createWithConfig({
    required Widget child,
    required StorageService storageService,
    required ConfigProvider configProvider,
  }) {
    return MultiProvider(
      providers: [
        // Existing providers
        ChangeNotifierProvider<ConfigProvider>.value(value: configProvider),
        
        Provider<StorageService>.value(value: storageService),
        
        // Rules Provider
        ChangeNotifierProvider<RulesProvider>(
          create: (context) => RulesProvider(storageService, context.read<ApiClientProvider>())..init(),
        ),
        
        // Reels Provider with config
        ChangeNotifierProvider<ReelsProvider>(
          create: (_) {
            final provider = ReelsProvider(storageService);
            provider.initialize(configProvider.config);
            return provider;
          },
        ),
        
        // Comments Provider with config
        ChangeNotifierProvider<CommentsProvider>(
          create: (_) {
            final provider = CommentsProvider();
            provider.initialize(configProvider.config);
            return provider;
          },
        ),
        
        // Monitor Provider (inject shared ApiClient)
        ChangeNotifierProvider<MonitorProvider>(
          create: (context) {
            final apiClientProvider = context.read<ApiClientProvider>();
            return MonitorProvider(storageService, apiClientProvider)..init();
          },
        ),
      ],
      child: child,
    );
  }
}
