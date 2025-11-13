import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../screens/main_navigation.dart';
import '../providers/permission_provider.dart';
import '../models/permission_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final permissionProvider = Provider.of<PermissionProvider>(context);

    // Define all possible navigation items with their permissions
    final allNavItems = [
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
      {
        'icon': Icons.summarize,
        'label': 'Summary',
        'permission': PermissionIds.cashSubmit,
      },
      {
        'icon': Icons.assignment,
        'label': 'Contracts',
        'permission': PermissionIds.contracts,
      },
    ];

    // Filter items based on permissions
    final availableItems = <BottomNavigationBarItem>[];
    final Map<int, int> indexMapping = {}; // Maps display index to original index

    for (int i = 0; i < allNavItems.length; i++) {
      final item = allNavItems[i];
      final permission = item['permission'] as String;

      // Check if user has permission (module or any sub-permission)
      if (permissionProvider.hasPermission(permission) ||
          permissionProvider.hasModulePermission(permission)) {
        indexMapping[availableItems.length] = i;
        availableItems.add(
          BottomNavigationBarItem(
            icon: Icon(item['icon'] as IconData),
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

    return BottomNavigationBar(
      currentIndex: displayIndex >= 0 && displayIndex < availableItems.length ? displayIndex : 0,
      onTap: (displayIndex) {
        // Map display index back to original index
        final originalIndex = indexMapping[displayIndex] ?? 0;
        _handleTap(context, originalIndex);
      },
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textLight,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 12,
      unselectedFontSize: 11,
      items: availableItems,
    );
  }
}
