import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Whether the app may keep NEW work on the device when the server cannot be
/// reached.
///
/// Two switches, and both must be on:
///  * the build-time client flag (ClientConfig.features.hasOfflineMode), which
///    is what decides whether this client has a local database at all, and
///  * mobile_offline_enabled on the server, reported by /api/app_version.
///
/// The server half exists so offline selling can be switched off -- or back on
/// -- from the database, without a Play release and without waiting for every
/// phone to update.
///
/// WHAT THIS DOES NOT GATE
/// -----------------------
/// Uploading work that is ALREADY queued, and reading from the local cache.
/// Switching offline mode off must not strand sales somebody already made, so
/// SyncService is deliberately untouched by this flag: the queue keeps
/// draining, it just stops being filled.
class OfflineFeature {
  OfflineFeature._();

  static const _prefsKey = 'offline_enabled_server';

  /// What the server last said. Defaults to true so a phone that has never
  /// managed to ask keeps today's behaviour rather than silently losing the
  /// ability to sell on a weak network.
  static bool _serverAllows = true;

  /// Read the last remembered answer. Call once at startup, before the first
  /// screen can queue anything.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverAllows = prefs.getBool(_prefsKey) ?? true;
    } catch (e) {
      debugPrint('OfflineFeature: could not read stored flag - $e');
    }
  }

  /// Record what /api/app_version reported, for the next cold start.
  static Future<void> applyServerFlag(bool allowed) async {
    if (_serverAllows != allowed) {
      debugPrint('OfflineFeature: server says offline mode '
          '${allowed ? 'ON' : 'OFF'}');
    }
    _serverAllows = allowed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, allowed);
    } catch (e) {
      debugPrint('OfflineFeature: could not store flag - $e');
    }
  }

  /// Whether new work may be kept on the device right now.
  static bool get enabled {
    final client = ApiService.currentClient;
    return (client?.features.hasOfflineMode ?? false) && _serverAllows;
  }

  /// What to tell someone whose sale or request could not be sent, when
  /// keeping it on the phone is not allowed.
  static String refusal(String what) =>
      'Hakuna mtandao. $what haikutumwa na haikuhifadhiwa kwenye simu. '
      'Tafadhali jaribu tena ukipata mtandao. / No connection: this $what was '
      'NOT recorded. Please try again when you are online.';
}
