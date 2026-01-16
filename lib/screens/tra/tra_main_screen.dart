import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../models/tra.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../services/tra_service.dart';
import 'tra_dashboard_screen.dart';
import 'tra_sales_screen.dart';
import 'tra_purchases_screen.dart';
import 'tra_expenses_screen.dart';
import 'tra_reports_screen.dart';

class TRAMainScreen extends StatefulWidget {
  const TRAMainScreen({super.key});

  @override
  State<TRAMainScreen> createState() => _TRAMainScreenState();
}

class _TRAMainScreenState extends State<TRAMainScreen> {
  final TRAService _traService = TRAService();

  int _selectedIndex = 0;
  List<EFDDevice> _efds = [];
  int? _defaultEfdId;
  bool _isLoadingEfds = true;

  @override
  void initState() {
    super.initState();
    _loadEFDs();
  }

  Future<void> _loadEFDs() async {
    final efds = await _traService.getEFDs();
    final defaultEfdId = await _traService.getDefaultEFDId();

    if (mounted) {
      setState(() {
        _efds = efds;
        _defaultEfdId = defaultEfdId;
        _isLoadingEfds = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final permissionProvider = context.watch<PermissionProvider>();

    // Build available tabs based on permissions
    final tabs = <_TRATab>[];

    // Home/Dashboard - always visible if user has TRA permission
    tabs.add(_TRATab(
      icon: Icons.home,
      label: 'Home',
      screen: TRADashboardContent(
        efds: _efds,
        defaultEfdId: _defaultEfdId,
        isLoadingEfds: _isLoadingEfds,
      ),
    ));

    // Sales
    if (permissionProvider.hasPermission(PermissionIds.traViewSales)) {
      tabs.add(_TRATab(
        icon: Icons.receipt_long,
        label: 'Sales',
        screen: TRASalesScreen(
          efds: _efds,
          initialEfdId: _defaultEfdId,
          showAppBar: false,
        ),
      ));
    }

    // Purchases
    if (permissionProvider.hasPermission(PermissionIds.traViewPurchases)) {
      tabs.add(_TRATab(
        icon: Icons.shopping_cart,
        label: 'Purchases',
        screen: TRAPurchasesScreen(
          efds: _efds,
          initialEfdId: _defaultEfdId,
          showAppBar: false,
        ),
      ));
    }

    // Expenses
    if (permissionProvider.hasPermission(PermissionIds.traViewExpenses)) {
      tabs.add(_TRATab(
        icon: Icons.money_off,
        label: 'Expenses',
        screen: TRAExpensesScreen(
          efds: _efds,
          initialEfdId: _defaultEfdId,
          showAppBar: false,
        ),
      ));
    }

    // Reports
    if (permissionProvider.hasPermission(PermissionIds.traViewReports)) {
      tabs.add(_TRATab(
        icon: Icons.assessment,
        label: 'Reports',
        screen: TRAReportsScreen(
          efds: _efds,
          defaultEfdId: _defaultEfdId,
        ),
      ));
    }

    // Ensure selected index is valid
    if (_selectedIndex >= tabs.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(_getAppBarTitle(tabs)),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingEfds
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: tabs.map((tab) => tab.screen).toList(),
            ),
      bottomNavigationBar: tabs.length > 1
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: isDark ? Colors.white54 : Colors.grey,
              selectedFontSize: 12,
              unselectedFontSize: 11,
              items: tabs.map((tab) => BottomNavigationBarItem(
                icon: Icon(tab.icon),
                label: tab.label,
              )).toList(),
            )
          : null,
    );
  }

  String _getAppBarTitle(List<_TRATab> tabs) {
    if (tabs.isEmpty) return 'TRADE';
    switch (_selectedIndex) {
      case 0:
        return 'TRADE';
      default:
        return 'TRADE ${tabs[_selectedIndex].label}';
    }
  }
}

class _TRATab {
  final IconData icon;
  final String label;
  final Widget screen;

  _TRATab({
    required this.icon,
    required this.label,
    required this.screen,
  });
}
