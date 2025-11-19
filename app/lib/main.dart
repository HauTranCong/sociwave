import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/utils/logger.dart';
import 'data/services/storage_service.dart';
import 'providers/provider_setup.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AppLogger.info('${AppConstants.appName} starting...');
  
  // Initialize storage service
  final storageService = await StorageService.init();
  
  runApp(MyApp(storageService: storageService));
}

class MyApp extends StatelessWidget {
  final StorageService storageService;
  
  const MyApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return ProviderSetup.create(
      storageService: storageService,
      child: Builder(
        builder: (context) {
          // Create router after providers are available
          final router = AppRouter.createRouter(context);
          
          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
