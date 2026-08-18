import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api_service.dart';

/// Handles a notification the user tapped. Set by main.dart so this service
/// stays free of navigation and can be used before a Navigator exists.
typedef PushTapHandler = void Function(Map<String, dynamic> data);

/// Fires when the app is in the background or terminated.
///
/// Must be a top-level function: Android runs it in a separate isolate with
/// none of the app's state, so anything it touches has to be re-created.
/// Nothing is done here on purpose -- the system already displays the
/// notification, and work started in this isolate cannot update the UI.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // Deliberately empty. See above.
}

/// Push notifications.
///
/// Every entry point is a no-op unless the current client has Firebase
/// configured (ClientFeatures.hasPushNotifications). The config files exist
/// per flavor and only mopos has them, so initialising Firebase for sada or
/// leruma would throw at launch.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _channel = AndroidNotificationChannel(
    'mopos_default',
    'Mopos notifications',
    description: 'Approvals, stock, production and daily summaries',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  bool _initialised = false;
  String? _token;
  PushTapHandler? _onTap;

  bool get _enabled =>
      ApiService.currentClient?.features.hasPushNotifications ?? false;

  /// The token this device is currently registered with, if any.
  String? get token => _token;

  /// Start Firebase and the local-notification channel.
  ///
  /// Called once from main() BEFORE the first frame, because a notification
  /// that launched the app has to be readable at startup.
  Future<void> initialise({PushTapHandler? onTap}) async {
    if (!_enabled || _initialised) return;

    _onTap = onTap;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

      // Android only shows a notification by itself when the app is in the
      // background. In the foreground the payload arrives silently, so it is
      // re-posted through a local notification to be seen at all.
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _onTap?.call(_decode(payload));
          }
        },
      );

      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _onTap?.call(m.data));

      // The app was launched by tapping a notification while terminated.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _onTap?.call(initial.data);
      }

      _initialised = true;
    } catch (e) {
      // A missing or malformed config must not stop the app launching.
      debugPrint('PushService: initialise failed: $e');
    }
  }

  /// Ask permission, then register this device against the signed-in user.
  ///
  /// Called after login rather than at launch, for two reasons: the request
  /// needs a token to authenticate, and asking for notification permission
  /// on first launch -- before the user has seen anything -- is the surest
  /// way to have it denied.
  Future<void> registerForCurrentUser() async {
    if (!_enabled) return;
    if (!_initialised) await initialise(onTap: _onTap);
    if (!_initialised) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('PushService: permission denied');
        return;
      }

      // On iOS the FCM token is only issued once APNs has handed over its
      // own, which is not instant after permission is granted.
      if (Platform.isIOS) {
        await FirebaseMessaging.instance.getAPNSToken();
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('PushService: no FCM token yet');
        return;
      }

      await _send(token);

      // FCM rotates tokens. Without this the device goes quiet the first
      // time it happens, and nothing reports an error.
      FirebaseMessaging.instance.onTokenRefresh.listen(_send);
    } catch (e) {
      debugPrint('PushService: register failed: $e');
    }
  }

  Future<void> _send(String token) async {
    _token = token;
    final info = await PackageInfo.fromPlatform();

    final response = await _apiService.registerDevice(
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
      appVersion: '${info.version}+${info.buildNumber}',
    );

    debugPrint(response.isSuccess
        ? 'PushService: device registered'
        : 'PushService: register rejected: ${response.message}');
  }

  /// Drop this device's registration, so the next person to sign in here
  /// does not receive the previous user's notifications.
  Future<void> unregister() async {
    if (!_enabled || _token == null) return;

    try {
      await _apiService.unregisterDevice(_token!);
    } catch (e) {
      debugPrint('PushService: unregister failed: $e');
    }
    _token = null;
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _encode(message.data),
    );
  }

  // The local-notification payload is a single string, so the data map is
  // flattened into one and parsed back on tap.
  static String _encode(Map<String, dynamic> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join('&');

  static Map<String, dynamic> _decode(String payload) {
    final map = <String, dynamic>{};
    for (final pair in payload.split('&')) {
      final i = pair.indexOf('=');
      if (i > 0) map[pair.substring(0, i)] = pair.substring(i + 1);
    }
    return map;
  }
}
