import 'dart:async';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Mirrors the in-app badge onto the launcher / home-screen app icon.
///
/// WHY THIS EXISTS
/// ---------------
/// [NotificationProvider.badgeCount] has always been right, but it was only
/// ever drawn on the bell inside the app. A manager who is not in the app --
/// which is precisely the manager who needs telling -- saw nothing at all.
///
/// WHICH PACKAGE, AND WHY NOT THE OBVIOUS ONE
/// ------------------------------------------
/// Almost every search result for this still points at `flutter_app_badger`.
/// It is marked DISCONTINUED on pub.dev and last shipped three years ago, so
/// it has no Android 13+ POST_NOTIFICATIONS handling and no support for the
/// launchers that shipped since. `app_badge_plus` is the maintained successor
/// (releases every few weeks, ~285k downloads), keeps the same one-integer
/// API, and -- the part that actually saved work here -- declares every
/// vendor badge permission in its OWN AndroidManifest, so the manifest merger
/// carries them into all five product flavors with no per-flavor edit.
///
/// THIS CLASS MUST NEVER BE ABLE TO BREAK THE APP
/// ----------------------------------------------
/// Android has no OS-level badge API. Each launcher invents its own, and a
/// good number -- the stock Pixel launcher among them -- support no numeric
/// badge at all. `isSupported()` answers that, and on a "no" this class goes
/// permanently quiet: no further platform calls, and no repeated logging on
/// what is a perfectly normal handset. Every call is also wrapped, because a
/// vendor badge provider throwing is not a reason to fail an approval poll.
class AppBadgeService {
  AppBadgeService._();

  static final AppBadgeService instance = AppBadgeService._();

  /// Shared instance -- FlutterLocalNotificationsPlugin() is a factory
  /// returning the same object PushService already holds.
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// null until the launcher has been asked. false means "this launcher does
  /// not do badges", and is final for the life of the process.
  bool? _supported;

  /// Whether the iOS badge entitlement has already been requested this run.
  bool _authorizationAsked = false;

  /// The last count actually pushed to the launcher.
  ///
  /// [NotificationProvider] notifies its listeners for reasons that have
  /// nothing to do with the count -- a loading flag, a feed merge -- and each
  /// of those would otherwise become a platform channel round trip, plus a
  /// vendor broadcast on the Samsung and Sony paths. Only real changes go out.
  int? _lastPushed;

  /// Serialises updates so two overlapping calls cannot land out of order and
  /// leave the launcher showing the older number.
  Future<void> _queue = Future<void>.value();

  /// Reflect [count] on the app icon.
  ///
  /// Never throws, never awaited by callers on a hot path, and silently does
  /// nothing on a launcher that has no badges.
  void setCount(int count) {
    if (count < 0) count = 0;
    if (count == _lastPushed) return;
    _lastPushed = count;

    _queue = _queue.then((_) => _apply(count)).catchError((_) {});
  }

  /// Clear the badge outright. Used on logout: on a shared shop handset the
  /// next person to sign in must not find the previous seller's count sitting
  /// on the home screen.
  void clear() => setCount(0);

  Future<void> _apply(int count) async {
    if (!await _isSupported()) return;

    try {
      await AppBadgePlus.updateBadge(count);
    } catch (e) {
      debugPrint('AppBadgeService: updateBadge($count) failed ($e)');
      return;
    }

    // Nothing left unread means nothing left in the tray either. This matters
    // more than it looks on Android: on the stock launcher the icon "badge" is
    // a dot derived from ACTIVE NOTIFICATIONS rather than from any number we
    // set, so clearing the count without clearing the tray leaves the dot
    // sitting there over an empty inbox. cancelAll() goes to
    // NotificationManager.cancelAll(), which takes the entries FCM drew itself
    // while the app was dead as well as the ones we drew in the foreground.
    if (count == 0) {
      try {
        await _local.cancelAll();
      } catch (e) {
        debugPrint('AppBadgeService: cancelAll failed ($e)');
      }
    }
  }

  /// Ask iOS for the badge entitlement, once.
  ///
  /// THIS IS NOT OPTIONAL AND IT IS EASY TO MISS.
  ///
  /// The plugin sets the badge with UNUserNotificationCenter.setBadgeCount,
  /// which iOS ignores -- silently, with no error and no log line -- unless
  /// the app holds .badge authorization. The first run of this change did
  /// exactly that: the bell inside the app read 26 and the home screen icon
  /// stayed blank.
  ///
  /// Nothing else asks for it on iOS. PushService asks via
  /// FirebaseMessaging.requestPermission, but returns early when Firebase is
  /// unavailable -- and there is no GoogleService-Info.plist for ANY flavor,
  /// so on iOS that early return is the only path there is. Android is left
  /// alone here: PushService already raises POST_NOTIFICATIONS after login and
  /// a second prompt from a different plugin would be one prompt too many.
  Future<void> _ensureIosAuthorization() async {
    if (_authorizationAsked) return;
    _authorizationAsked = true;

    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    try {
      // The same three PushService asks for, deliberately. Requesting badge
      // alone would be enough for this feature, but iOS grants exactly what is
      // asked for and never re-prompts -- so a badge-only grant here would
      // permanently deny alerts and sound to an iOS build that later gains a
      // Firebase configuration.
      await _local
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _local
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      // A refusal is a legitimate answer and updateBadge below simply becomes
      // a no-op. Nothing to recover from.
      debugPrint('AppBadgeService: notification permission request failed ($e)');
    }
  }

  Future<bool> _isSupported() async {
    final known = _supported;
    if (known != null) return known;

    await _ensureIosAuthorization();

    try {
      // Note the ordering everywhere else in this class depends on: the
      // Android side of isSupported() PROBES the launcher by writing a zero
      // badge. Asking after setting a count would wipe the count we just set,
      // so this is always asked first and then cached for good.
      final supported = await AppBadgePlus.isSupported();
      _supported = supported;
      if (!supported) {
        // Once, not once per poll. A launcher without badges is a supported
        // configuration, not a fault.
        debugPrint('AppBadgeService: launcher does not support icon badges');
      }
      return supported;
    } catch (e) {
      _supported = false;
      debugPrint('AppBadgeService: isSupported failed, badging disabled ($e)');
      return false;
    }
  }

  /// Test seam: forget everything learned about this launcher.
  @visibleForTesting
  void resetForTest() {
    _supported = null;
    _lastPushed = null;
    _authorizationAsked = false;
    _queue = Future<void>.value();
  }
}
