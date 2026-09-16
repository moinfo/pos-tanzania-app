import 'package:flutter/material.dart';

import '../models/app_version_info.dart';
import '../services/offline_feature.dart';
import '../services/update_service.dart';

/// Holds the answer to "is there a newer version?" for the whole app.
///
/// One check per session is enough. A Play release is not a live feed — the
/// version on the store changes at most a few times a month — so polling it
/// the way NotificationProvider polls the approval badge would be all cost and
/// no benefit. The check runs once when the main navigation mounts (i.e. once
/// per sign-in), and again whenever the user asks for it on the update screen.
class UpdateProvider extends ChangeNotifier {
  UpdateProvider({UpdateService? service})
      : _service = service ?? UpdateService();

  final UpdateService _service;

  bool _disposed = false;

  UpdateState _state = UpdateState.unknown;
  AppVersionInfo? _latest;
  String _installedVersionName = '';
  int _installedVersionCode = 0;
  bool _isChecking = false;
  DateTime? _lastCheckedAt;

  /// Set once the prompt has been shown in this session, so a rebuild of the
  /// main navigation cannot put a second sheet on top of the first.
  bool _promptedThisSession = false;

  UpdateState get state => _state;
  AppVersionInfo? get latest => _latest;
  bool get isChecking => _isChecking;
  DateTime? get lastCheckedAt => _lastCheckedAt;

  /// e.g. '1.0.0 (36)' — what the drawer and settings show for "installed".
  String get installedVersionName => _installedVersionName;
  int get installedVersionCode => _installedVersionCode;
  String get installedLabel => _installedVersionName.isEmpty
      ? 'Unknown'
      : '$_installedVersionName ($_installedVersionCode)';

  bool get updateAvailable => _state == UpdateState.updateAvailable;

  /// Load the installed version even if the network check never lands, so the
  /// update screen can always show what the user is running.
  Future<void> loadInstalledVersion() async {
    if (_installedVersionName.isNotEmpty) return;
    final installed = await _service.installedVersion();
    _installedVersionName = installed.versionName;
    _installedVersionCode = installed.versionCode;
    _safeNotify();
  }

  /// Compare the installed build against what this client's server publishes.
  Future<void> check() async {
    if (_isChecking) return;
    _isChecking = true;
    _safeNotify();

    try {
      await loadInstalledVersion();
      final published = await _service.fetchPublishedVersion();

      if (published == null) {
        // Offline, signed out, or the endpoint is not deployed yet. Say we do
        // not know rather than claiming the app is current.
        _state = UpdateState.checkFailed;
      } else {
        // Carried on the same call, so switching offline mode off costs no
        // extra request. Remembered on the device for the next cold start.
        await OfflineFeature.applyServerFlag(published.offlineEnabled);

        _latest = published;
        _state = published.configured &&
                published.versionCode > _installedVersionCode
            ? UpdateState.updateAvailable
            : UpdateState.upToDate;
        _lastCheckedAt = DateTime.now();
      }
    } catch (e) {
      debugPrint('Update check errored: $e');
      _state = UpdateState.checkFailed;
    } finally {
      _isChecking = false;
      _safeNotify();
    }
  }

  /// Whether the non-blocking prompt should be raised right now.
  ///
  /// Three gates, all of which must open: an update genuinely exists, the user
  /// has not deferred this build inside the snooze window, and nothing has
  /// been shown yet this session.
  Future<bool> shouldPrompt() async {
    if (!updateAvailable || _promptedThisSession) return false;
    return !await _service.isSnoozed(_latest!.versionCode);
  }

  /// Record that the prompt was raised. Not the same as snoozing — this only
  /// stops a second sheet inside one session.
  void markPrompted() {
    _promptedThisSession = true;
  }

  /// Defer this build for [UpdateService.snoozeDuration].
  Future<void> snooze() async {
    final version = _latest;
    if (version == null) return;
    await _service.snooze(version.versionCode);
    _safeNotify();
  }

  /// When the active deferral expires, for the update screen to show. Null
  /// when nothing is deferred.
  Future<DateTime?> snoozedUntil() async {
    final version = _latest;
    if (version == null) return null;
    return _service.snoozedUntil(version.versionCode);
  }

  /// Send the user to the store. Also takes a snooze: whether or not they
  /// finish the install, they have been asked and answered, and the prompt
  /// should not reappear on the next launch while Play is still downloading.
  Future<bool> openStore() async {
    final opened = await _service.openStore(_latest);
    if (opened) await snooze();
    return opened;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
