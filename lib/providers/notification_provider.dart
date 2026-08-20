import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import '../services/api_service.dart';

/// Keeps the notification feed and the approval-inbox badge fresh.
///
/// WHY POLLING RATHER THAN PUSH
/// ----------------------------
/// The server writes notifications to ospos_notifications and has done since
/// the approval system went in; the only wired delivery channel was email, and
/// the people who actually approve have no email address on file. Polling a
/// count endpoint closes that loop with no new packages, no Firebase project,
/// no APNs certificate and no device-token table to keep clean.
///
/// The poll is cheap on purpose: [refreshCounts] fetches two integers. The
/// full list is only pulled when a screen asks for it, and then with an
/// `after` cursor so the server returns only rows newer than what is held.
class NotificationProvider extends ChangeNotifier with WidgetsBindingObserver {
  NotificationProvider({ApiService? apiService})
      : _api = apiService ?? ApiService();

  final ApiService _api;

  static const _pollInterval = Duration(seconds: 90);
  static const _cursorKey = 'notification_cursor_id';

  Timer? _timer;
  bool _disposed = false;
  bool _polling = false;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  int _pendingApprovals = 0;
  bool _isLoading = false;
  String? _error;

  /// Newest notification id already seen, persisted so a cold start does not
  /// replay the whole feed as if it were new.
  String? _cursor;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  int get pendingApprovals => _pendingApprovals;

  /// What the nav badge should show: unread notifications plus anything
  /// actually waiting on this user to act.
  int get badgeCount => _unreadCount + _pendingApprovals;

  /// Notifications that arrived while the app was open, newest first.
  ///
  /// A screen listens to this to raise an in-app banner the moment an approval
  /// lands, which is as close to a push as this gets without a Firebase
  /// project, an APNs certificate and a device-token table to maintain.
  final _arrivals = StreamController<AppNotification>.broadcast();
  Stream<AppNotification> get arrivals => _arrivals.stream;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Call once the user is signed in. Safe to call again; it restarts cleanly.
  Future<void> start() async {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);

    final prefs = await SharedPreferences.getInstance();
    _cursor = prefs.getString(_cursorKey);

    await refreshCounts();
    _startTimer();
  }

  /// Call on logout. Clears state so the next user does not inherit a badge.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);

    _notifications = [];
    _unreadCount = 0;
    _pendingApprovals = 0;
    _cursor = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cursorKey);

    _safeNotify();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => refreshCounts());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No point polling a screen nobody is looking at, and a phone in a pocket
    // on a weak network is exactly where a stray timer costs battery.
    if (state == AppLifecycleState.resumed) {
      refreshCounts();
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// The cheap poll: two counts, nothing else.
  Future<void> refreshCounts() async {
    if (_polling) return;
    _polling = true;

    try {
      final results = await Future.wait([
        _api.getUnreadNotificationCount(),
        _api.getPendingApprovalsCount(),
      ]);

      var changed = false;

      final unread = results[0];
      if (unread.isSuccess && unread.data != null && unread.data != _unreadCount) {
        final rose = unread.data! > _unreadCount;
        _unreadCount = unread.data!;
        changed = true;

        // Only when the count went UP is there anything new to announce, and
        // only then is the extra request worth making.
        if (rose) await _pullArrivals();
      }

      final pending = results[1];
      // A 403 here is normal and not an error to surface: plenty of sellers
      // have no approvals permission at all, so the badge simply stays at
      // whatever the notification count contributes.
      if (pending.isSuccess && pending.data != null && pending.data != _pendingApprovals) {
        _pendingApprovals = pending.data!;
        changed = true;
      } else if (!pending.isSuccess && pending.statusCode == 403 && _pendingApprovals != 0) {
        _pendingApprovals = 0;
        changed = true;
      }

      if (changed) _safeNotify();
    } catch (_) {
      // A failed poll is not worth showing anyone; the next one is 90s away.
    } finally {
      _polling = false;
    }
  }

  /// Fetch notifications newer than the stored cursor and announce them.
  ///
  /// The `after` cursor is what keeps this from re-announcing the same row on
  /// every poll, and from replaying the entire backlog on a cold start.
  Future<void> _pullArrivals() async {
    final response = await _api.getNotifications(after: _cursor, limit: 20);
    if (!response.isSuccess || response.data == null || response.data!.isEmpty) {
      return;
    }

    final fresh = response.data!;

    // Newest first from the API; announce oldest first so the most recent
    // banner is the one left on screen.
    for (final notification in fresh.reversed) {
      if (!_arrivals.isClosed) _arrivals.add(notification);
    }

    // Merge into the held list so a screen already open updates too.
    final existing = _notifications.map((n) => n.id).toSet();
    _notifications = [
      ...fresh.where((n) => !existing.contains(n.id)),
      ..._notifications,
    ];

    await _saveCursor(fresh.first.id);
  }

  /// Pull the full feed for the notifications screen.
  Future<void> loadNotifications({bool refresh = false}) async {
    if (refresh) _notifications = [];

    _isLoading = true;
    _error = null;
    _safeNotify();

    final response = await _api.getNotifications(limit: 50);

    if (response.isSuccess && response.data != null) {
      _notifications = response.data!;
      if (_notifications.isNotEmpty) {
        await _saveCursor(_notifications.first.id);
      }
    } else {
      _error = response.message;
    }

    _isLoading = false;
    _safeNotify();

    // The list carries its own unread total; refresh the badge from it.
    await refreshCounts();
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;

    final response = await _api.markNotificationRead(notification.id);
    if (!response.isSuccess) return;

    final index = _notifications.indexWhere((n) => n.id == notification.id);
    if (index != -1) {
      _notifications[index] = AppNotification(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        notificationType: notification.notificationType,
        actionUrl: notification.actionUrl,
        actionText: notification.actionText,
        readAt: DateTime.now().toIso8601String(),
        createdAt: notification.createdAt,
        data: notification.data,
      );
    }

    if (_unreadCount > 0) _unreadCount--;
    _safeNotify();
  }

  Future<void> markAllRead() async {
    final response = await _api.markAllNotificationsRead();
    if (!response.isSuccess) return;

    final now = DateTime.now().toIso8601String();
    _notifications = _notifications
        .map((n) => AppNotification(
              id: n.id,
              title: n.title,
              body: n.body,
              notificationType: n.notificationType,
              actionUrl: n.actionUrl,
              actionText: n.actionText,
              readAt: n.readAt ?? now,
              createdAt: n.createdAt,
              data: n.data,
            ))
        .toList();

    _unreadCount = 0;
    _safeNotify();
  }

  /// Nudge the badge down immediately after acting on an approval, so the UI
  /// does not show a stale count for up to a poll interval.
  void decrementPendingApprovals() {
    if (_pendingApprovals > 0) {
      _pendingApprovals--;
      _safeNotify();
    }
  }

  Future<void> _saveCursor(String id) async {
    _cursor = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cursorKey, id);
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _arrivals.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
