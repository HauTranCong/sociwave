import 'package:flutter/foundation.dart';
import '../core/utils/logger.dart';
import '../data/services/storage_service.dart';
import '../domain/models/monitor_status.dart';
import '../services/background_monitor_service.dart';
import '../data/services/monitoring_service.dart';
import '../data/services/api_client.dart';
import 'api_client_provider.dart';

/// Provider for monitoring service status and control
class MonitorProvider extends ChangeNotifier {
  final StorageService _storage;
  late final BackgroundMonitorService _monitorService;
  final ApiClientProvider? _apiClientProvider;

  MonitorStatus _status = MonitorStatus.initial();
  bool _isInitialized = false;

  MonitorProvider(this._storage, [this._apiClientProvider]) {
    // Initialize background service with shared ApiClient when available
  _monitorService = BackgroundMonitorService(_storage, _apiClientProvider);
    // Set up callback to update stats in real-time
    _monitorService.onStatsUpdated = _reloadStats;
    // Set up callback to handle errors
    _monitorService.onError = _handleError;
  }

  // Getters
  MonitorStatus get status => _status;
  bool get isRunning => _status.isRunning;
  bool get isInitialized => _isInitialized;
  DateTime? get lastCheck => _status.lastCheck;
  int get totalChecks => _status.totalChecks;
  int get totalReplies => _status.totalReplies;
  String? get lastError => _status.lastError;
  Duration get monitoringInterval => _monitorService.interval;
  String get intervalText => _monitorService.intervalText;

  /// Initialize monitor provider
  Future<void> init() async {
    try {
  final monitoringService = MonitoringService(_apiClientProvider?.client ?? ApiClient());
      // Pull current settings from backend so UI reflects server state
      try {
        final backendIntervalSeconds = await monitoringService.getMonitoringInterval();
        await _monitorService.setInterval(Duration(seconds: backendIntervalSeconds));
        AppLogger.info('🛰️ Synced monitoring interval from backend: ${_monitorService.intervalText}');
      } catch (e) {
        AppLogger.warning('Failed to sync interval from backend: $e');
      }

      // Load monitoring state
      bool wasEnabled = _storage.loadMonitoringEnabled();
      try {
        // Prefer backend enabled flag if available
  wasEnabled = await monitoringService.getMonitoringEnabled();
      } catch (e) {
        AppLogger.warning('Failed to sync monitoring enabled state from backend: $e');
      }
      final lastCheckTime = _storage.loadLastMonitorCheck();
      final totalChecks = _storage.getTotalMonitorChecks();
      final totalReplies = _storage.getTotalReplies();

      _status = MonitorStatus(
        isRunning: false, // Will be started if wasEnabled
        lastCheck: lastCheckTime,
        totalChecks: totalChecks,
        totalReplies: totalReplies,
      );

      _isInitialized = true;
      AppLogger.info(
        '🤖 Monitor initialized (checks: $totalChecks, replies: $totalReplies)',
      );

      // Auto-start monitoring if it was previously enabled
      if (wasEnabled) {
        AppLogger.info('🔄 Auto-starting monitoring (was enabled)');
        // Clear any old errors before starting
        _status = _status.clearError();
        await startMonitoring();
      }

      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize MonitorProvider', e, stackTrace);
    }
  }

  /// Start monitoring
  Future<bool> startMonitoring() async {
    try {
      if (_status.isRunning) {
        AppLogger.warning('⚠️ Monitoring already running');
        return true;
      }

      // Clear any previous errors
      _status = _status.clearError();
      notifyListeners();

      // Start the background monitoring service
      final started = await _monitorService.start(
        interval: _monitorService.interval,
      );

      if (!started) {
        _setError('Failed to start monitoring service');
        return false;
      }

      await _storage.saveMonitoringEnabled(true);
      // Also enable server-side monitoring toggle if available
      try {
        await _waitForAuthIfNeeded();
  final client = _apiClientProvider?.client ?? ApiClient();
  final monitoringService = MonitoringService(client);
        await monitoringService.setMonitoringEnabled(true);
      } catch (e) {
        AppLogger.warning('Failed to enable server-side monitoring: $e');
      }
      _status = _status.copyWith(isRunning: true);

      AppLogger.info(
        '🤖 Background monitoring started (${_monitorService.intervalText} interval)',
      );
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to start monitoring', e, stackTrace);
      _setError('Failed to start monitoring: $e');
      return false;
    }
  }

  /// Stop monitoring
  Future<bool> stopMonitoring() async {
    try {
      if (!_status.isRunning) {
        AppLogger.warning('⚠️ Monitoring not running');
        return true;
      }

      // Stop the background monitoring service
      await _monitorService.stop();

      await _storage.saveMonitoringEnabled(false);
      // Also disable server-side monitoring toggle if available
      try {
        await _waitForAuthIfNeeded();
  final client = _apiClientProvider?.client ?? ApiClient();
  final monitoringService = MonitoringService(client);
        await monitoringService.setMonitoringEnabled(false);
      } catch (e) {
        AppLogger.warning('Failed to disable server-side monitoring: $e');
      }
      _status = _status.copyWith(isRunning: false);

      AppLogger.info('🛑 Background monitoring stopped');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to stop monitoring', e, stackTrace);
      _setError('Failed to stop monitoring: $e');
      return false;
    }
  }

  /// Toggle monitoring on/off
  Future<bool> toggleMonitoring() async {
    if (_status.isRunning) {
      return await stopMonitoring();
    } else {
      return await startMonitoring();
    }
  }

