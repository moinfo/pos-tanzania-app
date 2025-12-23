import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Provider to monitor network connectivity status
class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;

  // Current connectivity status
  bool _isOnline = true;
  ConnectivityResult _connectionType = ConnectivityResult.none;
  DateTime? _lastOnlineTime;
  DateTime? _lastOfflineTime;

  // Connection quality metrics
  int _connectionDropCount = 0;
  Duration _totalOfflineTime = Duration.zero;

  /// Whether the device is currently online
  bool get isOnline => _isOnline;

  /// Whether the device is currently offline
  bool get isOffline => !_isOnline;

  /// Current connection type (wifi, mobile, none, etc.)
  ConnectivityResult get connectionType => _connectionType;

  /// Human-readable connection type string
  String get connectionTypeString {
    switch (_connectionType) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }

  /// Last time the device was online
  DateTime? get lastOnlineTime => _lastOnlineTime;

  /// Last time the device went offline
  DateTime? get lastOfflineTime => _lastOfflineTime;

  /// Number of times connection dropped
  int get connectionDropCount => _connectionDropCount;

  /// Total time spent offline
  Duration get totalOfflineTime => _totalOfflineTime;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    debugPrint('ConnectivityProvider: Initializing...');

    try {
      // Get initial connectivity status
      final result = await _connectivity.checkConnectivity();
      _updateConnectivity(result);

      // Listen for connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen((result) {
        _updateConnectivity(result);
      });

      debugPrint('ConnectivityProvider: Initialized - Online: $_isOnline, Type: $connectionTypeString');
    } catch (e) {
      // Handle MissingPluginException on simulators/emulators
      debugPrint('ConnectivityProvider: Plugin not available, assuming online - $e');
      _isOnline = true;
      _connectionType = ConnectivityResult.wifi;
      notifyListeners();
    }
  }

  /// Update connectivity status
  void _updateConnectivity(ConnectivityResult result) {
    final wasOnline = _isOnline;

    // Determine connection type and online status
    _connectionType = result;
    _isOnline = result != ConnectivityResult.none;

    // Track online/offline transitions
    if (wasOnline && !_isOnline) {
      // Just went offline
      _lastOfflineTime = DateTime.now();
      _connectionDropCount++;
      debugPrint('ConnectivityProvider: Went OFFLINE (drop count: $_connectionDropCount)');
    } else if (!wasOnline && _isOnline) {
      // Just came back online
      _lastOnlineTime = DateTime.now();

      // Calculate time spent offline
      if (_lastOfflineTime != null) {
        final offlineDuration = DateTime.now().difference(_lastOfflineTime!);
        _totalOfflineTime += offlineDuration;
        debugPrint('ConnectivityProvider: Back ONLINE after ${offlineDuration.inSeconds}s offline');
      } else {
        debugPrint('ConnectivityProvider: Back ONLINE');
      }
    }

    notifyListeners();
  }

  /// Check connectivity manually
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectivity(result);
      return _isOnline;
    } catch (e) {
      debugPrint('ConnectivityProvider: Error checking connectivity - $e');
      return _isOnline; // Return current status if check fails
    }
  }

  /// Reset offline metrics
  void resetMetrics() {
    _connectionDropCount = 0;
    _totalOfflineTime = Duration.zero;
    notifyListeners();
  }

  /// Get connectivity summary for debugging
  Map<String, dynamic> getSummary() {
    return {
      'is_online': _isOnline,
      'connection_type': connectionTypeString,
      'last_online': _lastOnlineTime?.toIso8601String(),
      'last_offline': _lastOfflineTime?.toIso8601String(),
      'drop_count': _connectionDropCount,
      'total_offline_seconds': _totalOfflineTime.inSeconds,
    };
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
    debugPrint('ConnectivityProvider: Disposed');
  }
}
