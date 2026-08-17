import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock_location.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class LocationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<StockLocation> _allowedLocations = [];
  StockLocation? _selectedLocation;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentModuleId;

  /// Which signed-in user the loaded locations belong to.
  ///
  /// Allowed locations are per employee, so holding another user's list in
  /// memory or in the cache would show a seller stores they have no grant for.
  String? _loadedForUserId;

  // Cache key prefix for offline storage
  static const String _locationsCacheKeyPrefix = 'cached_locations';

  List<StockLocation> get allowedLocations => _allowedLocations;
  StockLocation? get selectedLocation => _selectedLocation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMultipleLocations => _allowedLocations.length > 1;

  /// Id of the signed-in user, or null when signed out.
  Future<String?> _activeUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AuthProvider.activeUserIdKey);
  }

  /// Cache key, scoped to both client and user.
  ///
  /// Without the user in the key, signing in as someone else on the same device
  /// reuses the previous seller's locations.
  Future<String> _getCacheKey(String moduleId) async {
    final client = await ApiService.getCurrentClient();
    final userId = await _activeUserId() ?? 'anon';
    return '${_locationsCacheKeyPrefix}_${client.id}_${userId}_$moduleId';
  }

  /// Cache locations to local storage
  Future<void> _cacheLocations(String moduleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getCacheKey(moduleId);
      final locationsJson = _allowedLocations.map((loc) => loc.toJson()).toList();
      await prefs.setString(key, jsonEncode(locationsJson));
      debugPrint('💾 Locations cached for module: $moduleId (${_allowedLocations.length} locations)');
    } catch (e) {
      debugPrint('Error caching locations: $e');
    }
  }

  /// Load locations from cache
  Future<bool> _loadFromCache(String moduleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getCacheKey(moduleId);
      final cachedJson = prefs.getString(key);

      if (cachedJson != null) {
        final locationsData = jsonDecode(cachedJson) as List<dynamic>;
        _allowedLocations = locationsData
            .map((json) => StockLocation.fromJson(json as Map<String, dynamic>))
            .toList();
        _currentModuleId = moduleId;
        debugPrint('📂 Locations loaded from cache for module: $moduleId (${_allowedLocations.length} locations)');
        return true;
      }
    } catch (e) {
      debugPrint('Error loading locations from cache: $e');
    }
    return false;
  }

  /// Initialize and load allowed locations
  /// [moduleId] - The module to filter locations for (e.g., 'sales', 'items')
  /// [userLocationId] - The user's assigned location from login (used as default)
  Future<void> initialize({String? moduleId, int? userLocationId}) async {
    final requestedModule = moduleId ?? 'items';

    debugPrint('📍 [LocationProvider] initialize called for module: $requestedModule, userLocationId: $userLocationId');
    debugPrint('📍 [LocationProvider] Current state - locations: ${_allowedLocations.length}, currentModule: $_currentModuleId, selected: ${_selectedLocation?.locationName}');

    final activeUserId = await _activeUserId();

    // Skip only when the loaded list belongs to the SAME module AND the same
    // user. Without the user check, signing in as another seller reuses the
    // previous one's locations because the API is never called again.
    // When no user is recorded (a session that predates this key, or a failed
    // write) we cannot prove the list belongs to whoever is signed in now, so
    // refetch rather than risk showing another seller's stores.
    if (_allowedLocations.isNotEmpty &&
        _currentModuleId == requestedModule &&
        activeUserId != null &&
        _loadedForUserId == activeUserId) {
      // Skipping the refetch must not skip the caller's assigned-location
      // default: if nothing is selected yet, apply it before returning.
      if (userLocationId != null && _selectedLocation == null) {
        await _setDefaultLocation(userLocationId);
        notifyListeners();
      }
      debugPrint('📍 [LocationProvider] Already initialized for $requestedModule, skipping');
      return;
    }

    if (_loadedForUserId != activeUserId) {
      debugPrint('📍 [LocationProvider] User changed ($_loadedForUserId -> $activeUserId), reloading locations');
      _allowedLocations = [];
      _selectedLocation = null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Load allowed locations from API
      final response = await _apiService.getAllowedStockLocations(moduleId: requestedModule);

      if (response.isSuccess && response.data != null) {
        _allowedLocations = response.data!;
        _currentModuleId = requestedModule;
        _loadedForUserId = activeUserId;
        _errorMessage = null;

        // Cache for offline use
        await _cacheLocations(requestedModule);

        debugPrint('📍 [LocationProvider] Loaded ${_allowedLocations.length} locations from API');
      } else {
        _errorMessage = response.message;
        debugPrint('📍 [LocationProvider] API Error: ${response.message}');
      }
    } catch (e) {
      debugPrint('📍 [LocationProvider] API Exception: $e');
      // Try loading from cache when offline
      final loadedFromCache = await _loadFromCache(requestedModule);
      if (loadedFromCache) {
        _errorMessage = null; // Clear error since we have cached data
        debugPrint('📍 [LocationProvider] Using cached locations (offline mode)');
      } else {
        _errorMessage = 'Unable to load locations. Please connect to internet.';
      }
    }

    // A selection carried over from another user (or a location whose grant was
    // revoked) must not survive -- drop it before picking a default.
    if (_selectedLocation != null &&
        !_allowedLocations.any((loc) => loc.locationId == _selectedLocation!.locationId)) {
      debugPrint('📍 [LocationProvider] Selected location ${_selectedLocation!.locationName} is not allowed, clearing');
      _selectedLocation = null;
    }

    // Set selected location
    if (_allowedLocations.isNotEmpty) {
      await _setDefaultLocation(userLocationId);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Set the default location based on priority
  Future<void> _setDefaultLocation(int? userLocationId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocationId = prefs.getInt('selected_location_id');

    // Priority for default location:
    // 1. User's assigned location from login (if provided and valid)
    // 2. Previously saved location from SharedPreferences
    // 3. First location in the list

    // Try user's assigned location first
    if (userLocationId != null && _selectedLocation == null) {
      final userLocation = _allowedLocations.where((loc) => loc.locationId == userLocationId).firstOrNull;
      if (userLocation != null) {
        _selectedLocation = userLocation;
        await _saveSelectedLocation();
        debugPrint('📍 [LocationProvider] Using user assigned location: ${_selectedLocation?.locationName}');
        return;
      }
    }

    // If not set, try saved location
    if (_selectedLocation == null && savedLocationId != null) {
      final savedLocation = _allowedLocations.where((loc) => loc.locationId == savedLocationId).firstOrNull;
      if (savedLocation != null) {
        _selectedLocation = savedLocation;
        debugPrint('📍 [LocationProvider] Using saved location: ${_selectedLocation?.locationName}');
        return;
      }
    }

    // If still not set, use first location
    if (_selectedLocation == null && _allowedLocations.isNotEmpty) {
      _selectedLocation = _allowedLocations.first;
      await _saveSelectedLocation();
      debugPrint('📍 [LocationProvider] Using first location: ${_selectedLocation?.locationName}');
    }
  }

  /// Change the selected location
  Future<void> selectLocation(StockLocation location) async {
    _selectedLocation = location;
    await _saveSelectedLocation();
    notifyListeners();
  }

  /// Save selected location to shared preferences
  Future<void> _saveSelectedLocation() async {
    if (_selectedLocation != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_location_id', _selectedLocation!.locationId);
    }
  }

  /// Reload locations from API
  Future<void> reload() async {
    await initialize();
  }

  /// Clear all location data (call on logout or user change)
  Future<void> clear() async {
    _allowedLocations = [];
    _selectedLocation = null;
    _currentModuleId = null;
    _loadedForUserId = null;
    _errorMessage = null;

    // Clear all location-related preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_location_id');

    // Clear all cached locations for this client
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_locationsCacheKeyPrefix)) {
        await prefs.remove(key);
        debugPrint('📍 [LocationProvider] Cleared cache: $key');
      }
    }

    debugPrint('📍 [LocationProvider] Cleared all location state and cache');
    notifyListeners();
  }
}
