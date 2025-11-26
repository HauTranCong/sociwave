import 'package:flutter/material.dart';
import '../data/services/api_client.dart';

/// Provides a shared ApiClient instance to the app and updates its auth header
class ApiClientProvider extends ChangeNotifier {
  ApiClient _client = ApiClient();
  void Function()? _onUnauthorized;

  ApiClient get client => _client;

  /// Update Authorization header (called when auth token changes)
  void setAuthToken(String? token) {
    try {
      _client.setAuthToken(token);
      // AppLogger.info('ApiClientProvider: set auth header -> ${_client.getAuthHeader() ?? '<none>'}');
    } catch (_) {
      // Fallback: recreate client if setAuthToken not available for some reason
      _client = ApiClient(authToken: token);
      // Attach onUnauthorized handler to the new client if present
      if (_onUnauthorized != null) {
        try {
          _client.setOnUnauthorized(_onUnauthorized);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  /// Register a global onUnauthorized handler (propagates to client)
  void setOnUnauthorized(void Function()? handler) {
    _onUnauthorized = handler;
    try {
      _client.setOnUnauthorized(handler);
    } catch (_) {}
  }
}
