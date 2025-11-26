import 'package:dio/dio.dart';
import '../../domain/models/config.dart';
import '../../domain/models/rule.dart';
import '../../domain/models/comment.dart';
import '../../domain/models/reel.dart';
// logger intentionally not imported here to avoid logging tokens

/// Client for talking to the SociWave FastAPI backend.
class ApiClient {
  final Dio _dio;
  void Function()? _onUnauthorized;

  /// Base URL for the FastAPI backend.
  /// `API_BASE_URL` can be supplied at build time via `--dart-define`.
  static const String _compileTimeBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  ApiClient({String? authToken, String? baseUrlOverride})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrlOverride ?? _compileTimeBaseUrl,
          // Increase timeouts to be more forgiving for slower local/back-end starts
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ) {
    if (authToken != null && authToken.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $authToken';
    }

      // Diagnostic interceptor: log outgoing requests and Authorization header
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          // Debug: log whether Authorization header is present (do NOT log token value)
          final hasAuth = options.headers.containsKey('Authorization');
          // Using print here to keep this diagnostic lightweight during local dev
          print('[ApiClient] ${options.method.toUpperCase()} ${options.path} authHeaderPresent=$hasAuth');
          return handler.next(options);
        },
        onError: (e, handler) {
          // If 401, call onUnauthorized handler if set
          final status = e.response?.statusCode;
          if (status == 401) {
            try {
              _onUnauthorized?.call();
            } catch (_) {}
          }
          return handler.next(e);
        },
      ));
  }

    /// Update Authorization header on the existing Dio instance.
    void setAuthToken(String? authToken) {
      if (authToken != null && authToken.isNotEmpty) {
        _dio.options.headers['Authorization'] = 'Bearer $authToken';
      } else {
        _dio.options.headers.remove('Authorization');
      }
    }

    /// Register a callback to be invoked when a 401 Unauthorized is observed
    void setOnUnauthorized(void Function()? handler) {
      _onUnauthorized = handler;
    }

  /// Diagnostic: return current Authorization header value (if any)
  String? getAuthHeader() => _dio.options.headers['Authorization'] as String?;

  /// Authenticate against the backend and return the access token.
  Future<String> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/auth/token',
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['access_token'] is String) {
        return data['access_token'] as String;
      }

      // If backend returned a 2xx but payload is unexpected, treat as failure
      return '';
    } on DioException catch (e) {
      final apiError = _handleDioError(e);
      // For login, 401 is an expected failure (invalid credentials) so return empty token
      if (apiError.statusCode == 401) return '';
      // rethrow ApiException for other errors
      throw apiError;
    }
  }

  /// Triggers the monitoring cycle on the backend.
  Future<void> triggerMonitoring() async {
    try {
      await _dio.post('/trigger-monitoring');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get whether server-side monitoring is enabled
  Future<bool> getMonitoringEnabled() async {
    try {
      final response = await _dio.get('/monitoring/enabled');
      final data = response.data;
      if (data is Map && data.containsKey('enabled')) {
        return data['enabled'] as bool;
      }
      return false;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Set whether server-side monitoring is enabled
  Future<bool> setMonitoringEnabled(bool enabled) async {
    try {
      final response = await _dio.post('/monitoring/enabled', queryParameters: {'enabled': enabled});
      final data = response.data;
      if (data is Map && data.containsKey('enabled')) {
        return data['enabled'] as bool;
      }
      return false;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get monitoring interval in seconds
  Future<int> getMonitoringInterval() async {
    try {
      final response = await _dio.get('/monitoring/interval');
      final data = response.data;
      if (data is Map && data.containsKey('interval_seconds')) {
        return (data['interval_seconds'] as num).toInt();
      }
      return 300;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Set monitoring interval in seconds
  Future<int?> setMonitoringInterval(int seconds) async {
    try {
      final response = await _dio.post('/monitoring/interval', queryParameters: {'interval_seconds': seconds});
      final data = response.data;
      if (data is Map && data.containsKey('interval_seconds')) {
        return (data['interval_seconds'] as num).toInt();
      }
      return null;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch reels from the backend.
  Future<List<Reel>> getReels() async {
    try {
      final response = await _dio.get('/reels');
      final data = response.data;

      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => Reel.fromJson(item))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch comments for a specific reel from the backend.
  Future<List<Comment>> getComments(String reelId) async {
    try {
      final response = await _dio.get('/comments/$reelId');
      final data = response.data;

      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => Comment.fromJson(item))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Reply to a specific comment via the backend.
  Future<void> replyToComment(String commentId, String message) async {
    try {
      await _dio.post(
        '/reply',
        queryParameters: {
          'comment_id': commentId,
          'message': message,
        },
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch configuration from the backend and map it into the front-end Config model.
  Future<Config> getConfig() async {
    try {
      final response = await _dio.get('/config');
      final data = response.data as Map<String, dynamic>;

      return Config(
        token: data['accessToken'] as String? ?? '',
        version: data['version'] as String? ?? 'v20.0',
        pageId: data['pageId'] as String? ?? 'me',
        useMockData: data['useMockData'] as bool? ?? false,
        reelsLimit: data['reelsLimit'] as int? ?? 25,
        commentsLimit: data['commentsLimit'] as int? ?? 100,
        repliesLimit: data['repliesLimit'] as int? ?? 100,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Save configuration to the backend using its expected JSON shape.
  Future<void> saveConfig(Config config) async {
    final payload = <String, dynamic>{
      'accessToken': config.token,
      'pageId': config.pageId,
      'version': config.version,
      'useMockData': config.useMockData,
      'reelsLimit': config.reelsLimit,
      'commentsLimit': config.commentsLimit,
      'repliesLimit': config.repliesLimit,
    };

    try {
      await _dio.post('/config', data: payload);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch rules from the backend.
  ///
  /// GET /rules returns a list of Rule objects; we map them into a map
  /// keyed by object_id for convenient use in the UI.
  Future<Map<String, Rule>> getRules() async {
    try {
      final response = await _dio.get('/rules');
      final data = response.data;

      if (data is List) {
        final result = <String, Rule>{};
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final objectId = item['object_id'] as String? ?? '';
            if (objectId.isEmpty) continue;
            result[objectId] = Rule.fromJson(objectId, item);
          }
        }
        return result;
      }

      return {};
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Save rules to the backend using its expected JSON shape.
  ///
  /// POST /rules expects a mapping from object_id to Rule.
  Future<void> saveRules(Map<String, Rule> rules) async {
    final payload = <String, dynamic>{};
    rules.forEach((id, rule) {
      payload[id] = rule.toJson();
    });
    try {
      await _dio.post('/rules', data: payload);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

}

/// Simple ApiException to surface HTTP status and message from Dio
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

ApiException _handleDioError(DioException e) {
  final status = e.response?.statusCode;
  String message = e.message ?? 'Unknown error';

  // Try to extract a message from JSON body if available
  try {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      if (data['detail'] != null) {
        message = data['detail'].toString();
      } else if (data['error'] != null) {
        message = data['error'].toString();
      }
    }
  } catch (_) {}

  return ApiException(message, statusCode: status);
}
