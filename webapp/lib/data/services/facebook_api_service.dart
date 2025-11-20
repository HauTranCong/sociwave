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
          ApiConstants.fieldsParam: ApiConstants.commentFields,
          ApiConstants.limitParam: limit ?? config.commentsLimit,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final commentsData = data['data'] as List<dynamic>? ?? [];

        final comments = commentsData
            .map((json) => Comment.fromJson(json as Map<String, dynamic>))
            .toList();

        AppLogger.info('🌐 API: Fetched ${comments.length} comments');
        return comments;
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
