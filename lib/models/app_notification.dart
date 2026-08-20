/// An in-app notification row from ospos_notifications.
///
/// Named AppNotification rather than Notification to avoid colliding with
/// Flutter's own Notification class, which is in scope everywhere widgets are.
class AppNotification {
  /// UUID, not an int — it doubles as the polling cursor.
  final String id;
  final String title;
  final String body;

  /// info | success | warning | error — drives the colour and icon.
  final String notificationType;

  /// A web URL like https://leruma.co.tz/approvals/view/18996. Useful for
  /// pulling the approval id out of, not for opening in a browser.
  final String? actionUrl;
  final String? actionText;
  final String? readAt;
  final String createdAt;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    required this.createdAt,
    this.actionUrl,
    this.actionText,
    this.readAt,
    this.data,
  });

  bool get isRead => readAt != null && readAt!.isNotEmpty;

  /// The approval this notification is about, dug out of the action_url.
  ///
  /// The server stores a web link rather than a structured id; parsing it is
  /// how the app turns "Approval Required" into a tap that opens the right
  /// request.
  int? get approvalId {
    final url = actionUrl;
    if (url == null) return null;
    final match = RegExp(r'/approvals/view/(\d+)').firstMatch(url);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? 'info',
      actionUrl: json['action_url']?.toString(),
      actionText: json['action_text']?.toString(),
      readAt: json['read_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      data: raw is Map<String, dynamic> ? raw : null,
    );
  }
}
