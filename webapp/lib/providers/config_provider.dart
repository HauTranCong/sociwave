import 'package:flutter/foundation.dart';
import '../core/utils/logger.dart';
import '../data/services/storage_service.dart';
import '../data/services/api_client.dart';
import '../domain/models/config.dart';
import 'api_client_provider.dart';

/// Provider for managing application configuration
class ConfigProvider extends ChangeNotifier {
  final StorageService _storage;
  ApiClientProvider? _apiClientProvider;
  final ApiClient _fallbackClient = ApiClient();

  Config _config = Config.initial();
  bool _isLoading = false;
  String? _error;
  bool _isConnected = false;
  bool _isTestingConnection = false;
  List<String> _managedPages = [];
  String? _selectedPageId;
  final Map<String, bool> _pageConfigStatus = {};
  final Map<String, String> _pageNames = {};
  final Map<String, bool> _pageConnectionStatus = {};
  bool _hydratedFromBackend = false;

  ConfigProvider(this._storage, [ApiClientProvider? apiClientProvider]) {
    _apiClientProvider = apiClientProvider;
  }

  // Getters
  Config get config => _config;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConfigured => _config.isValid;
  bool get isConnected => _isConnected;
  bool get isTestingConnection => _isTestingConnection;
  List<String> get managedPages => List.unmodifiable(_managedPages);
  String? get selectedPageId => _selectedPageId;
  bool get hasSelectedPage =>
      _selectedPageId != null && _selectedPageId!.isNotEmpty;
  String pageLabel(String pageId) => _pageNames[pageId] ?? pageId;
  bool isPageConnected(String pageId) =>
      _pageConnectionStatus[_normalizePageId(pageId)] ?? false;
  bool isPageConfigured(String pageId) {
    final normalized = _normalizePageId(pageId);
    if (normalized == null) return false;
    return _pageConfigStatus[normalized] ?? false;
  }

  /// Initialize provider by loading saved config
  Future<void> init() async {
    await _restorePageState();
    await _hydratePagesFromBackend();
    if (!_hasAuthHeader()) {
      notifyListeners();
      return;
    }
    if (hasSelectedPage) {
      await loadConfig();
      await testConnection();
    } else {
      notifyListeners();
    }
  }

  /// Allow wiring the ApiClientProvider after construction (used by ProxyProvider)
  void updateApiClientProvider(ApiClientProvider? provider) {
    _apiClientProvider = provider;
    _apiClientProvider?.setPageId(_selectedPageId);
    // When auth token arrives after login, attempt to hydrate from backend
    _hydratePagesFromBackend();
  }

