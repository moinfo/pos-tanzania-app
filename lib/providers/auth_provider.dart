import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'permission_provider.dart';
import 'location_provider.dart';
import 'connectivity_provider.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  PermissionProvider? _permissionProvider;
  LocationProvider? _locationProvider;
  ConnectivityProvider? _connectivityProvider;

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  // Keys for offline credential storage
  static const String _offlineCredentialsKey = 'offline_credentials';
  static const String _offlineUserKey = 'offline_user';

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

  /// Set connectivity provider (called from main.dart after providers are set up)
  void setConnectivityProvider(ConnectivityProvider provider) {
    _connectivityProvider = provider;
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

  /// Login user (supports offline login if credentials are cached)
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

      // Check if we're offline and offline mode is enabled
      final client = await ApiService.getCurrentClient();
      final isOffline = _connectivityProvider != null && !_connectivityProvider!.isOnline;

      if (isOffline && client.features.hasOfflineMode) {
        debugPrint('📴 Attempting offline login for user: $username');
        // Try offline login
        final offlineResult = await _tryOfflineLogin(username, password);
        if (offlineResult) {
          debugPrint('✅ Offline login successful');
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _error = 'Offline login failed. Please connect to internet for first-time login.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Online login
      final result = await _apiService.login(username, password);

      if (result.isSuccess && result.data != null) {
        _user = result.data;
        _isAuthenticated = true;
        _error = null;

        // Cache credentials for offline login (only if offline mode enabled)
        if (client.features.hasOfflineMode) {
          await _cacheOfflineCredentials(username, password, result.data!);
          debugPrint('💾 Credentials cached for offline login');
        }

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
      // If network error and offline mode enabled, try offline login
      final client = await ApiService.getCurrentClient();
      if (client.features.hasOfflineMode) {
        debugPrint('📴 Network error, attempting offline login');
        final offlineResult = await _tryOfflineLogin(username, password);
        if (offlineResult) {
          debugPrint('✅ Offline login successful (fallback)');
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _error = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Hash password for secure storage
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }

  /// Cache credentials for offline login
  Future<void> _cacheOfflineCredentials(String username, String password, User user) async {
    final prefs = await SharedPreferences.getInstance();
    final clientId = (await ApiService.getCurrentClient()).id;

    // Create a salt using username and client ID
    final salt = '$username$clientId';
    final hashedPassword = _hashPassword(password, salt);

    // Store hashed credentials
    final credentials = {
      'username': username,
      'passwordHash': hashedPassword,
      'salt': salt,
    };
    await prefs.setString('${_offlineCredentialsKey}_$clientId', jsonEncode(credentials));

    // Store user data for offline access
    await prefs.setString('${_offlineUserKey}_$clientId', jsonEncode(user.toJson()));

    debugPrint('💾 Offline credentials cached for $username (client: $clientId)');
  }

  /// Try to login using cached offline credentials
  Future<bool> _tryOfflineLogin(String username, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = (await ApiService.getCurrentClient()).id;

      // Get cached credentials
      final credentialsJson = prefs.getString('${_offlineCredentialsKey}_$clientId');
      if (credentialsJson == null) {
        debugPrint('❌ No offline credentials found');
        return false;
      }

      final credentials = jsonDecode(credentialsJson) as Map<String, dynamic>;
      final storedUsername = credentials['username'] as String;
      final storedPasswordHash = credentials['passwordHash'] as String;
      final salt = credentials['salt'] as String;

      // Verify username
      if (storedUsername.toLowerCase() != username.toLowerCase()) {
        debugPrint('❌ Username mismatch');
        return false;
      }

      // Verify password
      final inputHash = _hashPassword(password, salt);
      if (inputHash != storedPasswordHash) {
        debugPrint('❌ Password mismatch');
        return false;
      }

      // Load cached user data
      final userJson = prefs.getString('${_offlineUserKey}_$clientId');
      if (userJson == null) {
        debugPrint('❌ No offline user data found');
        return false;
      }

      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      _user = User.fromJson(userData);
      _isAuthenticated = true;
      _error = null;

      // Load permissions from local storage
      if (_permissionProvider != null) {
        await _permissionProvider!.loadPermissionsFromLocal();
      }

      debugPrint('✅ Offline login verified for $username');
      return true;
    } catch (e) {
      debugPrint('❌ Offline login error: $e');
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
