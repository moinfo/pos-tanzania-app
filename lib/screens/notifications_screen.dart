import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/state_views.dart';
import 'approvals_screen.dart';

/// The notification feed.
///
/// Tapping one marks it read and, when it is about an approval, opens that
/// request directly — the id is parsed out of the action_url the server
/// stores, which is a web link rather than a structured field.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: provider.markAllRead,
                icon: const Icon(Icons.done_all, size: 17, color: Colors.white),
                label: const Text(
                  'Mark all read',
                  style: TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return SkeletonRowList(
                isDark: isDark, itemCount: 7, hasTrailingAmount: false);
          }

          if (provider.notifications.isEmpty) {
            return EmptyStateView(
              icon: Icons.notifications_none,
              title: 'No notifications',
              message: 'You will see requests and decisions here.',
              isDark: isDark,
              onRefresh: () => provider.loadNotifications(refresh: true),
            );
          }

          final unread = provider.unreadCount;

          return RefreshIndicator(
            onRefresh: () => provider.loadNotifications(refresh: true),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: provider.notifications.length + (unread > 0 ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (unread > 0 && index == 0) {
                  return _UnreadStrip(count: unread, isDark: isDark);
                }
                final notification =
                    provider.notifications[index - (unread > 0 ? 1 : 0)];
                return _NotificationCard(
                  notification: notification,
                  isDark: isDark,
                  onTap: () => _open(provider, notification),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Future<void> _open(
    NotificationProvider provider,
    AppNotification notification,
  ) async {
    await provider.markRead(notification);
    if (!mounted) return;

    final approvalId = notification.approvalId;
    if (approvalId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApprovalsScreen(initialApprovalId: approvalId),
      ),
    );
  }
}

/// A single line saying how much is unread, so the count is legible without
/// counting dots down the list.
class _UnreadStrip extends StatelessWidget {
  const _UnreadStrip({required this.count, required this.isDark});

  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            count == 1 ? '1 new notification' : '$count new notifications',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isDark;
  final VoidCallback onTap;

  (IconData, Color) get _look {
    switch (notification.notificationType) {
      case 'success':
        return (Icons.check_circle, AppColors.success);
      case 'error':
        return (Icons.cancel, AppColors.error);
      case 'warning':
        return (Icons.pending_actions, AppColors.warning);
      default:
        return (Icons.info_outline, AppColors.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, colour) = _look;
    final unread = !notification.isRead;
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final opens = notification.approvalId != null;

    return Material(
      color: unread
          ? (isDark ? AppColors.darkCard : Colors.white)
          : (isDark ? AppColors.darkSurface : Colors.grey.shade50),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unread
                  ? colour.withValues(alpha: 0.35)
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: colour),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                              color: isDark ? AppColors.darkText : AppColors.text,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: colour,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          Formatters.formatDate(notification.createdAt,
                              format: 'dd MMM yyyy HH:mm'),
                          style: TextStyle(fontSize: 10.5, color: muted),
                        ),
                        if (opens) ...[
                          const Spacer(),
                          Text(
                            'OPEN REQUEST',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: colour,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right, size: 14, color: colour),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
