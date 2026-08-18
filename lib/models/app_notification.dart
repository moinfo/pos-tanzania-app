// The in-app notification centre.
//
// Backend: application/controllers/api/Notifications.php over
// ospos_notifications. Rows exist whether or not the push reached the
// handset, so this list is the reliable record -- the push is only a nudge.

class AppNotification {
  final int id;

  /// item_approval, low_stock, subscription_expiring, production_ready,
  /// lot_low, daily_report, test. Drives both the icon and where a tap goes.
  final String type;
  final String title;
  final String body;

  /// Same keys the push payload carries. Decoded server-side, so it arrives
  /// as a map rather than a JSON string.
  final Map<String, dynamic> data;
  final bool isRead;
  final String? createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      type: json['type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      // PHP encodes an empty map as {} but an empty array as [], so a
      // notification saved with no data can arrive as either.
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : <String, dynamic>{},
      isRead: json['is_read'] == true,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class NotificationListResponse {
  final List<AppNotification> notifications;
  final int unreadCount;

  NotificationListResponse({
    required this.notifications,
    required this.unreadCount,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    return NotificationListResponse(
      notifications: (json['notifications'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(AppNotification.fromJson)
              .toList() ??
          [],
      unreadCount: json['unread_count'] is int
          ? json['unread_count']
          : int.tryParse('${json['unread_count']}') ?? 0,
    );
  }
}
