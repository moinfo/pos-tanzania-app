import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/permission_provider.dart';
import '../models/permission_model.dart';
import '../services/api_service.dart';
import '../widgets/permission_wrapper.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'today_summary_screen.dart';
import 'contracts_screen.dart';
import 'z_report/z_reports_list_screen.dart';
import 'cash_submit_screen.dart';
import 'expenses_screen.dart';
import 'customers_screen.dart';
import 'suppliers_screen.dart';
import 'items_screen.dart';
import 'sales_screen.dart';
import 'sales_history_screen.dart';
import 'suspended_sales_screen.dart';
import 'receivings/receivings_list_screen.dart';
import 'banking/banking_list_screen.dart';
import 'profit_submit/profit_submit_list_screen.dart';
import 'transactions/transactions_screen.dart';
import 'reports/reports_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _checkAuthStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for authentication changes
    final authProvider = context.watch<AuthProvider>();

    // If user is no longer authenticated, redirect to login
    if (!authProvider.isAuthenticated && !authProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      });
    }
  }

  /// Periodic check for auth token validity
  Future<void> _checkAuthStatus() async {
    // Check every 30 seconds if token still exists
    while (mounted) {
      await Future.delayed(const Duration(seconds: 30));
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        await authProvider.checkTokenValidity();
      }
    }
  }

  // Screen configuration with permissions
  // IMPORTANT: All screens MUST have permission checks based on ospos_permissions table
  final List<Map<String, dynamic>> _screenConfigs = [
    {
      'screen': const HomeScreen(),
      'icon': Icons.home,
      'label': 'Home',
      'permission': PermissionIds.home, // module: home
    },
    {
      'screen': const SalesScreen(),
      'icon': Icons.point_of_sale,
      'label': 'Sales',
      'permission': PermissionIds.sales, // module: sales
    },
    {
      'screen': const ExpensesScreen(),
      'icon': Icons.receipt_long,
      'label': 'Expenses',
      'permission': PermissionIds.expenses, // module: expenses
    },
    {
      'screen': const TodaySummaryScreen(),
      'icon': Icons.summarize,
      'label': 'Summary',
      'permission': PermissionIds.cashSubmit, // module: cash_submit
    },
    {
      'screen': const ReportsScreen(),
      'icon': Icons.assessment,
      'label': 'Reports',
      'permission': PermissionIds.reports, // module: reports
    },
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final permissionProvider = context.watch<PermissionProvider>();
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;

    // Filter screens based on permissions AND client features
    final availableScreens = <Map<String, dynamic>>[];
    final Map<int, int> indexMapping = {}; // Maps bottom nav index to screen config index

    // Get current client's features
    final currentClient = ApiService.currentClient;
    final features = currentClient?.features;

    for (int i = 0; i < _screenConfigs.length; i++) {
      final config = _screenConfigs[i];
      final permission = config['permission'] as String?;
      final label = config['label'] as String;

      // Skip if no permission specified (shouldn't happen but prevents crash)
      if (permission == null) continue;

      // Check if feature is enabled for this client
      bool featureEnabled = true;
      if (features != null) {
        switch (permission) {
          case PermissionIds.contracts:
            featureEnabled = features.hasContracts;
            break;
          case PermissionIds.zreports:
            featureEnabled = features.hasZReports;
            break;
          case PermissionIds.cashSubmit:
            featureEnabled = features.hasCashSubmit;
            break;
          case PermissionIds.banking:
            featureEnabled = features.hasBanking;
            break;
          case PermissionIds.profitSubmit:
            featureEnabled = features.hasProfitSubmit;
            break;
          case PermissionIds.expenses:
            featureEnabled = features.hasExpenses;
            break;
          case PermissionIds.customers:
            featureEnabled = features.hasCustomers;
            break;
          case PermissionIds.suppliers:
            featureEnabled = features.hasSuppliers;
            break;
          case PermissionIds.items:
            featureEnabled = features.hasItems;
            break;
          case PermissionIds.receivings:
            featureEnabled = features.hasReceivings;
            break;
          case PermissionIds.sales:
            featureEnabled = features.hasSales;
            break;
        }
      }

      // Skip if feature is not enabled for this client
      if (!featureEnabled) {
        print('🚫 $label feature is disabled for client ${currentClient?.displayName}');
        continue;
      }

      // Check if user has the required permission
      // For module permissions, also check if user has any sub-permission
      final hasPermission = permissionProvider.hasPermission(permission) ||
          permissionProvider.hasModulePermission(permission);

      if (hasPermission) {
        indexMapping[availableScreens.length] = i;
        availableScreens.add(config);
      }
    }

    // Adjust selected index if current selection is not available
    if (_selectedIndex >= availableScreens.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        // Move drawer toggle to leading (left side)
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            tooltip: 'Menu',
          ),
        ),
        actions: [
          // Dark mode toggle button (right side)
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: isDark ? AppColors.darkText : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'User',
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user?.email != null && user!.email!.isNotEmpty)
                    Text(
                      user.email!,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextLight : Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            // Sales History - requires sales permission
            PermissionWrapper(
              permissionId: PermissionIds.sales,
              child: ListTile(
                leading: const Icon(Icons.history, color: AppColors.primary),
                title: const Text('Sales History'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
                  );
                },
              ),
            ),
            // Suspended Sales - requires sales_suspended permission
            PermissionWrapper(
              permissionId: PermissionIds.salesSuspended,
              child: ListTile(
                leading: const Icon(Icons.pause_circle, color: AppColors.warning),
                title: const Text('Suspended Sales'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SuspendedSalesScreen()),
                  );
                },
              ),
            ),
            // Z Reports - requires cash_submit_z_report permission
            PermissionWrapper(
              permissionId: PermissionIds.cashSubmitZReport,
              child: ListTile(
                leading: const Icon(Icons.description, color: AppColors.primary),
                title: const Text('Z Reports'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ZReportsListScreen()),
                  );
                },
              ),
            ),
            // Cash Submit - requires cash_submit module permission
            PermissionWrapper(
              permissionId: PermissionIds.cashSubmit,
              child: ListTile(
                leading: const Icon(Icons.attach_money, color: AppColors.success),
                title: const Text('Cash Submit'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CashSubmitScreen()),
                  );
                },
              ),
            ),
            // Banking - requires cash_submit_banking permission
            PermissionWrapper(
              permissionId: PermissionIds.cashSubmitBanking,
              child: ListTile(
                leading: const Icon(Icons.account_balance, color: AppColors.primary),
                title: const Text('Banking'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BankingListScreen()),
                  );
                },
              ),
            ),
            // Profit Submit - requires office permission (profit submission is office function)
            PermissionWrapper(
              permissionId: PermissionIds.office,
              child: ListTile(
                leading: const Icon(Icons.trending_up, color: AppColors.primary),
                title: const Text('Profit Submit'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfitSubmitListScreen()),
                  );
                },
              ),
            ),
            // Customers - requires customers permission
            PermissionWrapper(
              permissionId: PermissionIds.customers,
              child: ListTile(
                leading: const Icon(Icons.people, color: AppColors.primary),
                title: const Text('Customers'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomersScreen()),
                  );
                },
              ),
            ),
            // Suppliers - requires suppliers permission
            PermissionWrapper(
              permissionId: PermissionIds.suppliers,
              child: ListTile(
                leading: const Icon(Icons.local_shipping, color: AppColors.primary),
                title: const Text('Suppliers'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SuppliersScreen()),
                  );
                },
              ),
            ),
            // Items - requires items permission
            PermissionWrapper(
              permissionId: PermissionIds.items,
              child: ListTile(
                leading: const Icon(Icons.inventory_2, color: AppColors.primary),
                title: const Text('Items'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ItemsScreen()),
                  );
                },
              ),
            ),
            // Receivings - requires receivings permission
            PermissionWrapper(
              permissionId: PermissionIds.receivings,
              child: ListTile(
                leading: const Icon(Icons.inventory, color: AppColors.success),
                title: const Text('Receivings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReceivingsListScreen()),
                  );
                },
              ),
            ),
            // Transactions - requires customers permission (transactions are customer-related)
            PermissionWrapper(
              permissionId: PermissionIds.customers,
              child: ListTile(
                leading: const Icon(Icons.swap_horiz, color: AppColors.primary),
                title: const Text('Transactions'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                  );
                },
              ),
            ),
            // Contracts - requires contracts permission
            PermissionWrapper(
              permissionId: PermissionIds.contracts,
              child: ListTile(
                leading: const Icon(Icons.assignment, color: AppColors.primary),
                title: const Text('Contracts'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContractsScreen()),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings, color: AppColors.primary),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
      body: availableScreens.isNotEmpty
          ? availableScreens[_selectedIndex]['screen'] as Widget
          : const Center(child: Text('No access to any screens')),
      bottomNavigationBar: availableScreens.length > 1
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textLight,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 12,
              unselectedFontSize: 11,
              items: availableScreens.map((config) {
                return BottomNavigationBarItem(
                  icon: Icon(config['icon'] as IconData),
                  label: config['label'] as String,
                );
              }).toList(),
            )
          : null, // Hide bottom nav if only one or no screens available
    );
  }
}
