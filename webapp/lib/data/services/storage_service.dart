import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/utils/logger.dart';
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
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    return StorageService(prefs, secureStorage);
  }

  // ==================== Page Management ====================

  /// Persist the list of managed Facebook Page IDs for the current user
  Future<void> saveManagedPages(List<String> pageIds) async {
    final sanitized = pageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    await _prefs.setString(StorageKeys.managedPagesKey, jsonEncode(sanitized));
    AppLogger.info('Saved ${sanitized.length} managed pages');
  }

  /// Load the list of managed Facebook Page IDs
  List<String> loadManagedPages() {
    final raw = _prefs.getString(StorageKeys.managedPagesKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final pages = decoded
          .map((entry) => entry.toString().trim())
          .where((id) => id.isNotEmpty)
          .toList();
      AppLogger.info('Loaded ${pages.length} managed pages');
      return pages;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to decode managed pages', e, stackTrace);
      return [];
    }
  }

  /// Save the last selected page ID so the UI can restore the active scope
  Future<void> saveSelectedPageId(String pageId) async {
    await _prefs.setString(StorageKeys.pageIdKey, pageId);
  }

  /// Load the last selected page ID (if any)
  String? loadSelectedPageId() {
    final stored = _prefs.getString(StorageKeys.pageIdKey);
    if (stored == null) return null;
    final trimmed = stored.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Clear the stored selected page (used when no pages remain)
  Future<void> clearSelectedPageId() async {
    await _prefs.remove(StorageKeys.pageIdKey);
  }

  // ==================== Page Metadata ====================

  /// Persist friendly page names fetched from the backend.
  Future<void> savePageNames(Map<String, String> pageNames) async {
    final sanitized = <String, String>{};
    pageNames.forEach((id, name) {
      final trimmedId = id.trim();
      if (trimmedId.isNotEmpty) {
        sanitized[trimmedId] = name;
      }
    });
    await _prefs.setString(StorageKeys.pageNamesKey, jsonEncode(sanitized));
    AppLogger.info('Saved ${sanitized.length} page names');
  }

  /// Load friendly page names
  Map<String, String> loadPageNames() {
    final raw = _prefs.getString(StorageKeys.pageNamesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to decode page names', e, stackTrace);
      return {};
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
        rules[objectId] = Rule.fromJson(
          objectId,
          ruleData as Map<String, dynamic>,
        );
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

  // ==================== Inbox Tracking ====================

  /// Load set of user IDs who have been sent inbox messages
  Set<String> loadInboxedUsers() {
    final data = _prefs.getString(StorageKeys.inboxedUsersKey);
    if (data == null) return {};

    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list.cast<String>().toSet();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load inboxed users', e, stackTrace);
      return {};
    }
  }

  /// Add a user ID to the inboxed users set
  Future<void> addInboxedUser(String userId) async {
    try {
      final inboxedUsers = loadInboxedUsers();
      inboxedUsers.add(userId);
      await _prefs.setString(
        StorageKeys.inboxedUsersKey,
        jsonEncode(inboxedUsers.toList()),
      );
      AppLogger.debug('Added user $userId to inboxed users');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add inboxed user', e, stackTrace);
      rethrow;
    }
  }

  /// Check if a user has been sent an inbox message
  bool hasInboxedUser(String userId) {
    final inboxedUsers = loadInboxedUsers();
    return inboxedUsers.contains(userId);
  }

  /// Clear all inboxed users tracking
  Future<void> clearInboxedUsers() async {
    try {
      await _prefs.remove(StorageKeys.inboxedUsersKey);
      AppLogger.info('Cleared inboxed users tracking');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear inboxed users', e, stackTrace);
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
