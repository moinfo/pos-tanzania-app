import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../screens/main_navigation.dart';
import '../providers/permission_provider.dart';
import '../providers/theme_provider.dart';
import '../models/permission_model.dart';
import '../services/api_service.dart';
import 'curved_bottom_navigation.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const AppBottomNavigation({
    super.key,
    this.currentIndex = -1,
    this.onTap,
  });

  void _handleTap(BuildContext context, int index) {
    if (onTap != null) {
      onTap!(index);
      return;
    }

    // Navigate to MainNavigation with the selected index
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => MainNavigation(initialIndex: index),
      ),
      (route) => false, // Remove all previous routes
    );
  }

  /// Build navigation items matching MainNavigation structure exactly
  /// IMPORTANT: Must match MainNavigation._screenConfigs order for correct index mapping
  /// - SADA: Home, Sales, Expenses, Summary, Contracts, Reports
  /// - Leruma: Home, Sales, Expenses, Credits, Seller (Summary + Reports in drawer)
  List<Map<String, dynamic>> _buildNavItems() {
    final isLeruma = ApiService.currentClient?.id == 'leruma';
    final hasContracts = ApiService.currentClient?.features.hasContracts ?? false;

    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.home,
        'label': 'Home',
        'permission': PermissionIds.home,
      },
      {
        'icon': Icons.point_of_sale,
        'label': 'Sales',
        'permission': PermissionIds.sales,
      },
      {
        'icon': Icons.receipt_long,
        'label': 'Expenses',
        'permission': PermissionIds.expenses,
      },
    ];

    // Must mirror MainNavigation._buildScreenConfigs exactly -- this widget is
    // the bar shown on pushed screens, so any difference makes the tabs jump
    // when navigating. Leruma swaps Summary/Reports out for Customer Credits.
    if (!isLeruma) {
      items.add({
        'icon': Icons.summarize,
        'label': 'Summary',
        'permission': PermissionIds.cashSubmit,
      });
    } else {
      items.add({
        'icon': Icons.credit_card,
        'label': 'Credits',
        'permission': PermissionIds.credits,
      });
    }

    // Add Seller screen for Leruma only
    if (isLeruma) {
      items.add({
        'icon': Icons.person_outline,
        'label': 'Seller',
        'permission': PermissionIds.cashSubmitSellerReport,
      });
    }

    // Add Contracts for clients with contracts feature (SADA)
    if (hasContracts) {
      items.add({
        'icon': Icons.assignment,
        'label': 'Contracts',
        'permission': PermissionIds.contracts,
      });
    }

    // Reports is available to all clients -- in the drawer for Leruma
    if (!isLeruma) {
      items.add({
        'icon': Icons.assessment,
        'label': 'Reports',
        'permission': PermissionIds.reports,
      });
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final permissionProvider = Provider.of<PermissionProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Get navigation items (matches MainNavigation structure)
    final allNavItems = _buildNavItems();

    // Filter items based on permissions
    final availableItems = <CurvedNavItem>[];
    final Map<int, int> indexMapping = {}; // Maps display index to original index

    for (int i = 0; i < allNavItems.length; i++) {
      final item = allNavItems[i];
      final permission = item['permission'] as String;

      // Check if user has permission (module or any sub-permission)
      if (permissionProvider.hasPermission(permission) ||
          permissionProvider.hasModulePermission(permission)) {
        indexMapping[availableItems.length] = i;
        availableItems.add(
          CurvedNavItem(
            icon: item['icon'] as IconData,
            label: item['label'] as String,
          ),
        );
      }
    }

    // If no items available or only 1 item, don't show bottom nav
    if (availableItems.length <= 1) {
      return const SizedBox.shrink();
    }

    // Map current index to display index
    int displayIndex = 0;
    if (currentIndex >= 0) {
      for (int i = 0; i < indexMapping.length; i++) {
        if (indexMapping[i] == currentIndex) {
          displayIndex = i;
          break;
        }
      }
    }

    if (ApiService.currentClient?.id == 'leruma') {
      return _buildLerumaBar(
        context,
        items: availableItems,
        indexMapping: indexMapping,
        // currentIndex is -1 on a pushed screen. Highlighting Home there was
        // wrong: the seller is on the statement, not on the Home tab.
        activeDisplayIndex: currentIndex >= 0 ? displayIndex : -1,
      );
    }

    return CurvedBottomNavigation(
      currentIndex: displayIndex >= 0 && displayIndex < availableItems.length ? displayIndex : 0,
      onTap: (displayIndex) {
        // Map display index back to original index
        final originalIndex = indexMapping[displayIndex] ?? 0;
        _handleTap(context, originalIndex);
      },
      selectedItemColor: AppColors.primary,
      unselectedItemColor: isDark ? Colors.white54 : AppColors.textLight,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      items: availableItems,
    );
  }

  /// Flat bar from design_handoff_home_credit 1.7, matching the one the main
  /// shell draws so tabs do not change shape when a screen is pushed.
  Widget _buildLerumaBar(
    BuildContext context, {
    required List<CurvedNavItem> items,
    required Map<int, int> indexMapping,
    required int activeDisplayIndex,
  }) {
    // Same order as MainNavigation._buildLerumaBottomNav; keep the two in step.
    const order = ['Seller', 'Home', 'Sales', 'Credits', 'Expenses'];

    final ordered = [...items.asMap().entries]
      ..sort((a, b) {
        int rank(MapEntry<int, CurvedNavItem> e) {
          final i = order.indexOf(e.value.label);
          return i == -1 ? order.length + e.key : i;
        }

        return rank(a).compareTo(rank(b));
      });

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEF1F5))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 7, bottom: 6),
          child: Row(
            children: ordered.map((entry) {
              final active = entry.key == activeDisplayIndex;
              final color =
                  active ? const Color(0xFF1668A6) : const Color(0xFF64748B);

              return Expanded(
                child: InkWell(
                  onTap: () =>
                      _handleTap(context, indexMapping[entry.key] ?? 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(entry.value.icon, size: 20, color: color),
                      const SizedBox(height: 4),
                      Text(
                        entry.value.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
