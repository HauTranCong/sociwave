import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/utils/logger.dart';
import '../../domain/models/config.dart';
import '../../domain/models/reel.dart';
import '../../domain/models/rule.dart';

/// Service for local data persistence
/// 
/// Uses SharedPreferences for non-sensitive data and
/// FlutterSecureStorage for sensitive data (API tokens)
class StorageService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  StorageService(this._prefs, this._secureStorage);

  /// Initialize storage service
  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    );
    return StorageService(prefs, secureStorage);
  }

  // ==================== Configuration ====================

  /// Save configuration (token stored securely, rest in preferences)
  Future<void> saveConfig(Config config) async {
    try {
      // Store token securely
      await _secureStorage.write(
        key: StorageKeys.apiTokenKey,
        value: config.token,
      );

      // Store other config in preferences
      final configData = {
        'version': config.version,
        'page_id': config.pageId,
        'use_mock_data': config.useMockData,
      };
      await _prefs.setString(StorageKeys.configKey, jsonEncode(configData));
      
      AppLogger.info('Config saved successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save config', e, stackTrace);
      rethrow;
    }
  }

  /// Load configuration
  Future<Config?> loadConfig() async {
    try {
      final configJson = _prefs.getString(StorageKeys.configKey);
      if (configJson == null) {
        AppLogger.info('No saved config found');
        return null;
      }

      final configData = jsonDecode(configJson) as Map<String, dynamic>;
      
      // Get token from secure storage
      final token = await _secureStorage.read(key: StorageKeys.apiTokenKey) ?? '';

      final config = Config(
        token: token,
        version: configData['version'] as String? ?? 'v24.0',
        pageId: configData['page_id'] as String? ?? 'me',
        useMockData: configData['use_mock_data'] as bool? ?? false,
      );

      AppLogger.info('Config loaded successfully');
      return config;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load config', e, stackTrace);
      return null;
    }
  }

  /// Clear configuration
  Future<void> clearConfig() async {
    try {
      await _secureStorage.delete(key: StorageKeys.apiTokenKey);
      await _prefs.remove(StorageKeys.configKey);
      AppLogger.info('Config cleared');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear config', e, stackTrace);
      rethrow;
    }
  }

  // ==================== Rules ====================

  /// Save all rules
  Future<void> saveRules(Map<String, Rule> rules) async {
    try {
      final rulesMap = <String, dynamic>{};
      rules.forEach((objectId, rule) {
        rulesMap[objectId] = rule.toJson();
      });
      
      await _prefs.setString(StorageKeys.rulesKey, jsonEncode(rulesMap));
      AppLogger.info('Saved ${rules.length} rules');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save rules', e, stackTrace);
      rethrow;
    }
  }

  /// Load all rules
  Future<Map<String, Rule>> loadRules() async {
    try {
      final rulesJson = _prefs.getString(StorageKeys.rulesKey);
      if (rulesJson == null) {
        AppLogger.info('No saved rules found');
        return {};
      }

      final rulesData = jsonDecode(rulesJson) as Map<String, dynamic>;
      final rules = <String, Rule>{};
      
      rulesData.forEach((objectId, ruleData) {
        rules[objectId] = Rule.fromJson(objectId, ruleData as Map<String, dynamic>);
      });

      AppLogger.info('Loaded ${rules.length} rules');
      return rules;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load rules', e, stackTrace);
      return {};
    }
  }

  /// Save a single rule
  Future<void> saveRule(String objectId, Rule rule) async {
    try {
      final rules = await loadRules();
      rules[objectId] = rule;
      await saveRules(rules);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save rule for $objectId', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a rule
  Future<void> deleteRule(String objectId) async {
    try {
      final rules = await loadRules();
      rules.remove(objectId);
      await saveRules(rules);
      AppLogger.info('Deleted rule for $objectId');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete rule for $objectId', e, stackTrace);
      rethrow;
    }
  }

  // ==================== Replied Comments ====================

  /// Save replied comment IDs
  Future<void> saveRepliedComments(Set<String> commentIds) async {
    try {
      await _prefs.setString(
        StorageKeys.repliedCommentsKey,
        jsonEncode(commentIds.toList()),
      );
      AppLogger.info('Saved ${commentIds.length} replied comment IDs');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save replied comments', e, stackTrace);
      rethrow;
    }
  }

  /// Load replied comment IDs
  Future<Set<String>> loadRepliedComments() async {
    try {
      final json = _prefs.getString(StorageKeys.repliedCommentsKey);
      if (json == null) {
        return {};
      }

      final List<dynamic> list = jsonDecode(json);
      final Set<String> commentIds = list.cast<String>().toSet();
      
      AppLogger.info('Loaded ${commentIds.length} replied comment IDs');
      return commentIds;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load replied comments', e, stackTrace);
      return {};
    }
  }

  /// Add a replied comment ID
  Future<void> addRepliedComment(String commentId) async {
    try {
      final commentIds = await loadRepliedComments();
      commentIds.add(commentId);
      await saveRepliedComments(commentIds);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add replied comment $commentId', e, stackTrace);
      rethrow;
    }
  }

  /// Check if comment has been replied to
  Future<bool> hasRepliedToComment(String commentId) async {
    final commentIds = await loadRepliedComments();
    return commentIds.contains(commentId);
  }

  // ==================== Cached Reels ====================

  /// Cache reels data
  Future<void> cacheReels(List<Reel> reels) async {
    try {
      final reelsJson = reels.map((r) => r.toJson()).toList();
      await _prefs.setString(StorageKeys.cachedReelsKey, jsonEncode(reelsJson));
      await _prefs.setInt(
        StorageKeys.cachedReelsTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      AppLogger.info('Cached ${reels.length} reels');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to cache reels', e, stackTrace);
      rethrow;
    }
  }

  /// Load cached reels
  Future<List<Reel>?> loadCachedReels() async {
    try {
      final json = _prefs.getString(StorageKeys.cachedReelsKey);
      if (json == null) {
        return null;
      }

      final timestamp = _prefs.getInt(StorageKeys.cachedReelsTimestampKey);
      if (timestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
        // Cache expires after 1 hour
        if (cacheAge > 3600000) {
          AppLogger.info('Reel cache expired');
          return null;
        }
      }

      final List<dynamic> reelsData = jsonDecode(json);
      final reels = reelsData
          .map((data) => Reel.fromJson(data as Map<String, dynamic>))
          .toList();
      
      AppLogger.info('Loaded ${reels.length} cached reels');
      return reels;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load cached reels', e, stackTrace);
      return null;
    }
  }

  /// Clear cached reels
  Future<void> clearCachedReels() async {
    try {
      await _prefs.remove(StorageKeys.cachedReelsKey);
      await _prefs.remove(StorageKeys.cachedReelsTimestampKey);
      AppLogger.info('Cleared cached reels');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear cached reels', e, stackTrace);
      rethrow;
    }
  }

  // ==================== User Preferences ====================

  /// Save theme mode
  Future<void> saveThemeMode(String themeMode) async {
    await _prefs.setString(StorageKeys.themeModeKey, themeMode);
  }

  /// Load theme mode
  String loadThemeMode() {
    return _prefs.getString(StorageKeys.themeModeKey) ?? 'system';
  }

  /// Save monitoring enabled state
  Future<void> saveMonitoringEnabled(bool enabled) async {
    await _prefs.setBool(StorageKeys.monitoringEnabledKey, enabled);
  }

  /// Load monitoring enabled state
  bool loadMonitoringEnabled() {
    return _prefs.getBool(StorageKeys.monitoringEnabledKey) ?? false;
  }

  /// Save notifications enabled state
  Future<void> saveNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(StorageKeys.notificationsEnabledKey, enabled);
  }

  /// Load notifications enabled state
  bool loadNotificationsEnabled() {
    return _prefs.getBool(StorageKeys.notificationsEnabledKey) ?? true;
  }

  // ==================== Monitoring Statistics ====================

  /// Save last monitor check timestamp
  Future<void> saveLastMonitorCheck(DateTime timestamp) async {
    await _prefs.setInt(
      StorageKeys.lastMonitorCheckKey,
      timestamp.millisecondsSinceEpoch,
    );
  }

  /// Load last monitor check timestamp
  DateTime? loadLastMonitorCheck() {
    final timestamp = _prefs.getInt(StorageKeys.lastMonitorCheckKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Increment total monitor checks
  Future<void> incrementMonitorChecks() async {
    final current = _prefs.getInt(StorageKeys.totalMonitorChecksKey) ?? 0;
    await _prefs.setInt(StorageKeys.totalMonitorChecksKey, current + 1);
  }

  /// Get total monitor checks
  int getTotalMonitorChecks() {
    return _prefs.getInt(StorageKeys.totalMonitorChecksKey) ?? 0;
  }

  /// Increment total replies
  Future<void> incrementTotalReplies() async {
    final current = _prefs.getInt(StorageKeys.totalRepliesKey) ?? 0;
    await _prefs.setInt(StorageKeys.totalRepliesKey, current + 1);
  }

  /// Get total replies
  int getTotalReplies() {
    return _prefs.getInt(StorageKeys.totalRepliesKey) ?? 0;
  }

  // ==================== Onboarding ====================

  /// Mark onboarding as complete
  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(StorageKeys.hasCompletedOnboardingKey, true);
  }

  /// Check if onboarding is complete
  bool hasCompletedOnboarding() {
    return _prefs.getBool(StorageKeys.hasCompletedOnboardingKey) ?? false;
  }

  /// Mark as not first launch
  Future<void> setNotFirstLaunch() async {
    await _prefs.setBool(StorageKeys.isFirstLaunchKey, false);
  }

  /// Check if first launch
  bool isFirstLaunch() {
    return _prefs.getBool(StorageKeys.isFirstLaunchKey) ?? true;
  }

  // ==================== Authentication ====================

  /// Get authentication data
  Future<Map<String, dynamic>?> getAuthData() async {
    try {
      final authDataStr = _prefs.getString(StorageKeys.authKey);
      if (authDataStr == null) return null;
      
      return jsonDecode(authDataStr) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get auth data', e, stackTrace);
      return null;
    }
  }

  /// Save authentication data
  Future<void> saveAuthData(Map<String, dynamic> authData) async {
    try {
      await _prefs.setString(StorageKeys.authKey, jsonEncode(authData));
      AppLogger.info('Auth data saved successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save auth data', e, stackTrace);
      rethrow;
    }
  }

  /// Clear authentication data
  Future<void> clearAuthData() async {
    try {
      await _prefs.remove(StorageKeys.authKey);
      AppLogger.info('Auth data cleared');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear auth data', e, stackTrace);
      rethrow;
    }
  }

  // ==================== Clear All Data ====================

  /// Clear all app data
  Future<void> clearAll() async {
    try {
      await _prefs.clear();
      await _secureStorage.deleteAll();
      AppLogger.info('Cleared all app data');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear all data', e, stackTrace);
      rethrow;
    }
  }
}
