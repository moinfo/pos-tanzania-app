import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'permission_provider.dart';
import 'location_provider.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  PermissionProvider? _permissionProvider;
  LocationProvider? _locationProvider;

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _checkAuth();
  }

  /// Set permission provider (called from main.dart after providers are set up)
  void setPermissionProvider(PermissionProvider provider) {
    _permissionProvider = provider;
  }

  /// Set location provider (called from main.dart after providers are set up)
  void setLocationProvider(LocationProvider provider) {
    _locationProvider = provider;
  }

  /// Check if user is already authenticated
  Future<void> _checkAuth() async {
    final token = await _apiService.getToken();
    if (token != null) {
      // Verify token is still valid
      final result = await _apiService.verifyToken();
      if (result.isSuccess && result.data != null) {
        _user = result.data;
        _isAuthenticated = true;

        // Load permissions from local storage or fetch
        if (_permissionProvider != null) {
          await _permissionProvider!.loadPermissionsFromLocal();

          // If no permissions in local storage, fetch from API
          if (_permissionProvider!.permissions.isEmpty) {
            await _permissionProvider!.fetchPermissions();
          }
        }

        notifyListeners();
      } else {
        // Token is invalid, clear it
        await _apiService.clearToken();
      }
    }
  }

  /// Login user
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Clear previous user's cached data before login
      ApiService.clearDashboardCache();
      if (_locationProvider != null) {
        await _locationProvider!.clear();
      }

      final result = await _apiService.login(username, password);

      if (result.isSuccess && result.data != null) {
        _user = result.data;
        _isAuthenticated = true;
        _error = null;

        // Fetch user permissions after successful login
        if (_permissionProvider != null) {
          await _permissionProvider!.fetchPermissions();
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Check if token is still valid (called periodically)
  Future<void> checkTokenValidity() async {
    final token = await _apiService.getToken();

    // If token was cleared (by 401 handler), log out user
    if (token == null && _isAuthenticated) {
      debugPrint('Token no longer exists - logging out user');
      _user = null;
      _isAuthenticated = false;

      // Clear permissions
      if (_permissionProvider != null) {
        await _permissionProvider!.clearPermissions();
      }

      notifyListeners();
    }
  }

  /// Logout user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _apiService.logout();

    // Clear permissions on logout
    if (_permissionProvider != null) {
      await _permissionProvider!.clearPermissions();
    }

    // Clear location data on logout
    if (_locationProvider != null) {
      await _locationProvider!.clear();
    }

    // Clear dashboard cache
    ApiService.clearDashboardCache();

    _user = null;
    _isAuthenticated = false;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Refresh token
  Future<void> refreshToken() async {
    try {
      final result = await _apiService.refreshToken();
      if (!result.isSuccess) {
        // Token refresh failed, logout user
        await logout();
      }
    } catch (e) {
      await logout();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
