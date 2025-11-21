import 'dart:async';
import '../core/utils/logger.dart';
import '../data/services/facebook_api_service.dart';
import '../data/services/mock_api_service.dart';
import '../data/services/storage_service.dart';
import '../domain/models/comment.dart';
import '../domain/models/reel.dart';
import '../domain/models/rule.dart';

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
  FacebookApiService? _apiService;
  MockApiService? _mockApiService;

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
      // Load configuration
      final config = await _storage.loadConfig();
      if (config == null || !config.isValid) {
        AppLogger.error('Cannot start monitoring: Invalid configuration');
        return false;
      }

      // Initialize API service based on config
      if (config.useMockData) {
        _mockApiService = MockApiService();
        _apiService = null;
        AppLogger.info('Using Mock API for monitoring');
      } else {
        _apiService = FacebookApiService(config);
        _mockApiService = null;
        AppLogger.info('Using Facebook API for monitoring');
      }

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

      // 1. Load enabled rules
      final rules = await _storage.loadRules();
      final enabledRules = rules.entries
          .where((entry) => entry.value.enabled)
          .map((entry) => MapEntry(entry.key, entry.value))
          .toMap();

      if (enabledRules.isEmpty) {
        AppLogger.info('No enabled rules found, skipping cycle');
        await _recordMonitoringCheck();
        return;
      }

      AppLogger.debug('Found ${enabledRules.length} enabled rules');

      // 2. Fetch reels
      List<Reel> reels;
      if (_mockApiService != null) {
        reels = await _mockApiService!.getReels();
      } else if (_apiService != null) {
        reels = await _apiService!.getReels();
      } else {
        throw Exception('No API service configured');
      }

      AppLogger.debug('Fetched ${reels.length} reels');

      // 3. Load config to get page ID
      final config = await _storage.loadConfig();
      final pageId = config?.pageId ?? '';

      // 4. Process each reel
      for (final reel in reels) {
        try {
          await _processReel(reel, enabledRules, pageId);
        } catch (e, stackTrace) {
          AppLogger.error('Error processing reel ${reel.id}', e, stackTrace);
          // Continue with next reel
        }
      }

      // 5. Record statistics
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

  /// Process a single reel
  Future<void> _processReel(
    Reel reel,
    Map<String, Rule> enabledRules,
    String pageId,
  ) async {
    // Check if this reel has an enabled rule
    final rule = enabledRules[reel.id];
    if (rule == null) {
      return; // No rule for this reel
    }

    // Fetch comments for this reel
    List<Comment> comments;
    if (_mockApiService != null) {
      comments = await _mockApiService!.getComments(reel.id);
    } else if (_apiService != null) {
      comments = await _apiService!.getComments(reel.id);
    } else {
      return;
    }

    AppLogger.debug(
      'Processing ${comments.length} comments for reel ${reel.id}',
    );

    // Process each comment
    for (final comment in comments) {
      // Skip if page has already replied (check nested replies)
      if (comment.hasPageReplied(pageId)) {
        continue;
      }

      // Check if comment matches rule keywords
      if (rule.matches(comment.message)) {
        try {
          // Post reply
          if (_mockApiService != null) {
            await _mockApiService!.replyToComment(
              comment.id,
              rule.replyMessage,
            );
          } else if (_apiService != null) {
            await _apiService!.replyToComment(comment.id, rule.replyMessage);
          }

          // Increment total replies counter
          await _storage.incrementTotalReplies();

          // Notify provider about stats update
          onStatsUpdated?.call();

          AppLogger.info(
            'Auto-replied to comment ${comment.id} on reel ${reel.id}',
          );

          // Send inbox message if configured
          // Note: Facebook only allows one private reply per comment, so no need to track
          // We can send even if 'from' is null - Facebook uses comment_id, not user id
          if (rule.inboxMessage != null && rule.inboxMessage!.isNotEmpty) {
            try {
              if (_apiService != null) {
                // Use Facebook's Private Replies API
                // This sends a message to Messenger using the comment_id
                // Works even if the user hasn't messaged the page before
                // Works even if we don't know who the user is (from is null)
                // Facebook enforces "one private reply per comment" automatically
                await _apiService!.sendPrivateReply(
                  comment.id,
                  rule.inboxMessage!,
                );
                
                AppLogger.info(
                  '📬 Sent private reply to ${comment.authorName} for comment ${comment.id}',
                );
              }
            } catch (e, stackTrace) {
              // Check if it's a "user unavailable" error (common with Facebook messaging)
              final errorMessage = e.toString();
              if (errorMessage.contains('#551') || 
                  errorMessage.contains('unavailable') ||
                  errorMessage.contains('User is unavailable') ||
                  errorMessage.contains('không có mặt')) {
                AppLogger.warning(
                  '⚠️ User ${comment.authorName} is unavailable for private messages (may have blocked page or privacy restrictions)',
                );
              } else {
                AppLogger.error(
                  'Failed to send private reply to ${comment.authorId}',
                  e,
                  stackTrace,
                );
              }
              // Continue - don't fail the whole process
            }
          }
        } catch (e, stackTrace) {
          AppLogger.error(
            'Failed to reply to comment ${comment.id}',
            e,
            stackTrace,
          );
          // Continue with next comment
        }
      }
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
