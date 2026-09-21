import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../utils/constants.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';

/// In-app notification list -- rows exist whether or not the push reached
/// the device (the row is written the moment Push_lib::send_to_customer()
/// is called, the push itself is just a nudge), so this is the reliable
/// place to see every reminder/approval/rejection even if a push was
/// missed or notifications are off at the OS level.
class PortalNotificationsScreen extends StatefulWidget {
  const PortalNotificationsScreen({super.key});

  @override
  State<PortalNotificationsScreen> createState() =>
      _PortalNotificationsScreenState();
}

class _PortalNotificationsScreenState extends State<PortalNotificationsScreen> {
  final _service = CustomerApiService();
  List<Map<String, dynamic>>? _notifications;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final response = await _service.getNotifications();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        final list = (response.data?['notifications'] as List?) ?? [];
        _notifications = list.cast<Map<String, dynamic>>();
      } else {
        _error = response.message;
      }
    });
  }

  Future<void> _markAllRead() async {
    await _service.markAllNotificationsRead();
    _load();
  }

  Future<void> _tapNotification(Map<String, dynamic> n) async {
    if (n['is_read'] != true) {
      await _service.markNotificationRead(n['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: PortalLocale.instance.language,
      builder: (context, _, __) => Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          title: Text(PortalStrings.t('notifications')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: _markAllRead,
              child: Text(PortalStrings.t('mark_all_read'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _buildList(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final notifications = _notifications ?? [];
    if (notifications.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.notifications_none,
              size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Center(child: Text(PortalStrings.t('no_notifications'))),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _notificationCard(notifications[index]),
    );
  }

  Widget _notificationCard(Map<String, dynamic> n) {
    final isRead = n['is_read'] == true;
    final type = n['type'] as String? ?? 'general';
    final icon = type == 'payment_request_reviewed'
        ? Icons.receipt_long
        : type == 'payment_reminder'
            ? Icons.alarm
            : Icons.notifications;

    return InkWell(
      onTap: () => _tapNotification(n),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isRead
                  ? Colors.grey.shade200
                  : AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 20,
                color: isRead ? AppColors.textLight : AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n['title'] as String? ?? '',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              isRead ? FontWeight.w600 : FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(n['body'] as String? ?? '',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textLight)),
                  const SizedBox(height: 4),
                  Text(n['created_at'] as String? ?? '',
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.textLight)),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
