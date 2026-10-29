import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/permission_wrapper.dart';
import 'lodge_menu_items.dart';

/// Fifth bottom tab in LodgeShell: everything that doesn't fit Board/
/// Bookings/Calendar/Rooms as its own tab. Same entries as the drawer's
/// Lodge section (lodge_menu_items.dart) minus those four.
class LodgeMoreScreen extends StatelessWidget {
  const LodgeMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final headerColor = isDark ? AppColors.darkSurface : AppColors.brandPrimary;
    final entries = lodgeOverflowMenuEntries();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        title: const Text('More'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final entry = entries[i];
          return PermissionWrapper(
            permissionId: entry.permissionId,
            child: Card(
              color: isDark ? AppColors.darkCard : Colors.white,
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(entry.icon, color: AppColors.brandPrimary),
                title: Text(entry.label),
                trailing: entry.builder == null
                    ? const Text('Hivi karibuni', style: TextStyle(fontSize: 11.5, color: Colors.grey))
                    : const Icon(Icons.chevron_right),
                onTap: () => openLodgeMenuEntry(context, entry),
              ),
            ),
          );
        },
      ),
    );
  }
}
