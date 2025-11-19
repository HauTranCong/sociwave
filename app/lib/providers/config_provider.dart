import 'package:flutter/foundation.dart';
import '../core/utils/logger.dart';
import '../data/services/storage_service.dart';
import '../domain/models/config.dart';

/// Provider for managing application configuration
class ConfigProvider extends ChangeNotifier {
  final StorageService _storage;
  
  Config _config = Config.initial();
  bool _isLoading = false;
  String? _error;

  ConfigProvider(this._storage);

  // Getters
  Config get config => _config;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConfigured => _config.isValid;

  /// Initialize provider by loading saved config
  Future<void> init() async {
    await loadConfig();
  }

  /// Load configuration from storage
  Future<void> loadConfig() async {
    try {
      _setLoading(true);
      _clearError();

      final savedConfig = await _storage.loadConfig();
      if (savedConfig != null) {
        _config = savedConfig;
        AppLogger.info('Config loaded from storage');
      } else {
        _config = Config.initial();
        AppLogger.info('Using initial config');
      }

      notifyListeners();
    } catch (e, stackTrace) {
      _setError('Failed to load config: $e');
      AppLogger.error('Failed to load config', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  /// Save configuration
  Future<bool> saveConfig(Config config) async {
    try {
      _setLoading(true);
      _clearError();

      await _storage.saveConfig(config);
      _config = config;
      
      AppLogger.info('Config saved successfully');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _setError('Failed to save config: $e');
      AppLogger.error('Failed to save config', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update configuration
  Future<bool> updateConfig({
    String? token,
    String? version,
    String? pageId,
    bool? useMockData,
  }) async {
    final updatedConfig = _config.copyWith(
      token: token,
      version: version,
      pageId: pageId,
      useMockData: useMockData,
    );
    return await saveConfig(updatedConfig);
  }

  /// Clear configuration
  Future<bool> clearConfig() async {
    try {
      _setLoading(true);
      _clearError();

      await _storage.clearConfig();
      _config = Config.initial();
      
      AppLogger.info('Config cleared');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _setError('Failed to clear config: $e');
      AppLogger.error('Failed to clear config', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Validate configuration
  bool validateConfig() {
    if (!_config.isValid) {
      _setError('Configuration is incomplete');
      return false;
    }
    _clearError();
    return true;
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
