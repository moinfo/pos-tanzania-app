import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/permission_provider.dart';
import '../providers/location_provider.dart';
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
import 'stock_tracking/stock_tracking_screen.dart';
import 'positions/positions_screen.dart';
import 'seller_report_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'nfc_cards_screen.dart';
import 'nfc_confirmations_screen.dart';
import 'nfc_card_lookup_screen.dart';
import 'credits_screen.dart';
import 'suppliers_credits_screen.dart';
import 'tra/tra_main_screen.dart';

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
  // Built dynamically to support client-specific screens
  // - SADA: Home, Sales, Expenses, Summary, Contracts, Reports (or Transactions if no stock location)
  // - Leruma: Home, Sales, Expenses, Summary, Seller, Reports
  // - Come & Save: Home, Sales, Expenses, Summary, Reports (or Transactions if no stock location)
  List<Map<String, dynamic>> _buildScreenConfigs(PermissionProvider permissionProvider, LocationProvider locationProvider, String? userId) {
    final isLeruma = ApiService.currentClient?.id == 'leruma';
    final hasContracts = ApiService.currentClient?.features.hasContracts ?? false;

    // Check if user has a stock location assigned
    final hasStockLocation = locationProvider.selectedLocation != null ||
        locationProvider.allowedLocations.isNotEmpty;

    // Check if user has transactions permission (Come & Save)
    final hasTransactionsPermission = permissionProvider.hasPermission(PermissionIds.transactions) ||
        permissionProvider.hasModulePermission(PermissionIds.transactions);

    // Use user ID as key to force widget recreation on user change
    final userKey = ValueKey('user_$userId');

    final configs = <Map<String, dynamic>>[
      {
        'screen': HomeScreen(key: userKey),
        'icon': Icons.home,
        'label': 'Home',
        'permission': PermissionIds.home, // module: home
      },
      {
        'screen': SalesScreen(key: ValueKey('sales_$userId')),
        'icon': Icons.point_of_sale,
        'label': 'Sales',
        'permission': PermissionIds.sales, // module: sales
      },
      {
        'screen': ExpensesScreen(key: ValueKey('expenses_$userId')),
        'icon': Icons.receipt_long,
        'label': 'Expenses',
        'permission': PermissionIds.expenses, // module: expenses
      },
      {
        'screen': TodaySummaryScreen(key: ValueKey('summary_$userId')),
        'icon': Icons.summarize,
        'label': 'Summary',
        'permission': PermissionIds.cashSubmit, // module: cash_submit
      },
    ];

    // Add Transactions screen if user has NO stock location but has transactions permission
    // Available for both SADA and Come & Save clients
    if (hasTransactionsPermission && !hasStockLocation) {
      configs.add({
        'screen': TransactionsScreen(key: ValueKey('transactions_$userId')),
        'icon': Icons.swap_horiz,
        'label': 'Transactions',
        'permission': PermissionIds.transactions, // module: transactions
      });
    }

    // Add Seller screen for Leruma only
    if (isLeruma) {
      configs.add({
        'screen': SellerReportScreen(key: ValueKey('seller_$userId')),
        'icon': Icons.person_outline,
        'label': 'Seller',
        'permission': PermissionIds.cashSubmitSellerReport, // Leruma seller report
        'lerumaOnly': true, // Flag for Leruma-specific screen
      });
    }

    // Add Contracts for clients with contracts feature (SADA)
    if (hasContracts) {
      configs.add({
        'screen': ContractsScreen(key: ValueKey('contracts_$userId')),
        'icon': Icons.assignment,
        'label': 'Contracts',
        'permission': PermissionIds.contracts, // module: contracts
      });
    }

    // Reports is available to all clients
    configs.add({
      'screen': ReportsScreen(key: ValueKey('reports_$userId')),
      'icon': Icons.assessment,
      'label': 'Reports',
      'permission': PermissionIds.reports, // module: reports
    });

    return configs;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Build drawer avatar with profile picture (Leruma feature) or default icon
  Widget _buildDrawerAvatar(dynamic user, bool isDark) {
    final hasCommissionDashboard = ApiService.currentClient?.features.hasCommissionDashboard ?? false;
    final profilePicture = user?.profilePicture;

    // Show profile picture only for Leruma (hasCommissionDashboard) and if picture exists
    if (hasCommissionDashboard && profilePicture != null && profilePicture.isNotEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.darkCard : Colors.white,
        ),
        child: ClipOval(
          child: Image.network(
            profilePicture,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              // Skeleton placeholder while loading
              return Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withOpacity(0.3),
                ),
                child: Icon(
                  Icons.person,
                  size: 30,
                  color: Colors.grey.withOpacity(0.5),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.person,
                size: 40,
                color: isDark ? AppColors.darkText : AppColors.primary,
              );
            },
          ),
        ),
      );
    }

    // Default avatar with icon
    return CircleAvatar(
      radius: 30,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      child: Icon(
        Icons.person,
        size: 40,
        color: isDark ? AppColors.darkText : AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final permissionProvider = context.watch<PermissionProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;

    // Build screen configs based on permissions, location, and user ID
    // User ID is used as key to force widget recreation on user change (fixes cache issue)
    final screenConfigs = _buildScreenConfigs(permissionProvider, locationProvider, user?.id);

    // Filter screens based on permissions AND client features
    final availableScreens = <Map<String, dynamic>>[];
    final Map<int, int> indexMapping = {}; // Maps bottom nav index to screen config index

    // Get current client's features
    final currentClient = ApiService.currentClient;
    final features = currentClient?.features;

    for (int i = 0; i < screenConfigs.length; i++) {
      final config = screenConfigs[i];
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
                  // Profile picture (Leruma feature) or default icon
                  _buildDrawerAvatar(user, isDark),
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
            // 1. Customers Menu
            ExpansionTile(
              leading: const Icon(Icons.people, color: AppColors.primary),
              title: const Text('Customers'),
              childrenPadding: const EdgeInsets.only(left: 16),
              children: [
                // Customers List
                PermissionWrapper(
                  permissionId: PermissionIds.customers,
                  child: ListTile(
                    leading: const Icon(Icons.people_outline, color: AppColors.primary),
                    title: const Text('Customers List'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomersScreen()),
                      );
                    },
                  ),
                ),
                // Customer Credits
                PermissionWrapper(
                  permissionId: PermissionIds.credits,
                  child: ListTile(
                    leading: const Icon(Icons.credit_card, color: AppColors.error),
                    title: const Text('Customer Credits'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreditsScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            // 2. Items - requires items permission
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
            // 3. Sales Menu
            ExpansionTile(
              leading: const Icon(Icons.point_of_sale, color: AppColors.primary),
              title: const Text('Sales'),
              childrenPadding: const EdgeInsets.only(left: 16),
              children: [
                // Sales History
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
                // Suspended Sales
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
              ],
            ),
            // 4. Suppliers Menu
            ExpansionTile(
              leading: const Icon(Icons.local_shipping, color: AppColors.primary),
              title: const Text('Suppliers'),
              childrenPadding: const EdgeInsets.only(left: 16),
              children: [
                // Suppliers List
                PermissionWrapper(
                  permissionId: PermissionIds.suppliers,
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                    title: const Text('Suppliers List'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SuppliersScreen()),
                      );
                    },
                  ),
                ),
                // Supplier Credits
                PermissionWrapper(
                  permissionId: PermissionIds.credits,
                  child: ListTile(
                    leading: const Icon(Icons.credit_card, color: AppColors.error),
                    title: const Text('Supplier Credits'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SuppliersCreditsScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            // 4. Receivings - requires receivings permission
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
            // 5. Cash Submit - requires cash_submit module permission
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
            // 6. Banking - requires cash_submit_banking permission
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
            // 7. TRADE (TRA) - requires tra permission
            if (ApiService.currentClient?.features.hasTRA ?? false)
              PermissionWrapper(
                permissionId: PermissionIds.tra,
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.deepPurple),
                  title: const Text('Trade'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TRAMainScreen()),
                    );
                  },
                ),
              ),
            // 8. NFC Menu - requires hasNfcCard feature
            if (ApiService.currentClient?.features.hasNfcCard ?? false)
              ExpansionTile(
                leading: const Icon(Icons.nfc, color: Colors.orange),
                title: const Text('NFC'),
                childrenPadding: const EdgeInsets.only(left: 16),
                children: [
                  // NFC Cards
                  PermissionWrapper(
                    permissionId: PermissionIds.nfcCardsView,
                    child: ListTile(
                      leading: const Icon(Icons.credit_card, color: Colors.orange),
                      title: const Text('NFC Cards'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NfcCardsScreen()),
                        );
                      },
                    ),
                  ),
                  // NFC Confirmations
                  PermissionWrapper(
                    permissionId: PermissionIds.nfcConfirmationsView,
                    child: ListTile(
                      leading: const Icon(Icons.verified, color: Colors.green),
                      title: const Text('NFC Confirmations'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NfcConfirmationsScreen()),
                        );
                      },
                    ),
                  ),
                  // NFC Card Lookup
                  PermissionWrapper(
                    permissionId: PermissionIds.nfcCardsView,
                    child: ListTile(
                      leading: const Icon(Icons.contactless, color: Colors.deepOrange),
                      title: const Text('NFC Card Lookup'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NfcCardLookupScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            // 9. Seller Report - Leruma only, requires cash_submit_seller_report permission
            if (ApiService.currentClient?.id == 'leruma')
              PermissionWrapper(
                permissionId: PermissionIds.cashSubmitSellerReport,
                child: ListTile(
                  leading: const Icon(Icons.person_outline, color: AppColors.primary),
                  title: const Text('Seller Report'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SellerReportScreen()),
                    );
                  },
                ),
              ),
            // 10. Financial Position - requires office permission
            PermissionWrapper(
              permissionId: PermissionIds.office,
              child: ListTile(
                leading: const Icon(Icons.analytics, color: AppColors.primary),
                title: const Text('Financial Position'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PositionsScreen()),
                  );
                },
              ),
            ),
            const Divider(),
            // Other menus
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
            // Profit Submit - requires cash_submit_profit_submitted permission
            PermissionWrapper(
              permissionId: PermissionIds.cashSubmitProfitSubmitted,
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
            // Stock Tracking - requires items_stock permission
            PermissionWrapper(
              permissionId: PermissionIds.stockTracking,
              child: ListTile(
                leading: const Icon(Icons.track_changes, color: AppColors.primary),
                title: const Text('Stock Tracking'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StockTrackingScreen()),
                  );
                },
              ),
            ),
            // Transactions - requires transactions permission
            PermissionWrapper(
              permissionId: PermissionIds.transactions,
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
