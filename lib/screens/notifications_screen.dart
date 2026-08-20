import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import '../utils/constants.dart';
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
        title: const Text('Taarifa'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: provider.markAllRead,
                child: const Text(
                  'Soma zote',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => provider.loadNotifications(refresh: true),
              child: ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 56,
                          color: isDark
                              ? AppColors.darkTextLight
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Hakuna taarifa',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadNotifications(refresh: true),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final notification = provider.notifications[index];
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: unread ? 2 : 0,
      color: unread
          ? (isDark ? AppColors.darkCard : Colors.white)
          : (isDark ? AppColors.darkSurface : Colors.grey.shade50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: colour),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  unread ? FontWeight.bold : FontWeight.w500,
                              color: isDark ? AppColors.darkText : AppColors.text,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextLight
                            : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.createdAt,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextLight
                            : AppColors.textLight,
                      ),
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
