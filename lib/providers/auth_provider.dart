import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/push_service.dart';
import 'permission_provider.dart';
import 'location_provider.dart';
import 'connectivity_provider.dart';
import 'sale_provider.dart';
import 'notification_provider.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  PermissionProvider? _permissionProvider;
  LocationProvider? _locationProvider;
  ConnectivityProvider? _connectivityProvider;
  SaleProvider? _saleProvider;
  NotificationProvider? _notificationProvider;

  User? _user;

  /// Whether this session was established from cached credentials with no
  /// server round trip. Such a session must not be torn down by the token
  /// poll: there is no network to re-authenticate over, and the seller still
  /// has sales to ring up.
  bool _isOfflineSession = false;
  bool get isOfflineSession => _isOfflineSession;
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

  /// Completes when the startup session check (token read + verify +
  /// permissions) has finished. The splash screen awaits this instead of
  /// racing it with a fixed delay -- the race sent users with a perfectly
  /// valid session to the login screen whenever the network was slower
  /// than the splash.
  late final Future<void> ready;

  AuthProvider() {
    ready = _checkAuth();
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

  /// Set sale provider (called from main.dart after providers are set up)
  void setSaleProvider(SaleProvider provider) {
    _saleProvider = provider;
  }

  void setNotificationProvider(NotificationProvider provider) {
    _notificationProvider = provider;
  }

  /// Check if user is already authenticated
  Future<void> _checkAuth() async {
    try {
      await _checkAuthInner();
    } catch (e) {
      // A failed session check (secure-storage PlatformException after a
      // device restore, network down during verify) must resolve to "not
      // signed in", never to an error: the splash awaits `ready`, and an
      // error here left it stuck with no navigation at all.
      debugPrint('Auth check failed, treating as signed out: $e');
      _isAuthenticated = false;
      _user = null;
    }
  }

  Future<void> _checkAuthInner() async {
    final token = await _apiService.getToken();
    if (token != null) {
      // Verify token is still valid
      final result = await _apiService.verifyToken();
      if (result.isSuccess && result.data != null) {
        _user = result.data;
        _isAuthenticated = true;
        await _persistActiveUserId();

        // Begin polling for notifications and the approval badge. Not awaited:
        // it makes a network call, and nothing about resuming a session should
        // wait on it.
        _notificationProvider?.start();

        // Same seam, same reason: the device token must belong to whoever is
        // signed in now. Not awaited -- it asks for a notification permission
        // and makes a network call, and login must not wait on either.
        PushService.instance.onLogin().then((_) {
          // A push tapped while the app was dead has been parked until there
          // was somewhere to send it. Now there is.
          PushService.instance.flushPendingTap();
        });

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
        // Session state only. The full clear() also erases the cached
        // locations, which an offline sign-in immediately needs -- see
        // LocationProvider.clearForLogin. Logout still wipes everything.
        await _locationProvider!.clearForLogin();
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
        _isOfflineSession = false;
        _error = null;
        await _persistActiveUserId();

        _notificationProvider?.start();

        // Same seam, same reason: the device token must belong to whoever is
        // signed in now. Not awaited -- it asks for a notification permission
        // and makes a network call, and login must not wait on either.
        PushService.instance.onLogin().then((_) {
          // A push tapped while the app was dead has been parked until there
          // was somewhere to send it. Now there is.
          PushService.instance.flushPendingTap();
        });

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
      } else if (result.statusCode == null && client.features.hasOfflineMode) {
        // No status code means nobody answered -- the server is unreachable,
        // which is NOT the same as bad credentials. The connectivity check
        // above only catches a downed radio; a phone on a shop's wifi with a
        // dead uplink gets here instead, and without this it is simply refused
        // entry with "login failed" and cannot sell at all.
        debugPrint('📴 Server unreachable, attempting offline login');
        if (await _tryOfflineLogin(username, password)) {
          debugPrint('✅ Offline login successful (server unreachable)');
          _isLoading = false;
          notifyListeners();
          return true;
        }
        _error = 'Cannot reach the server, and there are no saved credentials '
            'for this user on this device. Connect once to sign in.';
        _isLoading = false;
        notifyListeners();
        return false;
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
      _isOfflineSession = true;
      _error = null;
      await _persistActiveUserId();

      // Put the last online session's JWT back where ApiService looks for it.
      //
      // Without this an offline sign-in leaves no token at all, and the
      // 30-second checkTokenValidity poll reads that as "session revoked" and
      // signs the seller straight back out -- half a minute after letting them
      // in, with no network to sign in again with. It also means that the
      // moment the server comes back, the queued sales have credentials to
      // upload with instead of waiting for someone to notice.
      //
      // The token may well be expired. That is fine and is handled: the server
      // answers 401, SyncService classifies that as retryable rather than as
      // the sale's fault, the sale stays queued, and the 401 handler asks the
      // seller to sign in properly -- by which time they demonstrably have a
      // connection to do it over.
      final cachedToken = _user?.token;
      if (cachedToken != null && cachedToken.isNotEmpty) {
        await _apiService.saveToken(cachedToken);
      }

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

    // An offline session has whatever token the last online sign-in left, or
    // none at all. Either way the absence of one here is not evidence that the
    // session was revoked -- only a 401 from a server that actually answered
    // is that, and _handleUnauthorized covers it.
    if (token == null && _isOfflineSession) {
      return;
    }

    // If token was cleared (by 401 handler), log out user
    if (token == null && _isAuthenticated) {
      debugPrint('Token no longer exists - logging out user');
      _user = null;
      _isAuthenticated = false;

      // Same treatment as an explicit logout(). A session dropped by a 401 is
      // still this person leaving the handset, and without this the poll kept
      // running under a dead token AND the home-screen icon kept the previous
      // seller's badge for whoever signs in next.
      await _notificationProvider?.stop();

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

    // BEFORE _apiService.logout(), which clears the JWT. Unregistering is
    // itself an authenticated call, so doing it afterwards would 401 and leave
    // this handset registered to the person signing out -- meaning the next
    // seller on a shared shop phone receives their approvals.
    await PushService.instance.onLogout();

    await _apiService.logout();

    // Clear permissions on logout
    if (_permissionProvider != null) {
      await _permissionProvider!.clearPermissions();
    }

    // Clear location data on logout
    if (_locationProvider != null) {
      await _locationProvider!.clear();
    }

    // SaleProvider is one instance for the app's whole process, so on a
    // shared device it otherwise survives into the next login. Left alone,
    // the next seller's cart could inherit this one's stock_location_id
    // before their own location finishes loading -- filing a sale, or a
    // suspend, under a stranger's location.
    _saleProvider?.resetForNewUser();

    // Stop the notification poll and clear the badge. On a shared device the
    // next seller would otherwise inherit this one's unread count -- and keep
    // polling under a token that no longer belongs to them.
    await _notificationProvider?.stop();

    // Clear dashboard cache
    ApiService.clearDashboardCache();

    _user = null;
    _isAuthenticated = false;
    _error = null;
    _isLoading = false;
    await _persistActiveUserId();
    notifyListeners();
  }

  /// Record which user is signed in.
  ///
  /// Per-user caches (locations, for one) key off this so one seller's data
  /// cannot be served to the next person who signs in on the same device.
  static const String activeUserIdKey = 'active_user_id';

  Future<void> _persistActiveUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = _user?.id;
    if (id == null || id.isEmpty) {
      await prefs.remove(activeUserIdKey);
    } else {
      await prefs.setString(activeUserIdKey, id);
    }
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