  /// Load configuration from storage
  Future<void> loadConfig() async {
    if (!_hasAuthHeader()) {
      AppLogger.warning('Skipping config load: missing auth token');
      return;
    }
    if (!hasSelectedPage) {
      AppLogger.warning('Skipping config load: no page selected');
      return;
    }
    try {
      _setLoading(true);
      _clearError();
      // Always load configuration from backend API (source of truth)
      final apiClient = _getApiClient();
      final backendConfig = await apiClient.getConfig();
      await _ensurePageTracked(backendConfig.pageId);
      await _updateSelectedPage(backendConfig.pageId, notify: false);
      await _refreshPageName(backendConfig.pageId);
      _config = backendConfig;
      _pageConfigStatus[backendConfig.pageId] = backendConfig.isValid;
      _isConnected = _pageConnectionStatus[backendConfig.pageId] ?? false;
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
      final resolvedPageId = _normalizePageId(_selectedPageId ?? config.pageId);
      if (resolvedPageId == null) {
        _setError('Select or add a page before saving configuration');
        return false;
      }
      final configToSave = config.copyWith(pageId: resolvedPageId);
      await _ensurePageTracked(resolvedPageId);
      await _updateSelectedPage(resolvedPageId, notify: false);
      // Persist to backend API (source of truth)
      final apiClient = _getApiClient();
      await apiClient.saveConfig(configToSave);

      _config = configToSave;
      _pageConfigStatus[resolvedPageId] = configToSave.isValid;
      await _refreshPageName(resolvedPageId);
      _pageConnectionStatus[resolvedPageId] = false;
      _isConnected = false;

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
    final resolvedPage = _normalizePageId(pageId ?? _selectedPageId ?? _config.pageId);
    final updatedConfig = _config.copyWith(
      token: token,
      version: version,
      pageId: resolvedPage ?? _config.pageId,
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
      final pageId = _selectedPageId ?? _config.pageId;
      if (pageId.isNotEmpty) {
        _pageConnectionStatus[pageId] = true;
      }
      notifyListeners();
      return true;
    }

    try {
      _isTestingConnection = true;
      notifyListeners();

      if (!_config.isValid) {
        _isConnected = false;
        final pageId = _selectedPageId ?? _config.pageId;
        if (pageId.isNotEmpty) {
          _pageConnectionStatus[pageId] = false;
        }
        notifyListeners();
        return false;
      }

      final apiClient = _getApiClient();
      final connected = await apiClient.testBackendConnection();

      _isConnected = connected;
      final pageId = _selectedPageId ?? _config.pageId;
      if (pageId.isNotEmpty) {
        _pageConnectionStatus[pageId] = connected;
      }

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
      final pageId = _selectedPageId ?? _config.pageId;
      if (pageId.isNotEmpty) {
        _pageConnectionStatus[pageId] = false;
      }
      notifyListeners();
      return false;
    } finally {
      _isTestingConnection = false;
      notifyListeners();
    }
  }

  /// Add a new Facebook Page scope and load its configuration
  Future<void> addPage(String pageId) async {
    final normalized = _normalizePageId(pageId);
    if (normalized == null) {
      _setError('Page ID cannot be empty');
      return;
    }
    await _ensurePageTracked(normalized);
    _pageConfigStatus[normalized] = false;
    _isConnected = false;
    await _updateSelectedPage(normalized);
    await loadConfig();
    await testConnection();
  }

  /// Add a page and immediately persist the provided configuration.
  Future<bool> addPageWithConfig(Config config) async {
    final normalized = _normalizePageId(config.pageId);
    if (normalized == null) {
      _setError('Page ID cannot be empty');
      return false;
    }

    final configToSave = config.copyWith(pageId: normalized);
    _setLoading(true);
    try {
      _clearError();
      await _ensurePageTracked(normalized);
      _pageConfigStatus[normalized] = configToSave.isValid;
      _isConnected = false;
      _pageConnectionStatus[normalized] = false;
      await _updateSelectedPage(normalized, notify: false);
      _config = configToSave;

      final apiClient = _getApiClient();
      await apiClient.saveConfig(configToSave);
      await _refreshPageName(normalized);
      notifyListeners();
      await testConnection();
      return true;
    } catch (e, stackTrace) {
      _setError('Failed to save config: $e');
      AppLogger.error('Failed to save config for new page', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Switch the active configuration scope to an existing page
  Future<void> selectPage(String pageId) async {
    final normalized = _normalizePageId(pageId);
    if (normalized == null) {
      return;
    }
    await _ensurePageTracked(normalized);
    _isConnected = false;
    await _updateSelectedPage(normalized);
    await loadConfig();
    await testConnection();
  }

  /// Remove a page from the local list and delete its backend data
  Future<void> removePage(String pageId) async {
    final normalized = _normalizePageId(pageId);
    if (normalized == null) return;

    _setLoading(true);
    try {
      _clearError();
      final apiClient = _getApiClient();
      await apiClient.deletePageData(normalized);
      AppLogger.info('Deleted page scope from backend for $normalized');
    } catch (e, stackTrace) {
      _setError('Failed to delete page: $e');
      AppLogger.error('Failed to delete page from backend', e, stackTrace);
      _setLoading(false);
      return;
    }

    final removed = _managedPages.remove(normalized);
    if (removed) {
      await _storage.saveManagedPages(_managedPages);
      _pageConfigStatus.remove(normalized);
      _pageNames.remove(normalized);
      await _persistPageNames();
      _pageConnectionStatus.remove(normalized);
    }

    if (_selectedPageId == normalized) {
      final nextPage = _managedPages.isNotEmpty ? _managedPages.first : null;
      await _updateSelectedPage(nextPage);
      if (nextPage != null) {
        await loadConfig();
      } else {
        _config = Config.initial();
        notifyListeners();
      }
    } else if (removed) {
      notifyListeners();
    }

    _setLoading(false);
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

  Future<void> _restorePageState() async {
    _managedPages = _storage.loadManagedPages();
    _pageNames
      ..clear()
      ..addAll(_storage.loadPageNames());
    final storedSelection = _storage.loadSelectedPageId();
    if (storedSelection != null) {
      await _updateSelectedPage(storedSelection, persist: false, notify: false);
    } else if (_managedPages.isNotEmpty) {
      await _updateSelectedPage(_managedPages.first, persist: false, notify: false);
    } else {
      await _updateSelectedPage(null, persist: false, notify: false);
    }
  }

  String? _normalizePageId(String? pageId) {
    if (pageId == null) return null;
    final trimmed = pageId.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _ensurePageTracked(String pageId) async {
    if (!_managedPages.contains(pageId)) {
      _managedPages.add(pageId);
      await _storage.saveManagedPages(_managedPages);
    }
  }

  Future<void> _updateSelectedPage(
    String? pageId, {
    bool persist = true,
    bool notify = true,
  }) async {
    final normalized = _normalizePageId(pageId);
    _selectedPageId = normalized;
    _fallbackClient.setPageId(normalized);
    _apiClientProvider?.setPageId(normalized);
    _config = _config.copyWith(pageId: normalized ?? '');
    _isConnected = normalized != null
        ? (_pageConnectionStatus[normalized] ?? false)
        : false;
    if (persist) {
      if (normalized == null) {
        await _storage.clearSelectedPageId();
      } else {
        await _storage.saveSelectedPageId(normalized);
      }
    }
    if (notify) {
      notifyListeners();
    }
  }

  ApiClient _getApiClient() {
    return _apiClientProvider?.client ?? _fallbackClient;
  }

  Future<void> _refreshPageName(String pageId) async {
    try {
      final apiClient = _getApiClient();
      final info = await apiClient.getPageProfile(pageId);
      final name = info['name']?.toString();
      if (name != null && name.isNotEmpty) {
        _pageNames[pageId] = name;
        await _persistPageNames();
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('Failed to refresh page name for $pageId: $e');
    }
  }

  Future<void> _persistPageNames() async {
    await _storage.savePageNames(_pageNames);
  }

  Future<void> _hydratePagesFromBackend() async {
    if (_hydratedFromBackend) return;
    // Only hydrate when we have an auth header (user is logged in)
    if (!_hasAuthHeader()) return;

    try {
      final apiClient = _getApiClient();
      final backendPages = await apiClient.getPages();
      if (backendPages.isEmpty) return;
      _managedPages = backendPages;
      await _storage.saveManagedPages(_managedPages);
      await _updateSelectedPage(_managedPages.first);
      _hydratedFromBackend = true;
      await loadConfig();
      await testConnection();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to hydrate pages from backend', e, stackTrace);
    }
  }

  bool _hasAuthHeader() {
    return _apiClientProvider?.client.getAuthHeader()?.isNotEmpty ?? false;
  }
}
