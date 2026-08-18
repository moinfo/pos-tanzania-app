import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/app_notification.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

/// One place for everything the system has told this user.
///
/// The rows exist whether or not the push arrived, so this is the reliable
/// list -- a phone that was off, or a user who declined the notification
/// permission, still finds everything here.
class NotificationsScreen extends StatefulWidget {
  /// Where a notification of each type should take the user. Supplied by the
  /// caller so this screen does not need to know about every other screen.
  final void Function(String type, Map<String, dynamic> data)? onOpen;

  const NotificationsScreen({super.key, this.onOpen});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<AppNotification> _notifications = [];
  int _unread = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getNotifications();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _notifications = response.data!.notifications;
        _unread = response.data!.unreadCount;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _markAllRead() async {
    final messenger = ScaffoldMessenger.of(context);
    final response = await _apiService.markAllNotificationsRead();
    if (!mounted) return;

    if (response.isSuccess) {
      _load();
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(response.message),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _open(AppNotification n) async {
    // Mark read first: the tap may navigate away, and the user should not
    // come back to find it still unread.
    if (!n.isRead) {
      await _apiService.markNotificationRead(n.id);
      if (mounted) _load();
    }

    widget.onOpen?.call(n.type, n.data);
  }

  IconData _icon(String type) {
    switch (type) {
      case 'item_approval':
        return Icons.fact_check_outlined;
      case 'low_stock':
        return Icons.inventory_2_outlined;
      case 'subscription_expiring':
        return Icons.card_membership_outlined;
      case 'production_ready':
      case 'lot_low':
        return Icons.precision_manufacturing_outlined;
      case 'daily_report':
        return Icons.summarize_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color _colour(String type) {
    switch (type) {
      case 'item_approval':
        return AppColors.warning;
      case 'low_stock':
        return AppColors.error;
      case 'subscription_expiring':
        return AppColors.warning;
      case 'production_ready':
      case 'lot_low':
        return AppColors.info;
      default:
        return AppColors.primary;
    }
  }

  /// Relative for anything recent, absolute once it stops being useful.
  String _when(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final at = DateTime.parse(raw);
      final ago = DateTime.now().difference(at);

      if (ago.inMinutes < 1) return 'just now';
      if (ago.inMinutes < 60) return '${ago.inMinutes}m ago';
      if (ago.inHours < 24) return '${ago.inHours}h ago';
      if (ago.inDays < 7) return '${ago.inDays}d ago';
      return DateFormat('dd MMM').format(at);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark ? AppColors.darkTextLight : Colors.grey[600])),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Icon(Icons.notifications_none,
                size: 56, color: isDark ? Colors.grey[700] : Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Nothing yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? AppColors.darkTextLight : Colors.grey[500],
                    fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _notifications.length,
        itemBuilder: (_, i) => _buildCard(_notifications[i], isDark),
      ),
    );
  }

  Widget _buildCard(AppNotification n, bool isDark) {
    final colour = _colour(n.type);
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextLight : Colors.grey[600];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // Unread is carried by weight and a dot rather than a different card
      // colour, which reads as an error state to most people.
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: n.isRead ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _open(n),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_icon(n.type), color: colour, size: 20),
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
                            n.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight:
                                  n.isRead ? FontWeight.w500 : FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(n.body,
                        style: TextStyle(fontSize: 13, color: subColor)),
                    const SizedBox(height: 5),
                    Text(_when(n.createdAt),
                        style: TextStyle(fontSize: 11.5, color: subColor)),
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
