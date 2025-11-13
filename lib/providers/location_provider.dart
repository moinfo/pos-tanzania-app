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
  Future<void> initialize({String? moduleId}) async {
    final requestedModule = moduleId ?? 'items';

    // If already loaded for same module, skip
    if (_allowedLocations.isNotEmpty && _currentModuleId == requestedModule) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Load allowed locations from API
      final response = await _apiService.getAllowedStockLocations(moduleId: requestedModule);

      if (response.isSuccess && response.data != null) {
        _allowedLocations = response.data!;
        _currentModuleId = requestedModule;
        _errorMessage = null;

        // Load previously selected location or use first one
        final prefs = await SharedPreferences.getInstance();
        final savedLocationId = prefs.getInt('selected_location_id');

        if (savedLocationId != null) {
          _selectedLocation = _allowedLocations.firstWhere(
            (loc) => loc.locationId == savedLocationId,
            orElse: () => _allowedLocations.isNotEmpty ? _allowedLocations.first : StockLocation(locationId: 0, locationName: 'Unknown'),
          );
        } else if (_allowedLocations.isNotEmpty) {
          _selectedLocation = _allowedLocations.first;
          await _saveSelectedLocation();
        }
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = 'Error loading locations: $e';
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
