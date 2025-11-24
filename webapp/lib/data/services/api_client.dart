import 'package:dio/dio.dart';
import '../../domain/models/rule.dart';

class ApiClient {
  final Dio _dio;

  // Base URL for the FastAPI backend
  // For local development, this assumes the backend is running on localhost:8000
  // This should be moved to a configuration file (e.g., .env) later.
  static const String _baseUrl = 'http://127.0.0.1:8000/api';

  ApiClient()
      : _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: Duration(seconds: 5),
          receiveTimeout: Duration(seconds: 5),
        ));

  /// Triggers the monitoring cycle on the backend.
  Future<void> triggerMonitoring() async {
    try {
      await _dio.post('/trigger-monitoring');
    } catch (e) {
      // Handle or rethrow the error
      rethrow;
    }
  }

  /// Fetches the rules from the backend.
  Future<Map<String, Rule>> getRules() async {
    try {
      final response = await _dio.get('/rules');
      if (response.data is Map<String, dynamic>) {
        return (response.data as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, Rule.fromJson(key, value)),
        );
      }
      return {};
    } catch (e) {
      rethrow;
    }
  }

  /// Saves the rules to the backend.
  Future<void> saveRules(Map<String, Rule> rules) async {
    try {
      final data = rules.map((key, value) => MapEntry(key, value.toJson()));
      await _dio.post('/rules', data: data);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the configuration from the backend.
  Future<Map<String, dynamic>> getConfig() async {
    try {
      final response = await _dio.get('/config');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Saves the configuration to the backend.
  Future<void> saveConfig(Map<String, dynamic> config) async {
    try {
      await _dio.post('/config', data: config);
    } catch (e) {
      rethrow;
    }
  }
}
