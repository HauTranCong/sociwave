import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';
import './auth_provider.dart';
import './config_provider.dart';
import './reels_provider.dart';
import './rules_provider.dart';
import './comments_provider.dart';
import './monitor_provider.dart';

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
        
        // Auth Provider
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(storageService)..init(),
        ),
        
        // Config Provider
        ChangeNotifierProvider<ConfigProvider>(
          create: (_) => ConfigProvider(storageService)..init(),
        ),
        
        // Rules Provider
        ChangeNotifierProvider<RulesProvider>(
          create: (_) => RulesProvider(storageService)..init(),
        ),
        
        // Reels Provider
        ChangeNotifierProvider<ReelsProvider>(
          create: (_) => ReelsProvider(storageService),
        ),
        
        // Comments Provider
        ChangeNotifierProvider<CommentsProvider>(
          create: (_) => CommentsProvider(storageService),
        ),
        
        // Monitor Provider
        ChangeNotifierProvider<MonitorProvider>(
          create: (_) => MonitorProvider(storageService)..init(),
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
          create: (_) => RulesProvider(storageService)..init(),
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
            final provider = CommentsProvider(storageService);
            provider.initialize(configProvider.config);
            return provider;
          },
        ),
        
        // Monitor Provider
        ChangeNotifierProvider<MonitorProvider>(
          create: (_) => MonitorProvider(storageService)..init(),
        ),
      ],
      child: child,
    );
  }
}
