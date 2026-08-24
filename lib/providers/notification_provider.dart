import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_response.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../services/app_badge_service.dart';
import '../services/read_cache.dart';

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

  /// Set once the approvals count comes back 403.
  ///
  /// Most sellers hold no approvals grant, so that call can never succeed for
  /// them — and polling it every 90 seconds means twenty-one sellers each
  /// firing a guaranteed refusal all day. One is enough to learn from.
  bool _approvalsForbidden = false;

  /// created_at of the newest notification the server reported.
  ///
  /// The trigger for pulling arrivals, in place of the unread count: one
  /// notification arriving while the user marks another read elsewhere leaves
  /// the count flat, and a count-watching poll concludes nothing happened.
  String? _latestSeenAt;

  /// Set when a pull was due but failed.
  ///
  /// The unread count is committed as soon as it arrives, so the badge stays
  /// right even if the follow-up pull fails. But that also means the next poll
  /// sees no change and would never retry — the arrival would be announced
  /// never, and only surface if the user happened to open the feed. This makes
  /// the debt explicit so the next poll settles it.
  bool _pullOwed = false;

  /// False until the first poll of a session has landed.
  ///
  /// On a cold start _unreadCount is 0 in memory while the server may hold
  /// twelve unread rows, so that first poll always looks like a rise. Without
  /// this the app would announce every one of them: up to twenty six-second
  /// banners queued back to back before the newest is on screen. The first
  /// poll therefore sets the counts and announces nothing.
  bool _primed = false;

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
  /// Nothing subscribes to this today: the in-app banner it used to feed was
  /// removed because it sat over the bottom navigation bar. It is a broadcast
  /// stream, so announcing with no listener is a no-op -- the badge count, the
  /// held feed and the cursor are all maintained by the poll itself and do not
  /// depend on anyone listening here.
  final _arrivals = StreamController<AppNotification>.broadcast();
  Stream<AppNotification> get arrivals => _arrivals.stream;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// The last feed load failed because the server could not be reached, as
  /// opposed to answering that there is nothing.
  ///
  /// The screen has to be able to tell those apart. The badge on the app bar
  /// is served from a separate counter that survives an outage, so without
  /// this the feed said "No notifications" directly underneath a bell reading
  /// 26 -- the app contradicting itself in the same breath.
  bool get isOffline => _offline;
  bool _offline = false;

  /// When the feed last came off the server, so rows left on screen through an
  /// outage can say how old they are instead of passing for current.
  DateTime? get loadedAt => _loadedAt;
  DateTime? _loadedAt;

  /// Call once the user is signed in. Safe to call again; it restarts cleanly.
  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    _cursor = prefs.getString(_cursorKey);

    // No seeding here: the first refreshCounts() below is the priming poll,
    // which records where the feed ends and announces nothing.

    // Registered only now. As an observer, a resume event arriving before the
    // priming poll had run would call refreshCounts() with _primed still
    // false — harmless today, but registering after keeps the ordering
    // obvious rather than accidental.
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);

    await refreshCounts();
    _startTimer();
  }

  /// Record where the feed currently ends, announcing nothing.
  ///
  /// Returns false if the feed could not be read, so the caller can try again
  /// rather than proceed with no idea where the feed ends.
  Future<bool> _seedCursor() async {
    final epoch = _epoch;
    final response = await _api.getNotifications(limit: 1);
    if (epoch != _epoch) return false;

    if (!response.isSuccess) return false;

    final newest = response.data;
    if (newest != null && newest.isNotEmpty) {
      await _saveCursor(newest.first.createdAt);
      _latestSeenAt = newest.first.createdAt;
    }
    // An empty feed is a legitimate answer: there is nothing to seed from and
    // nothing that could be replayed.
    return true;
  }

  /// Call on logout. Clears state so the next user does not inherit a badge.
  Future<void> stop() async {
    // Bump first: any poll already awaiting a response is now stale and will
    // discard itself rather than repopulate the badge after sign-out.
    _epoch++;

    _timer?.cancel();
    _timer = null;
    _primed = false;
    _pullOwed = false;
    _latestSeenAt = null;
    _approvalsForbidden = false;
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
      // Started together, awaited separately: the two calls return different
      // types, so Future.wait would erase both to Object.
      final unreadFuture = _api.getUnreadNotificationCount();
      final pendingFuture = _approvalsForbidden
          ? Future.value(ApiResponse<int>.success(data: 0))
          : _api.getPendingApprovalsCount();

      final unread = await unreadFuture;
      final pending = await pendingFuture;

      // Signed out while these were in flight: drop everything.
      if (epoch != _epoch) return;

      var changed = false;

      if (unread.isSuccess && unread.data != null) {
        final count = unread.data!.unread;
        final latestAt = unread.data!.latestAt;

        if (count != _unreadCount) {
          _unreadCount = count;
          changed = true;
        }

        // Pull when something ARRIVED, which the timestamp reports exactly,
        // rather than when the count moved, which it does not.
        final arrived = latestAt != null && latestAt != _latestSeenAt;
        _latestSeenAt = latestAt;

        if (_primed && (arrived || _pullOwed)) {
          final pulled = await _pullArrivals();
          _pullOwed = !pulled;
          // A pull driven by the debt flag rather than by a count change
          // still merges rows into _notifications; without this an open feed
          // would not repaint until the next poll.
          if (pulled) changed = true;
        }
      }

      // The first poll of a session only establishes where things stand.
      // _primed is set only once the seed actually lands: marking it early and
      // then failing would leave _cursor null, and the next change would
      // announce the entire backlog — the storm this exists to prevent.
      if (!_primed) {
        _primed = await _seedCursor();
      }

      // A 403 here is normal and not an error to surface: plenty of sellers
      // have no approvals permission at all, so the badge simply stays at
      // whatever the notification count contributes.
      if (pending.isSuccess && pending.data != null && pending.data != _pendingApprovals) {
        _pendingApprovals = pending.data!;
        changed = true;
      } else if (!pending.isSuccess && pending.statusCode == 403) {
        // Latch only on the server actually saying "no grant". A captive
        // portal or proxy answering 403 HTML also lands here, and latching on
        // that would kill the badge for the rest of the session over a network
        // blip.
        if (pending.message.contains('do not have permission')) {
          _approvalsForbidden = true;
        }
        if (_pendingApprovals != 0) {
          _pendingApprovals = 0;
          changed = true;
        }
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
  Future<bool> _pullArrivals() async {
    final epoch = _epoch;

    final response = await _api.getNotifications(after: _cursor, limit: 20);
    if (epoch != _epoch) return true;

    if (!response.isSuccess) return false;
    if (response.data == null || response.data!.isEmpty) return true;

    final fresh = response.data!;

    // The cursor has second resolution, so two notifications landing in the
    // same second could both sit on the boundary. Dedupe by id rather than
    // trusting the timestamp alone.
    final unseen = fresh.where((n) => !_announced.contains(n.id)).toList();
    if (unseen.isEmpty) return true;

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
    return true;
  }

  /// Announce a notification that arrived by push rather than by polling.
  ///
  /// Push and polling are two deliveries of ONE event, and both will usually
  /// fire: FCM wakes the app, and the next 90-second poll finds the same row.
  /// Routing push through this method instead of straight to the UI is what
  /// stops the user seeing it twice — [_announced] is keyed on the server's
  /// notification id, which the push payload carries, so whichever channel
  /// arrives first wins and the second is dropped on the floor here.
  ///
  /// Returns true if this was genuinely new.
  bool notifyArrival(AppNotification notification) {
    if (notification.id.isEmpty) return false;
    if (_announced.contains(notification.id)) return false;

    _remember(notification.id);
    if (!_arrivals.isClosed) _arrivals.add(notification);

    if (!_notifications.any((n) => n.id == notification.id)) {
      _notifications = [notification, ..._notifications];
    }

    // A push means at least one unread row exists that the badge does not know
    // about yet. Nudge it now rather than leaving the count stale until the
    // next poll — but do not advance _cursor: this single payload is not proof
    // that everything older has been seen, and moving the cursor past an
    // unfetched row would lose it permanently.
    _unreadCount++;
    _safeNotify();

    return true;
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
    // Deliberately NOT clearing _notifications here. Emptying the list before
    // the request means a failed refresh wipes rows that were on screen and
    // leaves nothing to show -- the success branch replaces the list wholesale
    // anyway, so there was never anything to gain by clearing it early.
    _isLoading = true;
    _error = null;
    _safeNotify();

    final response = await _api.getNotifications(limit: 50);

    if (response.isSuccess && response.data != null) {
      _notifications = response.data!;
      _offline = false;
      _loadedAt = DateTime.now();
      if (_notifications.isNotEmpty) {
        await _saveCursor(_notifications.first.createdAt);
      }
    } else {
      _error = response.message;
      _offline = isTransportFailure(response);
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
    // The launcher icon is a second view of the SAME number the bell shows, so
    // it is updated on the same seam rather than from a handful of call sites.
    // Every path that can move the count -- a poll, a push arrival, a read, a
    // mark-all-read, an approval acted on, sign-out -- already ends here, so
    // hanging the badge off this one method is what makes it go DOWN as
    // reliably as it goes up. AppBadgeService ignores a repeat of the value it
    // last pushed, so the notifies that are really about _isLoading cost
    // nothing.
    AppBadgeService.instance.setCount(badgeCount);

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
