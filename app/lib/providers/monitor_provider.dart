import 'package:flutter/foundation.dart';
import '../core/utils/logger.dart';
import '../data/services/storage_service.dart';
import '../domain/models/monitor_status.dart';
import '../services/background_monitor_service.dart';

/// Provider for monitoring service status and control
class MonitorProvider extends ChangeNotifier {
  final StorageService _storage;
  final BackgroundMonitorService _monitorService;
  
  MonitorStatus _status = MonitorStatus.initial();
  bool _isInitialized = false;

  MonitorProvider(this._storage) : _monitorService = BackgroundMonitorService(_storage);

  // Getters
  MonitorStatus get status => _status;
  bool get isRunning => _status.isRunning;
  bool get isInitialized => _isInitialized;
  DateTime? get lastCheck => _status.lastCheck;
  int get totalChecks => _status.totalChecks;
  int get totalReplies => _status.totalReplies;
  String? get lastError => _status.lastError;

  /// Initialize monitor provider
  Future<void> init() async {
    try {
      // Load monitoring state
      final wasEnabled = _storage.loadMonitoringEnabled();
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
      AppLogger.info('🤖 Monitor initialized (checks: $totalChecks, replies: $totalReplies)');
      
      // Auto-start monitoring if it was previously enabled
      if (wasEnabled) {
        AppLogger.info('🔄 Auto-starting monitoring (was enabled)');
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

      // Start the background monitoring service
      final started = await _monitorService.start(
        interval: const Duration(minutes: 5),
      );

      if (!started) {
        _setError('Failed to start monitoring service');
        return false;
      }

      await _storage.saveMonitoringEnabled(true);
      _status = _status.copyWith(isRunning: true);
      
      AppLogger.info('🤖 Background monitoring started (5min interval)');
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
    return timeSinceCheck.inMinutes < 5; // Should check at least every 5 minutes
  }

  /// Get monitoring statistics summary
  Map<String, dynamic> getStatistics() {
    return {
      'isRunning': _status.isRunning,
      'totalChecks': _status.totalChecks,
      'totalReplies': _status.totalReplies,
      'averageRepliesPerCheck': _status.averageRepliesPerCheck.toStringAsFixed(2),
      'lastCheck': _status.lastCheck?.toIso8601String(),
      'hasRecentError': _status.hasRecentError,
      'isHealthy': isHealthy,
    };
  }

  // Private helpers
  void _setError(String error) {
    _status = _status.withError(error);
    notifyListeners();
  }
}
