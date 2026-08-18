import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import 'production_batches_screen.dart';
import 'production_lots_screen.dart';
import 'production_reports_screen.dart';
import 'production_recipes_screen.dart';
import 'production_settings_screen.dart';

/// Holds the production module's own bottom navigation, so every page in it
/// keeps a menu and switching between them is one tap rather than back-then-
/// tap through the drawer.
///
/// An IndexedStack keeps each page alive: the batches list holds a date range
/// and a status filter, and rebuilding it on every switch would throw those
/// away and re-fetch.
class ProductionShell extends StatefulWidget {
  final int initialIndex;

  const ProductionShell({super.key, this.initialIndex = 0});

  @override
  State<ProductionShell> createState() => _ProductionShellState();
}

class _ProductionShellState extends State<ProductionShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();

    // Reports and Settings carry their own grants on top of the module one,
    // exactly as the web gates them. Destinations are built per user so the
    // bar never offers a page that 403s.
    final destinations = <_Destination>[
      const _Destination('Batches', Icons.precision_manufacturing_outlined,
          ProductionBatchesScreen()),
      const _Destination('Lots', Icons.layers_outlined, ProductionLotsScreen()),
      if (permissions.hasPermission(PermissionIds.productionReports))
        const _Destination('Reports', Icons.bar_chart, ProductionReportsScreen()),
      const _Destination('Recipes', Icons.menu_book_outlined, ProductionRecipesScreen()),
      if (permissions.hasPermission(PermissionIds.productionCostmap))
        const _Destination('Settings', Icons.settings_outlined, ProductionSettingsScreen()),
    ];

    // A revoked grant can shrink the list while a later tab is selected.
    final index = _index.clamp(0, destinations.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: destinations.map((d) => d.screen).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor:
            isDark ? AppColors.darkTextLight : Colors.grey[600],
        selectedFontSize: 11.5,
        unselectedFontSize: 11.5,
        items: destinations
            .map((d) => BottomNavigationBarItem(
                  icon: Icon(d.icon, size: 22),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

class _Destination {
  final String label;
  final IconData icon;
  final Widget screen;

  const _Destination(this.label, this.icon, this.screen);
}
