import 'package:flutter/foundation.dart';
import '../data/services/api_client.dart';
import '../data/services/storage_service.dart';
import '../core/utils/logger.dart';

/// Provider for managing authentication state
class AuthProvider with ChangeNotifier {
  final StorageService _storage;

  bool _isAuthenticated = false;
  String? _username;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _token;

  AuthProvider(this._storage);

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get token => _token;

  /// Initialize auth state from storage
  Future<void> init() async {
    try {
      final authData = await _storage.getAuthData();
      if (authData != null && authData['isAuthenticated'] == true) {
        _isAuthenticated = true;
        _username = authData['username'] as String?;
        _token = authData['token'] as String?;
        AppLogger.info('User authenticated: $_username');
      }
    } catch (e) {
      AppLogger.error('Failed to load auth state: $e');
    }
    _isInitializing = false;
    notifyListeners();
  }

  /// Login with username and password
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Authenticate against backend API
      final apiClient = ApiClient();
      final accessToken = await apiClient.login(username, password);

      if (accessToken.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Save auth state locally
      await _storage.saveAuthData({
        'isAuthenticated': true,
        'username': username,
        'token': accessToken,
        'loginTime': DateTime.now().toIso8601String(),
      });

      _isAuthenticated = true;
      _username = username;
      _token = accessToken;
      _isLoading = false;
      notifyListeners();

      AppLogger.info('User logged in: $username');
      return true;
    } catch (e) {
      AppLogger.error('Login failed: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storage.clearAuthData();
      _isAuthenticated = false;
      _username = null;
      _token = null;

      AppLogger.info('User logged out');
    } catch (e) {
      AppLogger.error('Logout failed: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
