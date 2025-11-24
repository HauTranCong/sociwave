import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/models/config.dart';
import '../../domain/models/reel.dart';
import '../../domain/models/comment.dart';

/// Service for Facebook Graph API communication
///
/// Corresponds to Python's FacebookAPI class in facebook/api.py
class FacebookApiService {
  final Dio _dio;
  final Config config;

  FacebookApiService(this.config) : _dio = Dio() {
    _configureDio();
  }

  /// Configure Dio with interceptors and options
  void _configureDio() {
    // Ensure baseUrl ends with a slash
    final baseUrlWithVersion = '${ApiConstants.baseUrl}/${config.version}/';

    _dio.options = BaseOptions(
      baseUrl: baseUrlWithVersion,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 500,
    );

    // Add request interceptor for logging (only errors)
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          final uri = error.requestOptions.uri;
          final statusCode = error.response?.statusCode ?? '?';
          AppLogger.error('🌐 API Error: $statusCode ${uri.path}', error);
          return handler.next(error);
        },
      ),
    );
  }

  /// Build query parameters with access token
  Map<String, dynamic> _buildParams([Map<String, dynamic>? params]) {
    return {ApiConstants.accessTokenParam: config.token, ...?params};
  }

  /// Build comment fields with dynamic replies limit
  String _buildCommentFields() {
    return 'id,message,from,created_time,updated_time,comments.limit(${config.repliesLimit}).summary(true){id,message,from,created_time}';
  }

  // ==================== User Info ====================

  /// Get user/page information
  ///
  /// Python equivalent: def get_user_info(self)
  Future<Map<String, dynamic>> getUserInfo() async {
    try {
      final response = await _dio.get(
        config.pageId,
        queryParameters: _buildParams({
          ApiConstants.fieldsParam: ApiConstants.userFields,
        }),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw _handleError(response);
      }
    } on DioException {
      rethrow;
    }
  }

  // ==================== Reels ====================

  /// Get video reels
  ///
  /// Python equivalent: def get_reels(self)
  Future<List<Reel>> getReels({int? limit}) async {
    try {
      final endpoint = '${config.pageId}/${ApiConstants.reelsEndpoint}';
      final response = await _dio.get(
        endpoint,
        queryParameters: _buildParams({
          ApiConstants.fieldsParam: ApiConstants.reelFields,
          ApiConstants.limitParam: limit ?? config.reelsLimit,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final reelsData = data['data'] as List<dynamic>? ?? [];

        final reels = reelsData
            .map((json) => Reel.fromJson(json as Map<String, dynamic>))
            .toList();

        AppLogger.info('🌐 API: Fetched ${reels.length} reels');
        return reels;
      } else {
        throw _handleError(response);
      }
    } on DioException {
      rethrow;
    }
  }

  // ==================== Comments ====================

  /// Get comments for a specific object (post or reel)
  ///
  /// Python equivalent: def get_comments(self, object_id)
  Future<List<Comment>> getComments(String objectId, {int? limit}) async {
    try {
      final endpoint = '$objectId/${ApiConstants.commentsEndpoint}';
      final response = await _dio.get(
        endpoint,
        queryParameters: _buildParams({
          ApiConstants.fieldsParam: _buildCommentFields(),
          ApiConstants.limitParam: limit ?? config.commentsLimit,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final commentsData = data['data'] as List<dynamic>? ?? [];

        // Parse all parent comments (including those without 'from' field)
        final parentComments = commentsData
            .map((json) => Comment.fromJson(json as Map<String, dynamic>))
            .toList();

        // Count comments without author info (deleted/restricted users)
        final commentsWithoutAuthor = parentComments
            .where((c) => c.from == null)
            .length;
        if (commentsWithoutAuthor > 0) {
          AppLogger.debug(
            'Found $commentsWithoutAuthor comment(s) without author info (deleted/restricted users) - will show as "[Unknown User]"',
          );
        }

        AppLogger.info(
          '🌐 API: Fetched ${parentComments.length} user comments',
        );
        return parentComments;
      } else {
        throw _handleError(response);
      }
    } on DioException {
      rethrow;
    }
  }

  /// Reply to a comment
  ///
  /// Python equivalent: def reply_to_comment(self, comment_id, message)
  Future<Map<String, dynamic>> replyToComment(
    String commentId,
    String message,
  ) async {
    try {
      final endpoint = '$commentId/${ApiConstants.commentsEndpoint}';
      final response = await _dio.post(
        endpoint,
        queryParameters: _buildParams({ApiConstants.messageParam: message}),
      );

      if (response.statusCode == 200) {
        AppLogger.info('🌐 API: Reply posted');
        return response.data as Map<String, dynamic>;
      } else {
        throw _handleError(response);
      }
    } on DioException {
      rethrow;
    }
  }

  /// Send a private reply to a comment using Facebook's Private Replies API
  ///
  /// This sends a message to the person's Messenger inbox with a link to their comment.
  ///
  /// Key differences from regular messaging:
  /// - Uses comment_id in recipient field (not user id)
  /// - Works for commenters who haven't messaged the page
  /// - Must be sent within 7 days of the comment
  /// - Only one private reply can be sent per comment
  /// - When user responds, you can continue the conversation (24h window)
  ///
  /// Requires pages_messaging permission
  ///
  /// Reference: https://developers.facebook.com/docs/messenger-platform/send-messages/private-replies
  Future<Map<String, dynamic>> sendPrivateReply(
    String commentId,
    String message,
  ) async {
    try {
      // Use the Private Replies API - send to page's messages endpoint
      // with comment_id in recipient (not the old private_replies endpoint)
      final endpoint = '${config.pageId}/messages';

      AppLogger.debug('📤 Sending private reply for comment $commentId');

      final response = await _dio.post(
        endpoint,
        queryParameters: _buildParams(),
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: {
          'recipient': {
            'comment_id': commentId, // Use comment_id instead of user id
          },
          'message': {'text': message},
        },
      );

      if (response.statusCode == 200) {
        AppLogger.info('📬 API: Private reply sent for comment $commentId');
        return response.data as Map<String, dynamic>;
      } else {
        throw _handleError(response);
      }
    } on DioException catch (e) {
      AppLogger.error('Failed to send private reply', e);
      rethrow;
    }
  }

  /// Send a private reply using comment_id (Facebook Private Replies API)
  ///
  /// This is an alias for sendPrivateReply for backwards compatibility
  /// and clearer naming when called from other parts of the code.
  ///
  /// Uses comment_id in recipient field which works for commenters
  /// who haven't messaged the page before (unlike user id method).
  ///
  /// Limitations:
  /// - Only one private reply per comment
  /// - Must be sent within 7 days of comment
  /// - Requires pages_messaging permission
  Future<Map<String, dynamic>> sendPrivateMessage(
    String commentId,
    String message,
  ) async {
    // Use the Private Replies API with comment_id
    return sendPrivateReply(commentId, message);
  }

  /// Send a direct message to a user via Facebook Messenger (legacy method)
  ///
  /// Note: This method uses user ID and typically fails with error #551
  /// because users must message the page first. Use sendPrivateReply instead.
  ///
  /// Kept for reference but not recommended for use.
  Future<Map<String, dynamic>> sendDirectMessageToUser(
    String userId,
    String message,
  ) async {
    try {
      // Use the Send API endpoint with user id
      final endpoint = '${config.pageId}/messages';

      AppLogger.debug('📤 Sending direct message to user $userId');

      final response = await _dio.post(
        endpoint,
        queryParameters: _buildParams(),
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: {
          'recipient': {'id': userId},
          'messaging_type': 'RESPONSE',
          'message': {'text': message},
        },
      );

      if (response.statusCode == 200) {
        AppLogger.info('📬 API: Direct message sent to user $userId');
        return response.data as Map<String, dynamic>;
      } else {
        throw _handleError(response);
      }
    } on DioException catch (e) {
      // Handle specific Facebook API errors
      final errorData = e.response?.data;
      if (errorData is Map<String, dynamic> && errorData.containsKey('error')) {
        final error = errorData['error'] as Map<String, dynamic>;
        final errorCode = error['code'] as int?;
        final errorMessage = error['message'] as String? ?? 'Unknown error';

        AppLogger.debug('📭 Facebook API Error $errorCode: $errorMessage');

        // Error 551: User unavailable (blocked, deleted, or hasn't messaged page)
        if (errorCode == 551) {
          AppLogger.warning(
            '📭 Cannot message user $userId: User unavailable or hasn\'t initiated conversation',
          );
          throw Exception(
            'User is unavailable for messaging. They may need to message your page first.',
          );
        }
        // Error 10: Permission denied
        else if (errorCode == 10) {
          AppLogger.error('📭 Missing pages_messaging permission');
          throw Exception(
            'Missing required Facebook permission: pages_messaging',
          );
        }
        // Error 200: Permission from user required
        else if (errorCode == 200) {
          AppLogger.warning('📭 User has not granted messaging permission');
          throw Exception(
            'User has not granted permission to receive messages',
          );
        } else {
          AppLogger.error('📭 Facebook API error: $errorCode - $errorMessage');
          throw Exception('Facebook API error: $errorMessage');
        }
      }

      AppLogger.error('Failed to send private message', e);
      rethrow;
    }
  }

  // ==================== Posts (Optional) ====================

  /// Get posts
  ///
  /// Python equivalent: def get_posts(self)
  Future<List<Map<String, dynamic>>> getPosts({int limit = 25}) async {
    try {
      final endpoint = '${config.pageId}/${ApiConstants.postsEndpoint}';
      final response = await _dio.get(
        endpoint,
        queryParameters: _buildParams({
          ApiConstants.fieldsParam: 'id,message,updated_time',
          ApiConstants.limitParam: limit,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final postsData = data['data'] as List<dynamic>? ?? [];

        final posts = postsData.cast<Map<String, dynamic>>();
        AppLogger.info('🌐 API: Fetched ${posts.length} posts');
        return posts;
      } else {
        throw _handleError(response);
      }
    } on DioException {
      rethrow;
    }
  }

  // ==================== Error Handling ====================

  /// Handle API error responses
  Exception _handleError(Response response) {
    final data = response.data;
    String errorMessage = 'Unknown error';

    if (data is Map<String, dynamic> && data.containsKey('error')) {
      final error = data['error'] as Map<String, dynamic>;
      errorMessage = error['message'] as String? ?? 'API Error';
    }

    switch (response.statusCode) {
      case ApiConstants.unauthorizedError:
        return Exception('Unauthorized: Invalid or expired access token');
      case ApiConstants.forbiddenError:
        return Exception('Forbidden: Insufficient permissions');
      case ApiConstants.notFoundError:
        return Exception('Not Found: Resource does not exist');
      case ApiConstants.rateLimitError:
        return Exception('Rate Limit: Too many requests');
      default:
        return Exception('API Error: $errorMessage');
    }
  }

  /// Test API connection
  Future<bool> testConnection() async {
    try {
      await getUserInfo();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get API version being used
  String get apiVersion => config.version;

  /// Get base URL
  String get baseUrl => _dio.options.baseUrl;
}
