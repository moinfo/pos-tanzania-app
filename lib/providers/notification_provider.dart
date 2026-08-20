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

  /// Bumped by [stop]. A poll that was already in flight when the user signed
  /// out captures the old value and drops its result instead of writing the
  /// previous seller's badge and notifications back over a cleared state.
  int _epoch = 0;

  /// Ids already announced as banners, so a cursor tie (two notifications in
  /// the same second) cannot show the same one twice. Bounded — see [_remember].
  final _announced = <String>{};

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  int _pendingApprovals = 0;
  bool _isLoading = false;
  String? _error;

  /// created_at of the newest notification already seen, persisted so a cold
  /// start does not replay the whole feed as if it were new.
  ///
  /// A TIMESTAMP, not an id. The server applies this as `created_at > ?` and
  /// ids in that table are UUIDs; sending one makes MySQL coerce it to a zero
  /// date and match every row. The API now rejects a non-timestamp outright,
  /// but the reason the field is a timestamp is worth keeping written down.
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
    final prefs = await SharedPreferences.getInstance();
    _cursor = prefs.getString(_cursorKey);

    // With no cursor, every existing notification looks new. Seed from the
    // current newest WITHOUT announcing, or signing in would fire a banner per
    // unread row — twenty stacked snackbars on the first screen.
    if (_cursor == null) {
      await _seedCursor();
    }

    // Registered only now. As an observer, a resume event arriving mid-seed
    // would call refreshCounts() while _cursor is still null, and
    // _pullArrivals would then announce the entire backlog — the exact thing
    // seeding exists to prevent.
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);

    await refreshCounts();
    _startTimer();
  }

  /// Record where the feed currently ends, announcing nothing.
  Future<void> _seedCursor() async {
    final epoch = _epoch;
    final response = await _api.getNotifications(limit: 1);
    if (epoch != _epoch) return;

    final newest = response.data;
    if (response.isSuccess && newest != null && newest.isNotEmpty) {
      await _saveCursor(newest.first.createdAt);
    }
  }

  /// Call on logout. Clears state so the next user does not inherit a badge.
  Future<void> stop() async {
    // Bump first: any poll already awaiting a response is now stale and will
    // discard itself rather than repopulate the badge after sign-out.
    _epoch++;

    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    _announced.clear();

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

    final epoch = _epoch;

    try {
      final results = await Future.wait([
        _api.getUnreadNotificationCount(),
        _api.getPendingApprovalsCount(),
      ]);

      // Signed out while these were in flight: drop everything.
      if (epoch != _epoch) return;

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
    final epoch = _epoch;

    final response = await _api.getNotifications(after: _cursor, limit: 20);
    if (epoch != _epoch) return;

    if (!response.isSuccess || response.data == null || response.data!.isEmpty) {
      return;
    }

    final fresh = response.data!;

    // The cursor has second resolution, so two notifications landing in the
    // same second could both sit on the boundary. Dedupe by id rather than
    // trusting the timestamp alone.
    final unseen = fresh.where((n) => !_announced.contains(n.id)).toList();
    if (unseen.isEmpty) return;

    // Newest first from the API; announce oldest first so the most recent
    // banner is the one left on screen.
    for (final notification in unseen.reversed) {
      _remember(notification.id);
      if (!_arrivals.isClosed) _arrivals.add(notification);
    }

    // Merge into the held list so a screen already open updates too.
    final existing = _notifications.map((n) => n.id).toSet();
    _notifications = [
      ...unseen.where((n) => !existing.contains(n.id)),
      ..._notifications,
    ];

    await _saveCursor(fresh.first.createdAt);
  }

  /// Keep the announced-id set from growing without bound on a long shift.
  void _remember(String id) {
    if (_announced.length >= 200) {
      _announced.remove(_announced.first);
    }
    _announced.add(id);
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
        await _saveCursor(_notifications.first.createdAt);
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
