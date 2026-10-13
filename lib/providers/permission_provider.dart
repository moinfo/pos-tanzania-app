import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/permission_model.dart';
import '../services/api_service.dart';

class PermissionProvider with ChangeNotifier {
  List<Permission> _permissions = [];
  bool _isLoading = false;
  String? _error;

  List<Permission> get permissions => _permissions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static const String _permissionsKeyPrefix = 'user_permissions';

  /// Get client-specific permissions key
  Future<String> _getPermissionsKey() async {
    final client = await ApiService.getCurrentClient();
    return '${_permissionsKeyPrefix}_${client.id}';
  }

  /// Check if user has a specific permission
  bool hasPermission(String permissionId) {
    if (permissionId.isEmpty) return true; // Empty permission means no restriction
    return _permissions.any((p) => p.permissionId == permissionId);
  }

  /// Check if user has module-level permission or any sub-permission of that module
  bool hasModulePermission(String moduleId) {
    if (moduleId.isEmpty) return true;

    // Check if user has the module permission itself
    if (_permissions.any((p) => p.permissionId == moduleId)) {
      return true;
    }

    // Check if user has any sub-permission of this module (e.g., items_add for items module)
    return _permissions.any((p) => p.permissionId.startsWith('${moduleId}_'));
  }

  /// Check if user has any of the specified permissions
  bool hasAnyPermission(List<String> permissionIds) {
    if (permissionIds.isEmpty) return true;
    return permissionIds.any((id) => hasPermission(id));
  }

  /// Check if user has all of the specified permissions
  bool hasAllPermissions(List<String> permissionIds) {
    if (permissionIds.isEmpty) return true;
    return permissionIds.every((id) => hasPermission(id));
  }

  /// Get permissions for a specific module
  List<Permission> getModulePermissions(String moduleId) {
    return _permissions.where((p) => p.moduleId == moduleId).toList();
  }

  /// Get permissions by menu group
  List<Permission> getPermissionsByMenuGroup(String menuGroup) {
    return _permissions.where((p) => p.menuGroup == menuGroup).toList();
  }

  /// Fetch permissions from API
  Future<void> fetchPermissions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final apiService = ApiService();
      final response = await apiService.getUserPermissions();

      if (response['status'] == 'success') {
        final data = response['data'] as Map<String, dynamic>;
        final permissionsResponse = UserPermissionsResponse.fromJson(data);
        _permissions = permissionsResponse.permissions;
        _lastRefresh = DateTime.now();

        // Save to local storage
        await _savePermissionsLocally();

        _error = null;
      } else {
        _error = response['message'] ?? 'Failed to fetch permissions';
      }
    } catch (e) {
      _error = 'Error fetching permissions: $e';
      debugPrint(_error);

      // Try to load from local storage on error
      await loadPermissionsFromLocal();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DateTime? _lastRefresh;

  /// Re-reads the employee's grants without any loading state, so a change an
  /// administrator makes on the web (a grant added or taken away) reaches a
  /// phone that is already signed in -- the web re-checks grants on every
  /// request, the app otherwise only at sign-in. Skipped when the last
  /// refresh is younger than [minAge]. A failed read (offline, server error)
  /// keeps what is already held; it never clears permissions.
  Future<void> refreshInBackground({
    Duration minAge = const Duration(minutes: 2),
  }) async {
    if (_isLoading) return;
    final last = _lastRefresh;
    if (last != null && DateTime.now().difference(last) < minAge) return;
    _lastRefresh = DateTime.now();

    try {
      final response = await ApiService().getUserPermissions();
      if (response['status'] != 'success') return;
      final data = response['data'] as Map<String, dynamic>;
      final fresh = UserPermissionsResponse.fromJson(data).permissions;

      final held = _permissions.map((p) => p.permissionId).toSet();
      final now = fresh.map((p) => p.permissionId).toSet();
      if (held.length == now.length && held.containsAll(now)) return;

      _permissions = fresh;
      await _savePermissionsLocally();
      notifyListeners();
    } catch (e) {
      debugPrint('Background permission refresh failed: $e');
    }
  }

  /// Save permissions to local storage
  Future<void> _savePermissionsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getPermissionsKey();
      final permissionsJson = _permissions.map((p) => p.toJson()).toList();
      await prefs.setString(key, jsonEncode(permissionsJson));
      debugPrint('💾 Permissions saved locally (${_permissions.length} permissions)');
    } catch (e) {
      debugPrint('Error saving permissions locally: $e');
    }
  }

  /// Load permissions from local storage
  Future<void> loadPermissionsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getPermissionsKey();
      final permissionsString = prefs.getString(key);

      if (permissionsString != null) {
        final permissionsJson = jsonDecode(permissionsString) as List<dynamic>;
        _permissions = permissionsJson
            .map((p) => Permission.fromJson(p as Map<String, dynamic>))
            .toList();
        debugPrint('📂 Permissions loaded from local (${_permissions.length} permissions)');
        notifyListeners();
      } else {
        debugPrint('⚠️ No cached permissions found');
      }
    } catch (e) {
      debugPrint('Error loading permissions from local storage: $e');
    }
  }

  /// Clear all permissions (used on logout)
  Future<void> clearPermissions() async {
    _permissions = [];
    _error = null;

    // Clear cached permissions from local storage to prevent user data leakage
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_permissionsKeyPrefix)) {
          await prefs.remove(key);
          debugPrint('🗑️ Cleared cached permissions: $key');
        }
      }
    } catch (e) {
      debugPrint('Error clearing cached permissions: $e');
    }

    notifyListeners();
  }

  /// Set permissions directly (used after login)
  void setPermissions(List<Permission> permissions) {
    _permissions = permissions;
    _savePermissionsLocally();
    notifyListeners();
  }

  /// Debug: Print all permissions
  void debugPrintPermissions() {
    debugPrint('=== User Permissions (${_permissions.length}) ===');
    for (var permission in _permissions) {
      debugPrint('  - ${permission.permissionId} (module: ${permission.moduleId}, menu: ${permission.menuGroup})');
    }
    debugPrint('=================================');
  }
}
