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

  /// Whether the last request actually reached the server.
  ///
  /// The radio being up is not the same thing, and this app's users live in
  /// the gap between them: a van on a bar of signal that carries nothing, a
  /// shop wifi whose uplink is down, a captive portal. The badge used to read
  /// ONLINE in all three while every request failed.
  ///
  /// Null means nothing has been tried since the radio came up, so there is no
  /// evidence either way and the radio is the best guess available.
  bool? _serverAnswering;

  /// Online means the radio is up AND the server has not just refused to
  /// answer. Optimistic when untested: a fresh start with signal reads online
  /// until something proves otherwise, rather than accusing the network before
  /// a single request has been made.
  bool get isOnline => _isOnline && (_serverAnswering ?? true);

  /// Whether the device is currently offline
  bool get isOffline => !isOnline;

  /// True only when the radio is up but the server is not answering -- worth
  /// saying differently on screen, because "no internet" sends a seller to
  /// check a connection that is fine.
  bool get serverUnreachable => _isOnline && _serverAnswering == false;

  /// Report the outcome of a real request.
  ///
  /// Called from ApiService on every response: statusCode == null means nobody
  /// answered, anything else means they did -- a 401 or a 500 is still the
  /// server being there. Cheap and truthful, and it costs no extra round trip,
  /// which is why this is not a poll.
  void reportServerReachable(bool reachable) {
    if (_serverAnswering == reachable) return;
    _serverAnswering = reachable;
    notifyListeners();
  }

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
  /// Exposed for tests: the radio transition is half of what [isOnline] means,
  /// and the half that cannot be driven from a unit test otherwise.
  @visibleForTesting
  void applyConnectivityResult(ConnectivityResult result) =>
      _updateConnectivity(result);

  void _updateConnectivity(ConnectivityResult result) {
    final wasOnline = _isOnline;

    // Determine connection type and online status
    _connectionType = result;
    _isOnline = result != ConnectivityResult.none;

    // A different radio is a different network, so what the last one proved
    // about the server no longer applies. Forget it and let the next real
    // request settle the question -- otherwise a phone that walks from a dead
    // shop wifi onto mobile data keeps insisting the server is unreachable.
    _serverAnswering = null;

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
