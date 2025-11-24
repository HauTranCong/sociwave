import 'package:flutter/foundation.dart';
import '../core/utils/logger.dart';
import '../data/services/mock_api_service.dart';
import '../data/services/api_client.dart';
import '../domain/models/comment.dart';
import '../domain/models/config.dart';

/// Provider for managing comments
class CommentsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  MockApiService? _mockApiService;
  Config? _config;

  final Map<String, List<Comment>> _commentsByReel = {};
  bool _isLoading = false;
  String? _error;
  String? _currentReelId;

  CommentsProvider();

  // Getters
  List<Comment> get currentComments {
    if (_currentReelId == null) return [];
    return _commentsByReel[_currentReelId] ?? [];
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentReelId => _currentReelId;
  int get currentCommentCount => currentComments.length;
  int get newCommentCount => currentComments.where((c) => !c.hasReplied).length;

  /// Initialize with config
  void initialize(Config config) {
    _config = config;
    if (config.useMockData) {
      _mockApiService = MockApiService();
      AppLogger.info('📝 Comments: Using mock API');
    } else {
      _mockApiService = null;
      AppLogger.info('📝 Comments: Using backend API');
    }
  }

  /// Fetch comments for a specific reel
  Future<void> fetchComments(String reelId, {bool refresh = false}) async {
    try {
      _setLoading(true);
      _clearError();
      _currentReelId = reelId;

      // Return cached if not refreshing
      if (!refresh && _commentsByReel.containsKey(reelId)) {
        AppLogger.info('Using cached comments for $reelId');
        notifyListeners();
        return;
      }

      // Fetch from API
      List<Comment> fetchedComments;
      if (_mockApiService != null) {
        fetchedComments = await _mockApiService!.getComments(reelId);
      } else {
        fetchedComments = await _apiClient.getComments(reelId);
      }

      // Mark replied status based on nested replies (check if page has already replied)
      final pageId = _config?.pageId ?? '';
      final commentsWithStatus = fetchedComments.map((comment) {
        return comment.copyWith(hasReplied: comment.hasPageReplied(pageId));
      }).toList();

      _commentsByReel[reelId] = commentsWithStatus;

      AppLogger.info('📝 Loaded ${commentsWithStatus.length} comments');
      notifyListeners();
    } catch (e, stackTrace) {
      _setError('Failed to fetch comments: $e');
      AppLogger.error('📝 Failed to load comments', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh comments for current reel
  Future<void> refreshComments() async {
    if (_currentReelId != null) {
      await fetchComments(_currentReelId!, refresh: true);
    }
  }

  /// Reply to a comment
  Future<bool> replyToComment(String commentId, String message) async {
    try {
      _setLoading(true);
      _clearError();

      // Post reply via API
      if (_mockApiService != null) {
        await _mockApiService!.replyToComment(commentId, message);
      } else {
        await _apiClient.replyToComment(commentId, message);
      }

      // Mark as replied
      await _markAsReplied(commentId);

      AppLogger.info('Successfully replied to comment $commentId');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _setError('Failed to reply to comment: $e');
      AppLogger.error('Failed to reply to comment $commentId', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Mark comment as replied (by refreshing to get updated replies from API)
  Future<void> _markAsReplied(String commentId) async {
    // Update comment status in cache optimistically
    for (final comments in _commentsByReel.values) {
      final index = comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        comments[index] = comments[index].copyWith(hasReplied: true);
      }
    }
  }

  /// Get comments for a specific reel (from cache)
  List<Comment> getCommentsForReel(String reelId) {
    return _commentsByReel[reelId] ?? [];
  }

  /// Get new (unreplied) comments for a reel
  List<Comment> getNewCommentsForReel(String reelId) {
    final comments = _commentsByReel[reelId] ?? [];
    return comments.where((c) => !c.hasReplied).toList();
  }

  /// Get all new comments across all reels
  List<Comment> getAllNewComments() {
    final allComments = <Comment>[];
    for (final comments in _commentsByReel.values) {
      allComments.addAll(comments.where((c) => !c.hasReplied));
    }
    return allComments;
  }

  /// Clear comments for a specific reel
  void clearCommentsForReel(String reelId) {
    _commentsByReel.remove(reelId);
    if (_currentReelId == reelId) {
      _currentReelId = null;
    }
    notifyListeners();
  }

  /// Clear all comments
  void clearAllComments() {
    _commentsByReel.clear();
    _currentReelId = null;
    notifyListeners();
  }

  /// Get total comment count across all reels
  int get totalCommentCount {
    return _commentsByReel.values.fold(
      0,
      (sum, comments) => sum + comments.length,
    );
  }

  /// Get total new comment count across all reels
  int get totalNewCommentCount {
    return _commentsByReel.values.fold(
      0,
      (sum, comments) => sum + comments.where((c) => !c.hasReplied).length,
    );
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
