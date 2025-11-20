import 'package:flutter/foundation.dart';
import '../data/services/storage_service.dart';
import '../core/utils/logger.dart';

/// Provider for managing authentication state
class AuthProvider with ChangeNotifier {
  final StorageService _storage;
  
  bool _isAuthenticated = false;
  String? _username;
  bool _isLoading = true;

  AuthProvider(this._storage);

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  bool get isLoading => _isLoading;

  /// Initialize auth state from storage
  Future<void> init() async {
    try {
      final authData = await _storage.getAuthData();
      if (authData != null && authData['isAuthenticated'] == true) {
        _isAuthenticated = true;
        _username = authData['username'] as String?;
        AppLogger.info('User authenticated: $_username');
      }
    } catch (e) {
      AppLogger.error('Failed to load auth state: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  /// Login with username and password
  /// For now, this is a simple demo - in production use proper authentication
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Demo validation - accept any non-empty credentials
      // In production, validate against backend API
      if (username.isEmpty || password.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Save auth state
      await _storage.saveAuthData({
        'isAuthenticated': true,
        'username': username,
        'loginTime': DateTime.now().toIso8601String(),
      });
      
      _isAuthenticated = true;
      _username = username;
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
      
      AppLogger.info('User logged out');
    } catch (e) {
      AppLogger.error('Logout failed: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }
}
