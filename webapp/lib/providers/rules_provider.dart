import 'package:flutter/foundation.dart';
import '../core/utils/logger.dart';
import '../data/services/storage_service.dart';
import '../data/services/api_client.dart';
import '../domain/models/rule.dart';

/// Provider for managing auto-reply rules
class RulesProvider extends ChangeNotifier {
  final StorageService _storage;
  final ApiClient _apiClient = ApiClient();

  Map<String, Rule> _rules = {};
  bool _isLoading = false;
  String? _error;

  RulesProvider(this._storage);

  // Getters
  Map<String, Rule> get rules => _rules;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get ruleCount => _rules.length;
  int get enabledRuleCount => _rules.values.where((r) => r.enabled).length;

  /// Initialize by loading rules
  Future<void> init() async {
    await loadRules();
  }

  /// Load all rules from storage
  Future<void> loadRules() async {
    try {
      _setLoading(true);
      _clearError();
      // Load rules from backend (source of truth)
      _rules = await _apiClient.getRules();
      // Optionally mirror to local storage for offline/fast startup use
      await _storage.saveRules(_rules);

      AppLogger.info('Loaded ${_rules.length} rules from backend');
      notifyListeners();
    } catch (e, stackTrace) {
      _setError('Failed to load rules: $e');
      AppLogger.error('Failed to load rules', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  /// Get rule for a specific object ID
  Rule? getRule(String objectId) {
    return _rules[objectId];
  }

  /// Check if a rule exists for an object
  bool hasRule(String objectId) {
    return _rules.containsKey(objectId);
  }

  /// Check if rule is enabled for an object
  bool isRuleEnabled(String objectId) {
    return _rules[objectId]?.enabled ?? false;
  }

  /// Save or update a rule
  Future<bool> saveRule(Rule rule) async {
    try {
      _setLoading(true);
      _clearError();
      // Update local map
      _rules[rule.objectId] = rule;
      // Persist full rule set to backend
      await _apiClient.saveRules(_rules);
      // Mirror to local storage
      await _storage.saveRules(_rules);

      AppLogger.info('Saved rule for ${rule.objectId} (backend + cache)');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _setError('Failed to save rule: $e');
      AppLogger.error('Failed to save rule', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Toggle rule enabled state
  Future<bool> toggleRule(String objectId) async {
    final rule = _rules[objectId];
    if (rule == null) {
      _setError('Rule not found for $objectId');
      return false;
    }

    final updatedRule = rule.copyWith(enabled: !rule.enabled);
    return await saveRule(updatedRule);
  }

  /// Update rule
  Future<bool> updateRule(
    String objectId, {
    List<String>? matchWords,
    String? replyMessage,
    String? inboxMessage,
    bool? enabled,
  }) async {
    final rule = _rules[objectId];
    if (rule == null) {
      // Create new rule if it doesn't exist
      final newRule = Rule(
        objectId: objectId,
        matchWords: matchWords ?? [],
        replyMessage: replyMessage ?? '',
        inboxMessage: inboxMessage,
        enabled: enabled ?? false,
      );
      return await saveRule(newRule);
    }

    final updatedRule = rule.copyWith(
      matchWords: matchWords,
      replyMessage: replyMessage,
      inboxMessage: inboxMessage,
      enabled: enabled,
    );
    return await saveRule(updatedRule);
  }

  /// Delete a rule
  Future<bool> deleteRule(String objectId) async {
    try {
      _setLoading(true);
      _clearError();

      _rules.remove(objectId);
      // Persist updated rules to backend
      await _apiClient.saveRules(_rules);
      // Mirror to local storage
      await _storage.saveRules(_rules);

      AppLogger.info('Deleted rule for $objectId (backend + cache)');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _setError('Failed to delete rule: $e');
      AppLogger.error('Failed to delete rule', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get all enabled rules
  Map<String, Rule> getEnabledRules() {
    return Map.fromEntries(
      _rules.entries.where((entry) => entry.value.enabled),
    );
  }

  /// Get rules for specific object IDs
  Map<String, Rule> getRulesForObjects(List<String> objectIds) {
    return Map.fromEntries(
      _rules.entries.where((entry) => objectIds.contains(entry.key)),
    );
  }

  /// Validate rule
  bool validateRule(Rule rule) {
    if (!rule.isValid) {
      _setError('Rule is invalid: reply message is required');
      return false;
    }
    _clearError();
    return true;
  }

  /// Clear all rules
  Future<bool> clearAllRules() async {
    try {
      _setLoading(true);
      _clearError();

      _rules.clear();
      // Persist empty rule set to backend
      await _apiClient.saveRules(_rules);
      // Clear local cache
      await _storage.saveRules(_rules);

      AppLogger.info('Cleared all rules (backend + cache)');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _setError('Failed to clear rules: $e');
      AppLogger.error('Failed to clear rules', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Private helpers
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
