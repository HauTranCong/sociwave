import 'package:dio/dio.dart';
import '../../domain/models/config.dart';
import '../../domain/models/rule.dart';
import '../../domain/models/comment.dart';
import '../../domain/models/reel.dart';

/// Client for talking to the SociWave FastAPI backend.
class ApiClient {
  final Dio _dio;

  // Base URL for the FastAPI backend.
  // For local development with docker-compose, the backend is exposed on 8000.
  static const String _baseUrl = 'http://127.0.0.1:8000/api';

  ApiClient({String? authToken})
    : _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      ) {
    if (authToken != null && authToken.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $authToken';
    }
  }

  /// Authenticate against the backend and return the access token.
  Future<String> login(String username, String password) async {
    final response = await _dio.post(
      '/auth/token',
      data: {'username': username, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data['access_token'] is String) {
      return data['access_token'] as String;
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      error: 'Invalid login response from backend',
    );
  }

  /// Triggers the monitoring cycle on the backend.
  Future<void> triggerMonitoring() async {
    await _dio.post('/trigger-monitoring');
  }

  /// Fetch reels from the backend.
  Future<List<Reel>> getReels() async {
    final response = await _dio.get('/reels');
    final data = response.data;

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => Reel.fromJson(item))
          .toList();
    }

    return [];
  }

  /// Fetch comments for a specific reel from the backend.
  Future<List<Comment>> getComments(String reelId) async {
    final response = await _dio.get('/comments/$reelId');
    final data = response.data;

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => Comment.fromJson(item))
          .toList();
    }

    return [];
  }

  /// Reply to a specific comment via the backend.
  Future<void> replyToComment(String commentId, String message) async {
    await _dio.post(
      '/reply',
      queryParameters: {
        'comment_id': commentId,
        'message': message,
      },
    );
  }

  /// Fetch configuration from the backend and map it into the front-end Config model.
  Future<Config> getConfig() async {
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

    await _dio.post('/config', data: payload);
  }

  /// Fetch rules from the backend.
  ///
  /// GET /rules returns a list of Rule objects; we map them into a map
  /// keyed by object_id for convenient use in the UI.
  Future<Map<String, Rule>> getRules() async {
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
  }

  /// Save rules to the backend using its expected JSON shape.
  ///
  /// POST /rules expects a mapping from object_id to Rule.
  Future<void> saveRules(Map<String, Rule> rules) async {
    final payload = <String, dynamic>{};
    rules.forEach((id, rule) {
      payload[id] = rule.toJson();
    });

    await _dio.post('/rules', data: payload);
  }
}
