import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/utils/logger.dart';
import 'data/services/storage_service.dart';
import 'providers/provider_setup.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URLs on web (removes "#" from routes)
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }

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
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // Create router after providers are available
          final router = AppRouter.createRouter(context);

          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
