import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../l10n/portal_language_switch.dart';

/// Shared top bar for the customer portal's bottom-nav tabs (Dashboard /
/// Mikataba / Malipo / Taarifa / Account), mirroring the staff app's
/// [MainNavigation] branded app bar (logo + name on the brand color) instead
/// of each tab rolling its own plain AppBar or inline header.
///
/// Deliberately leaner than the staff bar: no drawer menu (the portal has no
/// drawer), no "switch business" icon (that's a staff-only, multi-tenant
/// employee feature -- a customer belongs to exactly one tenant), and no
/// dark-mode toggle (the portal doesn't support a dark theme). No
/// notification bell either -- the portal doesn't have a notifications
/// endpoint yet, and an icon that does nothing on tap is worse than no icon;
/// add one here once that lands.
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
              const PortalLanguageSwitch(),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