  /// Manually trigger a monitoring cycle
  Future<void> runMonitoringCycle() async {
    try {
      if (!_status.isRunning) {
        AppLogger.warning('⚠️ Cannot run cycle: monitoring not started');
        return;
      }

      AppLogger.info('🔄 Running manual monitoring cycle...');
      await _monitorService.performMonitoringCycle();
      await recordCheck();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to run monitoring cycle', e, stackTrace);
      _setError('Failed to run monitoring cycle: $e');
    }
  }

  /// Record a monitoring check
  Future<void> recordCheck() async {
    try {
      await _storage.incrementMonitorChecks();
      await _storage.saveLastMonitorCheck(DateTime.now());

      _status = _status.incrementChecks();
      notifyListeners();

      AppLogger.info('✅ Check recorded');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to record monitoring check', e, stackTrace);
    }
  }

  /// Record a reply
  Future<void> recordReply() async {
    try {
      await _storage.incrementTotalReplies();

      _status = _status.incrementReplies();
      notifyListeners();

      AppLogger.debug('Reply recorded');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to record reply', e, stackTrace);
    }
  }

  /// Set error
  void setError(String error) {
    _setError(error);
    AppLogger.error('Monitoring error: $error');
  }

  /// Clear error
  void clearError() {
    _status = _status.clearError();
    notifyListeners();
  }

  /// Reset statistics
  Future<bool> resetStatistics() async {
    try {
      // This would require new storage methods
      // For now, we'll just update the local status
      _status = MonitorStatus(
        isRunning: _status.isRunning,
        lastCheck: _status.lastCheck,
        totalChecks: 0,
        totalReplies: 0,
      );

      AppLogger.info('Statistics reset');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to reset statistics', e, stackTrace);
      return false;
    }
  }

  /// Get monitoring status text
  String getStatusText() {
    return _status.statusText;
  }

  /// Check if monitoring is healthy
  bool get isHealthy {
    if (!_status.isRunning) return true; // Stopped is considered healthy
    if (_status.hasRecentError) return false;
    if (_status.lastCheck == null) return true; // Just started

    // Check if last check was within acceptable time
    final timeSinceCheck = DateTime.now().difference(_status.lastCheck!);
    return timeSinceCheck.inMinutes <
        5; // Should check at least every 5 minutes
  }

  /// Get monitoring statistics summary
  Map<String, dynamic> getStatistics() {
    return {
      'isRunning': _status.isRunning,
      'totalChecks': _status.totalChecks,
      'totalReplies': _status.totalReplies,
      'averageRepliesPerCheck': _status.averageRepliesPerCheck.toStringAsFixed(
        2,
      ),
      'lastCheck': _status.lastCheck?.toIso8601String(),
      'hasRecentError': _status.hasRecentError,
      'isHealthy': isHealthy,
      'interval': intervalText,
      'intervalMinutes': monitoringInterval.inMinutes,
    };
  }

  /// Set monitoring interval
  /// Returns true if successful, false otherwise
  Future<bool> setMonitoringInterval(Duration interval) async {
    try {
      if (interval.inSeconds < 60) {
        AppLogger.warning('⚠️ Interval too short (minimum 1 minute)');
        _setError('Interval must be at least 1 minute');
        return false;
      }

      final success = await _monitorService.setInterval(interval);

      if (success) {
        AppLogger.info(
          '✅ Monitoring interval updated to ${_monitorService.intervalText}',
        );
        notifyListeners(); // Notify listeners about interval change
        return true;
      } else {
        _setError('Failed to set monitoring interval');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set monitoring interval', e, stackTrace);
      _setError('Failed to set interval: $e');
      return false;
    }
  }

  /// Set monitoring interval in minutes (convenience method)
  Future<bool> setIntervalMinutes(int minutes) async {
    if (minutes < 1) {
      AppLogger.warning('⚠️ Interval must be at least 1 minute');
      return false;
    }
    return await setMonitoringInterval(Duration(minutes: minutes));
  }

  /// Set monitoring interval in hours (convenience method)
  Future<bool> setIntervalHours(int hours) async {
    if (hours < 1) {
      AppLogger.warning('⚠️ Interval must be at least 1 hour');
      return false;
    }
    return await setMonitoringInterval(Duration(hours: hours));
  }

  // Private helpers
  void _setError(String error) {
    _status = _status.withError(error);
    notifyListeners();
  }

  /// Reload statistics from storage (called by background service)
  void _reloadStats() {
    try {
      final lastCheckTime = _storage.loadLastMonitorCheck();
      final totalChecks = _storage.getTotalMonitorChecks();
      final totalReplies = _storage.getTotalReplies();

      _status = _status.copyWith(
        lastCheck: lastCheckTime,
        totalChecks: totalChecks,
        totalReplies: totalReplies,
      );

      notifyListeners();
      AppLogger.debug(
        '📊 Stats reloaded: checks=$totalChecks, replies=$totalReplies',
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to reload stats', e, stackTrace);
    }
  }

  /// Handle error from background service
  void _handleError(String error) {
    AppLogger.error('📛 Background monitoring error: $error');
    _setError(error);
  }

  /// Wait a short amount of time for auth header to propagate to shared client
  Future<void> _waitForAuthIfNeeded({Duration timeout = const Duration(seconds: 2)}) async {
    if (_apiClientProvider == null) return;
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final header = _apiClientProvider.client.getAuthHeader();
      if (header != null && header.isNotEmpty) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    AppLogger.warning('Auth header did not appear on shared ApiClient within ${timeout.inSeconds}s');
  }

}
