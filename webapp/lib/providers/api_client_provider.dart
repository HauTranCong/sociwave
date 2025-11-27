import 'package:flutter/material.dart';
import '../data/services/api_client.dart';

/// Provides a shared ApiClient instance to the app and updates its auth header
class ApiClientProvider extends ChangeNotifier {
  ApiClient _client = ApiClient();
  void Function()? _onUnauthorized;
  String? _authToken;
  String? _pageId;

  ApiClient get client => _client;

  /// Update Authorization header (called when auth token changes)
  void setAuthToken(String? token) {
    _authToken = token;
    try {
      _client.setAuthToken(token);
      // AppLogger.info('ApiClientProvider: set auth header -> ${_client.getAuthHeader() ?? '<none>'}');
    } catch (_) {
      _recreateClient();
    }
    notifyListeners();
  }

  /// Update the page scope for all API requests
  void setPageId(String? pageId) {
    _pageId = pageId;
    try {
      _client.setPageId(pageId);
    } catch (_) {
      _recreateClient();
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

  void _recreateClient() {
    _client = ApiClient(authToken: _authToken, pageId: _pageId);
    if (_onUnauthorized != null) {
      try {
        _client.setOnUnauthorized(_onUnauthorized);
      } catch (_) {}
    }
  }
}
