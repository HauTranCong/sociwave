import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/utils/logger.dart';
import '../data/services/mock_api_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/api_client.dart';
import '../domain/models/config.dart';
import '../domain/models/reel.dart';

/// Provider for managing video reels
class ReelsProvider extends ChangeNotifier {
  final StorageService _storage;
  final ApiClient _apiClient = ApiClient();
  MockApiService? _mockApiService;

  List<Reel> _reels = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchTime;

  ReelsProvider(this._storage);

  // Getters
  List<Reel> get reels => _reels;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasReels => _reels.isNotEmpty;
  DateTime? get lastFetchTime => _lastFetchTime;

  /// Initialize with config
  void initialize(Config config) {
    if (config.useMockData) {
      _mockApiService = MockApiService();
      AppLogger.info('🎬 Reels: Using mock API');
    } else {
      _mockApiService = null;
      AppLogger.info('🎬 Reels: Using backend API');
    }
  }

  /// Fetch reels from API
  Future<void> fetchReels({bool forceRefresh = false}) async {
    try {
      _setLoading(true);
      _clearError();

      // Try to load from cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedReels = await _storage.loadCachedReels();
        if (cachedReels != null && cachedReels.isNotEmpty) {
          _reels = await _attachRuleStatus(cachedReels);
          _lastFetchTime = DateTime.now();
          AppLogger.info('🎬 Loaded ${_reels.length} reels (cached)');
          notifyListeners();
          return;
        }
      }

      // Fetch from API
      List<Reel> fetchedReels;
      if (_mockApiService != null) {
        fetchedReels = await _mockApiService!.getReels();
      } else {
        fetchedReels = await _apiClient.getReels();
      }

      // Attach rule status to reels
      _reels = await _attachRuleStatus(fetchedReels);
      _lastFetchTime = DateTime.now();

      // Cache the reels
      await _storage.cacheReels(fetchedReels);

      AppLogger.info('🎬 Loaded ${_reels.length} reels from API');
      notifyListeners();
    } catch (e, stackTrace) {
      // Provide clearer, actionable messages for known HTTP errors
      int? status;
      String? message;

      if (e is ApiException) {
        status = e.statusCode;
        message = e.message;
      } else if (e is DioException) {
        status = e.response?.statusCode;
        message = e.message;
      }

      if (status == 400) {
        // Backend returns 400 when Facebook config is incomplete
        _setError('Cannot load reels: Facebook configuration is incomplete.\nPlease set accessToken and pageId in Settings.');
      } else if (status == 401) {
        _setError('Unauthorized: Please login again.');
      } else if (status != null && status >= 500) {
        _setError('Server error when fetching reels (status $status). Try again later.');
      } else if (message != null) {
        _setError('Failed to fetch reels: $message');
      } else {
        _setError('Failed to fetch reels: $e');
      }

      AppLogger.error('🎬 Failed to load reels', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh reels (force fetch from API)
  Future<void> refreshReels() async {
    await fetchReels(forceRefresh: true);
  }

  /// Attach rule status to reels
  Future<List<Reel>> _attachRuleStatus(List<Reel> reels) async {
    final rules = await _storage.loadRules();

    return reels.map((reel) {
      final rule = rules[reel.id];
      return reel.copyWith(
        hasRule: rule != null,
        ruleEnabled: rule?.enabled ?? false,
      );
    }).toList();
  }

  /// Get a specific reel by ID
  Reel? getReelById(String id) {
    try {
      return _reels.firstWhere((reel) => reel.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Update reel rule status after rule change
  void updateReelRuleStatus(
    String reelId, {
    required bool hasRule,
    required bool enabled,
  }) {
    final index = _reels.indexWhere((reel) => reel.id == reelId);
    if (index != -1) {
      _reels[index] = _reels[index].copyWith(
        hasRule: hasRule,
        ruleEnabled: enabled,
      );
      notifyListeners();
    }
  }

  /// Clear all reels
  void clearReels() {
    _reels = [];
    _lastFetchTime = null;
    notifyListeners();
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
