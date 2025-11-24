import 'package:flutter/foundation.dart';
import '../core/utils/logger.dart';
import '../data/services/storage_service.dart';
import '../data/services/facebook_api_service.dart';
import '../data/services/api_client.dart';
import '../domain/models/config.dart';

/// Provider for managing application configuration
class ConfigProvider extends ChangeNotifier {
  final StorageService _storage;

  Config _config = Config.initial();
  bool _isLoading = false;
  String? _error;
  bool _isConnected = false;
  bool _isTestingConnection = false;

  ConfigProvider(this._storage);

  // Getters
  Config get config => _config;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConfigured => _config.isValid;
  bool get isConnected => _isConnected;
  bool get isTestingConnection => _isTestingConnection;

  /// Initialize provider by loading saved config
  Future<void> init() async {
    await loadConfig();
  }

  /// Load configuration from storage
  Future<void> loadConfig() async {
    try {
      _setLoading(true);
      _clearError();
      // Always load configuration from backend API (source of truth)
      final apiClient = ApiClient();
      final backendConfig = await apiClient.getConfig();
      _config = backendConfig;
      AppLogger.info('Config loaded from backend');
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
      // Persist to backend API (source of truth)
      final apiClient = ApiClient();
      await apiClient.saveConfig(config);

      _config = config;

      AppLogger.info('Config saved successfully (backend)');
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
    int? reelsLimit,
    int? commentsLimit,
  }) async {
    final updatedConfig = _config.copyWith(
      token: token,
      version: version,
      pageId: pageId,
      useMockData: useMockData,
      reelsLimit: reelsLimit,
      commentsLimit: commentsLimit,
    );
    return await saveConfig(updatedConfig);
  }

  /// Clear configuration
  Future<bool> clearConfig() async {
    try {
      _setLoading(true);
      _clearError();
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

  /// Test API connection
  Future<bool> testConnection() async {
    if (_config.useMockData) {
      _isConnected = true;
      notifyListeners();
      return true;
    }

    if (!_config.isValid) {
      _isConnected = false;
      notifyListeners();
      return false;
    }

    try {
      _isTestingConnection = true;
      notifyListeners();

      final apiService = FacebookApiService(_config);
      final connected = await apiService.testConnection();

      _isConnected = connected;

      if (connected) {
        AppLogger.info('✅ API connection successful');
      } else {
        AppLogger.warning('❌ API connection failed');
      }

      notifyListeners();
      return connected;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to test API connection', e, stackTrace);
      _isConnected = false;
      notifyListeners();
      return false;
    } finally {
      _isTestingConnection = false;
      notifyListeners();
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
