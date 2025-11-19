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
  
  BackgroundMonitorService(this._storage);

  /// Start monitoring with specified interval
  Future<bool> start({Duration interval = const Duration(minutes: 5)}) async {
    if (_isRunning) {
      AppLogger.warning('Background monitoring is already running');
      return false;
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

      _isRunning = true;
      await _storage.saveMonitoringEnabled(true);
      
      // Run first check immediately
      await performMonitoringCycle();
      
      // Start periodic timer
      _timer = Timer.periodic(interval, (_) => performMonitoringCycle());
      
      AppLogger.info('Background monitoring started (interval: ${interval.inMinutes}m)');
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

      // 3. Load replied comments to avoid duplicates
      final repliedComments = await _storage.loadRepliedComments();

      // 4. Process each reel
      for (final reel in reels) {
        try {
          await _processReel(reel, enabledRules, repliedComments);
        } catch (e, stackTrace) {
          AppLogger.error('Error processing reel ${reel.id}', e, stackTrace);
          // Continue with next reel
        }
      }

      // 5. Save updated replied comments
      await _storage.saveRepliedComments(repliedComments);

      // 6. Record statistics
      await _recordMonitoringCheck();
      
      final duration = DateTime.now().difference(startTime);
      AppLogger.info('Monitoring cycle completed in ${duration.inSeconds}s');
      
    } catch (e, stackTrace) {
      AppLogger.error('Monitoring cycle failed', e, stackTrace);
      // Don't throw - keep monitoring running
    }
  }

  /// Process a single reel
  Future<void> _processReel(
    Reel reel,
    Map<String, Rule> enabledRules,
    Set<String> repliedComments,
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

    AppLogger.debug('Processing ${comments.length} comments for reel ${reel.id}');

    // Process each comment
    for (final comment in comments) {
      // Skip if already replied
      if (repliedComments.contains(comment.id)) {
        continue;
      }

      // Check if comment matches rule keywords
      if (rule.matches(comment.message)) {
        try {
          // Post reply
          if (_mockApiService != null) {
            await _mockApiService!.replyToComment(comment.id, rule.replyMessage);
          } else if (_apiService != null) {
            await _apiService!.replyToComment(comment.id, rule.replyMessage);
          }

          // Mark as replied
          repliedComments.add(comment.id);
          await _storage.incrementTotalReplies();
          
          AppLogger.info('Auto-replied to comment ${comment.id} on reel ${reel.id}');
        } catch (e, stackTrace) {
          AppLogger.error('Failed to reply to comment ${comment.id}', e, stackTrace);
          // Continue with next comment
        }
      }
    }
  }

  /// Record a monitoring check
  Future<void> _recordMonitoringCheck() async {
    await _storage.saveLastMonitorCheck(DateTime.now());
    await _storage.incrementMonitorChecks();
  }
}

/// Extension to convert map entries back to map
extension _MapFromEntries<K, V> on Iterable<MapEntry<K, V>> {
  Map<K, V> toMap() => Map.fromEntries(this);
}
