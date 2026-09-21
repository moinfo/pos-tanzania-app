import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/customer_api_service.dart';
import '../utils/constants.dart';
import '../l10n/portal_language_switch.dart';
import '../screens/portal/portal_notifications_screen.dart';

/// Shared top bar for the customer portal's bottom-nav tabs (Dashboard /
/// Mikataba / Malipo / Taarifa / Account), mirroring the staff app's
/// [MainNavigation] branded app bar (logo + name on the brand color) instead
/// of each tab rolling its own plain AppBar or inline header.
///
/// Deliberately leaner than the staff bar: no drawer menu (the portal has no
/// drawer), no "switch business" icon (that's a staff-only, multi-tenant
/// employee feature -- a customer belongs to exactly one tenant), and no
/// dark-mode toggle (the portal doesn't support a dark theme).
///
/// Shows the customer's own tenant/business name (as already surfaced on the
/// Dashboard hero card) rather than the generic "Mopos" app name, since that
/// is what a customer recognizes -- falling back to the client's display
/// name only when the tenant name hasn't loaded yet.
class PortalTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// The customer's tenant/business name, e.g. from
  /// `CustomerApiService.getTenantName()`. Falls back to the client
  /// config's display name (and then the generic app name) when empty.
  final String? tenantName;

  const PortalTopBar({super.key, this.tenantName});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final barColor = AppColors.brandPrimary;
    final title = (tenantName != null && tenantName!.isNotEmpty)
        ? tenantName!
        : (ApiService.currentClient?.displayName ?? AppConstants.appName);

    return Container(
      color: barColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 16),
              if (ApiService.currentClient?.logoUrl != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Image.asset(
                    ApiService.currentClient!.logoUrl!,
                    height: 30,
                    width: 30,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const _NotificationBell(),
              const PortalLanguageSwitch(),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bell icon with an unread-count badge. Self-contained (fetches its own
/// count on mount) since [PortalTopBar] itself is stateless and shared
/// across every shell tab -- re-checks the count each time it's tapped and
/// the notification list screen is popped, so approving/rejecting a
/// submission while the customer is looking at the badge updates it without
/// needing a manual refresh.
class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  final _service = CustomerApiService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final response = await _service.getNotifications(limit: 1);
    if (!mounted || !response.isSuccess) return;
    setState(
        () => _unreadCount = (response.data?['unread_count'] as int?) ?? 0);
  }

  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PortalNotificationsScreen()),
    );
    _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: _open,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                _unreadCount > 9 ? '9+' : '$_unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
