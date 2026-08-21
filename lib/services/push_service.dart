import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import '../screens/approvals_screen.dart';
import 'api_service.dart';

/// Handles a push that arrives while the app is in the background or dead.
///
/// This runs in a SEPARATE isolate with no access to the app's providers, so it
/// deliberately does almost nothing. It does not need to: every payload we send
/// carries a `notification` block, which means Android draws the tray entry
/// itself. The work that matters — deduping against the poll, opening the right
/// approval — happens back in the main isolate when the user taps, via
/// [PushService._handleTap].
///
/// It must still exist and be a top-level function with this annotation, or
/// firebase_messaging logs a warning and background data payloads are dropped.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally empty. See above.
}

/// FCM push, sitting alongside the existing polling in [NotificationProvider].
///
/// WHY BOTH
/// --------
/// Polling only runs while the app is open, so an approval raised after a
/// manager pockets their phone waited up to 90 seconds — and if the app was
/// closed, until they next opened it. Push reaches a closed app. Polling stays
/// because push is best-effort: it needs Play Services, a network, and a
/// notification permission the user can revoke at any time.
///
/// NOTHING HERE IS FATAL
/// ---------------------
/// Only the `leruma` flavor ships a google-services.json, and iOS ships none at
/// all. On every other build `Firebase.initializeApp()` throws, [isAvailable]
/// stays false, and the whole class turns into a no-op — the app keeps working
/// exactly as it did before, on polling alone. That is a supported state, not
/// an error, which is why failures here are swallowed rather than surfaced.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  /// Must match `fcm_android_channel` in the server's application/config/fcm.php.
  /// Android 8+ silently discards a notification whose channel does not exist.
  static const _channelId = 'approvals';
  static const _channelName = 'Approvals';
  static const _channelDescription =
      'Discount and credit limit requests that need your attention';

  final ApiService _api = ApiService();
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  NotificationProvider? _notifications;
  GlobalKey<NavigatorState>? _navigatorKey;

  bool _available = false;
  bool _started = false;
  String? _token;

  /// A tap that arrived before there was anywhere to send it — typically the
  /// app being launched from cold by tapping the notification, long before
  /// login has finished. Replayed by [flushPendingTap].
  int? _pendingApprovalId;

  final List<StreamSubscription<dynamic>> _subs = [];

  bool get isAvailable => _available;

  /// Bring Firebase up. Safe to call on any flavor and any platform.
  ///
  /// Returns false when this build has no Firebase configuration, which is the
  /// normal case for four of the five clients.
  static Future<bool> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      return true;
    } catch (e) {
      // No google-services.json / GoogleService-Info.plist for this flavor.
      debugPrint('PushService: Firebase unavailable, using polling only ($e)');
      return false;
    }
  }

  /// Wire up messaging. Call once, after [initializeFirebase] returns true.
  Future<void> start({
    required NotificationProvider notifications,
    required GlobalKey<NavigatorState> navigatorKey,
    required bool firebaseReady,
  }) async {
    _notifications = notifications;
    _navigatorKey = navigatorKey;
    _available = firebaseReady;

    if (!_available || _started) return;
    _started = true;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _createAndroidChannel();
      await _initLocalNotifications();

      // Foreground: FCM does NOT draw anything itself in this state, so we
      // draw it, and we also feed the provider so the in-app banner and the
      // badge behave exactly as they do for a polled arrival.
      _subs.add(FirebaseMessaging.onMessage.listen(_handleForeground));

      // Background (app alive, not on screen) and the user taps the tray entry.
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _handleTap(m.data),
      ));

      // Terminated: the tap that launched the process.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _handleTap(initial.data);
      }

      _subs.add(FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        // Firebase rotates tokens on its own schedule. Re-register or the
        // handset quietly stops receiving anything.
        _token = token;
        unawaited(_sendTokenToServer(token));
      }));
    } catch (e) {
      debugPrint('PushService: start failed, falling back to polling ($e)');
      _available = false;
    }
  }

  /// Ask for notification permission and register this handset to the person
  /// who just signed in. Call on the same seam as NotificationProvider.start().
  Future<void> onLogin() async {
    if (!_available) return;

    try {
      // On Android 13+ this is what actually raises the POST_NOTIFICATIONS
      // dialog; declaring the permission in the manifest alone does nothing.
      // On older Android it resolves immediately as granted.
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // The user said no. Polling still delivers everything while the app is
        // open, so there is nothing to warn about and nothing to retry.
        debugPrint('PushService: notification permission denied');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      _token = token;
      await _sendTokenToServer(token);
    } catch (e) {
      debugPrint('PushService: onLogin failed ($e)');
    }
  }

  /// Release this handset on logout.
  ///
  /// Deliberately awaited by the caller BEFORE the auth token is cleared: the
  /// unregister call is itself JWT-authenticated, so doing it afterwards would
  /// fail with a 401 and leave the row behind — pushing the next seller's
  /// approvals to the person who just signed out.
  Future<void> onLogout() async {
    if (!_available) return;

    final token = _token;
    _pendingApprovalId = null;

    try {
      if (token != null && token.isNotEmpty) {
        await _api.unregisterDeviceToken(token);
      }
      _token = null;
    } catch (e) {
      debugPrint('PushService: onLogout failed ($e)');
    }
  }

  /// Replay a notification tap that arrived before the app could act on it.
  /// Called once the user is signed in and the navigator exists.
  void flushPendingTap() {
    final id = _pendingApprovalId;
    if (id == null) return;
    _pendingApprovalId = null;
    _openApproval(id);
  }

  // ---- internals ----

  Future<void> _sendTokenToServer(String token) async {
    String? version;
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Diagnostic only; not worth failing registration over.
    }

    final result = await _api.registerDeviceToken(
      token: token,
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      appVersion: version,
    );

    if (!result.isSuccess) {
      debugPrint('PushService: token registration failed: ${result.message}');
    }
  }

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initLocalNotifications() async {
    // @mipmap/ic_launcher is guaranteed to exist for every flavor; a missing
    // icon makes the Android notification fail to post at all.
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final id = int.tryParse(payload);
        if (id != null) _openApproval(id);
      },
    );
  }

  Future<void> _handleForeground(RemoteMessage message) async {
    final notification = _toAppNotification(message);

    // Route through the provider rather than showing a banner directly. It
    // holds the announced-id set that keeps this from being shown twice when
    // the next poll returns the same row.
    final isNew = notification == null
        ? true
        : (_notifications?.notifyArrival(notification) ?? true);

    if (!isNew) return;

    final title = message.notification?.title ?? notification?.title;
    final body = message.notification?.body ?? notification?.body;
    if (title == null && body == null) return;

    final approvalId = _approvalIdFrom(message.data);

    await _local.show(
      // Collapse repeats about one approval onto a single tray entry.
      id: approvalId ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: approvalId?.toString(),
    );
  }

  void _handleTap(Map<String, dynamic> data) {
    final id = _approvalIdFrom(data);
    if (id == null) return;

    if (_navigatorKey?.currentState == null) {
      // Cold start: the navigator does not exist yet. Hold it until login has
      // settled — see flushPendingTap.
      _pendingApprovalId = id;
      return;
    }

    _openApproval(id);
  }

  void _openApproval(int approvalId) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      _pendingApprovalId = approvalId;
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ApprovalsScreen(initialApprovalId: approvalId),
      ),
    );
  }

  /// The approval id from the push payload.
  ///
  /// The server sends it as structured data precisely so this does not have to
  /// parse a URL. The action_url fallback only covers a server older than the
  /// change that added it.
  int? _approvalIdFrom(Map<String, dynamic> data) {
    final raw = data['approval_id'];
    if (raw != null) {
      final id = int.tryParse(raw.toString());
      if (id != null) return id;
    }

    final url = data['action_url']?.toString();
    if (url == null) return null;

    final match = RegExp(r'/approvals/view/(\d+)').firstMatch(url);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Rebuild the server's notification row from the push payload.
  ///
  /// Returns null when the payload carries no notification_id — without it we
  /// cannot dedupe against polling, and announcing it anyway risks showing the
  /// same approval twice. Better to let the poll deliver it a moment later.
  AppNotification? _toAppNotification(RemoteMessage message) {
    final data = message.data;
    final id = data['notification_id']?.toString();
    if (id == null || id.isEmpty) return null;

    return AppNotification(
      id: id,
      title: message.notification?.title ?? data['title']?.toString() ?? '',
      body: message.notification?.body ?? data['body']?.toString() ?? '',
      notificationType: data['notification_type']?.toString() ?? 'info',
      actionUrl: data['action_url']?.toString(),
      actionText: 'Open request',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }
}
