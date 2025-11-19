/// Application-wide constants
class AppConstants {
  // App Information
  static const String appName = 'SociWave';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Automated social media comment management';
  
  // Developer Info
  static const String developerName = 'SociWave Team';
  static const String supportEmail = 'support@sociwave.app';
  
  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration cacheExpiry = Duration(hours: 1);
  
  // Pagination
  static const int defaultPageSize = 25;
  static const int maxPageSize = 100;
  
  // Background Service
  static const Duration monitoringInterval = Duration(minutes: 1);
  static const String monitoringTaskName = 'comment_monitoring_task';
  
  // Storage Keys - see storage_keys.dart for detailed keys
  
  // UI
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
}
