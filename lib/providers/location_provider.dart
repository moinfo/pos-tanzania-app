import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock_location.dart';
import '../services/api_service.dart';

class LocationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<StockLocation> _allowedLocations = [];
  StockLocation? _selectedLocation;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentModuleId;

  List<StockLocation> get allowedLocations => _allowedLocations;
  StockLocation? get selectedLocation => _selectedLocation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMultipleLocations => _allowedLocations.length > 1;

  /// Initialize and load allowed locations
  /// [moduleId] - The module to filter locations for (e.g., 'sales', 'items')
  /// [userLocationId] - The user's assigned location from login (used as default)
  Future<void> initialize({String? moduleId, int? userLocationId}) async {
    final requestedModule = moduleId ?? 'items';

    print('📍 [LocationProvider] initialize called for module: $requestedModule, userLocationId: $userLocationId');
    print('📍 [LocationProvider] Current state - locations: ${_allowedLocations.length}, currentModule: $_currentModuleId, selected: ${_selectedLocation?.locationName}');

    // If already loaded for same module, skip
    if (_allowedLocations.isNotEmpty && _currentModuleId == requestedModule) {
      print('📍 [LocationProvider] Already initialized for $requestedModule, skipping');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Load allowed locations from API
      final response = await _apiService.getAllowedStockLocations(moduleId: requestedModule);

      if (response.isSuccess && response.data != null) {
        _allowedLocations = response.data!;
        _currentModuleId = requestedModule;
        _errorMessage = null;

        // Priority for default location:
        // 1. User's assigned location from login (if provided and valid)
        // 2. Previously saved location from SharedPreferences
        // 3. First location in the list
        final prefs = await SharedPreferences.getInstance();
        final savedLocationId = prefs.getInt('selected_location_id');

        // Try user's assigned location first
        if (userLocationId != null) {
          final userLocation = _allowedLocations.where((loc) => loc.locationId == userLocationId).firstOrNull;
          if (userLocation != null) {
            _selectedLocation = userLocation;
            await _saveSelectedLocation();
            print('📍 [LocationProvider] Using user assigned location: ${_selectedLocation?.locationName}');
          }
        }

        // If not set, try saved location
        if (_selectedLocation == null && savedLocationId != null) {
          final savedLocation = _allowedLocations.where((loc) => loc.locationId == savedLocationId).firstOrNull;
          if (savedLocation != null) {
            _selectedLocation = savedLocation;
            print('📍 [LocationProvider] Using saved location: ${_selectedLocation?.locationName}');
          }
        }

        // If still not set, use first location
        if (_selectedLocation == null && _allowedLocations.isNotEmpty) {
          _selectedLocation = _allowedLocations.first;
          await _saveSelectedLocation();
          print('📍 [LocationProvider] Using first location: ${_selectedLocation?.locationName}');
        }

        print('📍 [LocationProvider] Loaded ${_allowedLocations.length} locations, selected: ${_selectedLocation?.locationName}');
      } else {
        _errorMessage = response.message;
        print('📍 [LocationProvider] API Error: ${response.message}');
      }
    } catch (e) {
      _errorMessage = 'Error loading locations: $e';
      print('📍 [LocationProvider] Exception: $e');
    }

    _isLoading = false;
    notifyListeners();
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
}
