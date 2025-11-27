/// Storage keys for SharedPreferences and SecureStorage
class StorageKeys {
  // Authentication
  static const String authKey = 'auth_data';
  
  // Configuration
  static const String configKey = 'app_config';
  static const String apiTokenKey = 'api_token'; // Stored in secure storage
  static const String apiVersionKey = 'api_version';
  static const String pageIdKey = 'page_id';
  static const String managedPagesKey = 'managed_pages';
  static const String pageNamesKey = 'page_names';
  static const String useMockDataKey = 'use_mock_data';
  
  // Rules
  static const String rulesKey = 'rules_data';
  
  // Replied Comments
  static const String repliedCommentsKey = 'replied_comments';
  
  // Cached Data
  static const String cachedReelsKey = 'cached_reels';
  static const String cachedReelsTimestampKey = 'cached_reels_timestamp';
  
  // User Preferences
  static const String themeModeKey = 'theme_mode';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String monitoringEnabledKey = 'monitoring_enabled';
  
  // Monitoring Status
  static const String lastMonitorCheckKey = 'last_monitor_check';
  static const String totalMonitorChecksKey = 'total_monitor_checks';
  static const String totalRepliesKey = 'total_replies';
  
  // Inbox Tracking
  static const String inboxedUsersKey = 'inboxed_users';
  
  // Onboarding
  static const String hasCompletedOnboardingKey = 'has_completed_onboarding';
  static const String isFirstLaunchKey = 'is_first_launch';
}
