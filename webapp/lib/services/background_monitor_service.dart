import 'dart:async';
import '../core/utils/logger.dart';
import '../data/services/api_client.dart';
import '../data/services/storage_service.dart';

/// Background service for monitoring comments and auto-replying
///
/// This service:
/// 1. Fetches reels from API
/// 2. Gets comments for each reel
/// 3. Checks if comments match rule keywords
/// 4. Posts auto-replies for matching comments
/// 5. Tracks replied comments to avoid duplicates
class BackgroundMonitorService {
  final StorageService _storage;
  final ApiClient _apiClient = ApiClient();

  Timer? _timer;
  bool _isRunning = false;
  Duration _interval = const Duration(minutes: 5);

  // Callback to notify when statistics are updated
  Function()? onStatsUpdated;

  // Callback to notify when an error occurs
  Function(String)? onError;

  BackgroundMonitorService(this._storage);

  /// Start monitoring with specified interval
  Future<bool> start({Duration interval = const Duration(minutes: 5)}) async {
    if (_isRunning) {
      AppLogger.info('Background monitoring is already running');
      return true; // Return true since it's already running successfully
    }

    try {
      // Set the interval
      _interval = interval;

      _isRunning = true;
      await _storage.saveMonitoringEnabled(true);

      // Run first check immediately
      await performMonitoringCycle();

      // Start periodic timer
      _timer = Timer.periodic(_interval, (_) => performMonitoringCycle());

      AppLogger.info(
        'Background monitoring started (interval: ${_formatInterval(_interval)})',
      );
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to start monitoring', e, stackTrace);
      return false;
    }
  }

  /// Stop monitoring
  Future<void> stop() async {
    if (!_isRunning) {
      AppLogger.warning('Background monitoring is not running');
      return;
    }

    _timer?.cancel();
    _timer = null;
    _isRunning = false;

    await _storage.saveMonitoringEnabled(false);

    AppLogger.info('Background monitoring stopped');
  }

  /// Check if monitoring is currently running
  bool get isRunning => _isRunning;

  /// Get the current monitoring interval
  Duration get interval => _interval;

  /// Get a formatted string of the interval
  String get intervalText => _formatInterval(_interval);

  /// Set a new monitoring interval
  /// If monitoring is running, it will restart with the new interval
  Future<bool> setInterval(Duration newInterval) async {
    if (newInterval.inSeconds < 60) {
      AppLogger.warning('Interval too short (minimum 1 minute)');
      return false;
    }

    _interval = newInterval;
    AppLogger.info('Monitoring interval set to ${_formatInterval(_interval)}');

    // If monitoring is running, restart with new interval
    if (_isRunning) {
      AppLogger.info('Restarting monitoring with new interval');

      // Cancel existing timer
      _timer?.cancel();

      // Start new timer with updated interval
      _timer = Timer.periodic(_interval, (_) => performMonitoringCycle());

      AppLogger.info(
        'Monitoring restarted with ${_formatInterval(_interval)} interval',
      );
    }

    return true;
  }

  /// Format interval duration to human-readable string
  String _formatInterval(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }

  /// Perform one complete monitoring cycle
  Future<void> performMonitoringCycle() async {
    try {
      AppLogger.info('Starting monitoring cycle');
      final startTime = DateTime.now();
      // Delegate monitoring logic to backend service
      await _apiClient.triggerMonitoring();

      // Record statistics
      await _recordMonitoringCheck();

      final duration = DateTime.now().difference(startTime);
      AppLogger.info('Monitoring cycle completed in ${duration.inSeconds}s');
    } catch (e, stackTrace) {
      AppLogger.error('Monitoring cycle failed', e, stackTrace);

      // Notify provider about the error
      final errorMessage = e.toString();
      if (errorMessage.contains('expired')) {
        onError?.call(
          'Access token has expired. Please update your token in Settings.',
        );
      } else if (errorMessage.contains('Unauthorized')) {
        onError?.call(
          'Invalid access token. Please check your credentials in Settings.',
        );
      } else if (errorMessage.contains('Rate Limit')) {
        onError?.call('API rate limit exceeded. Monitoring will retry later.');
      } else {
        onError?.call('Monitoring failed: ${e.toString()}');
      }

      // Don't throw - keep monitoring running
    }
  }

  /// Record a monitoring check
  Future<void> _recordMonitoringCheck() async {
    await _storage.saveLastMonitorCheck(DateTime.now());
    await _storage.incrementMonitorChecks();

    // Notify provider about stats update
    onStatsUpdated?.call();
  }
}

/// Extension to convert map entries back to map
extension _MapFromEntries<K, V> on Iterable<MapEntry<K, V>> {
  Map<K, V> toMap() => Map.fromEntries(this);
}
