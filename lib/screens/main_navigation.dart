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
import 'financial_banking/financial_banking_screen.dart';
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
import 'shops_screen.dart';
import 'discount_requests_screen.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with TickerProviderStateMixin {
  late int _selectedIndex;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  double _currentRotationOffset = 0.0; // Offset to rotate items (in item units)
  int _totalNavItems = 0; // Will be set on first build to trigger sync
  bool _initialPositionSet = false; // Track if initial position has been set

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
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
    final hasShops = ApiService.currentClient?.features.hasShops ?? false;
    final hasDiscountRequests = ApiService.currentClient?.features.hasDiscountRequests ?? false;

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
        'icon': Icons.shopping_cart,
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

    // Add Shops for SADA client (shop registration with GPS)
    if (hasShops) {
      configs.add({
        'screen': ShopsScreen(key: ValueKey('shops_$userId')),
        'icon': Icons.store,
        'label': 'Shops',
        'permission': PermissionIds.customersShops, // customers_shops permission
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
    // Calculate rotation offset to bring selected item to center
    // Center index is (totalItems - 1) / 2
    // Offset = centerIndex - selectedIndex (how much to shift)
    final centerIndex = (_totalNavItems - 1) / 2.0;
    final newOffset = centerIndex - index;

    _animateRotationTo(newOffset);

    setState(() {
      _selectedIndex = index;
    });
  }

  void _animateRotationTo(double targetOffset) {
    _rotationAnimation = Tween<double>(
      begin: _currentRotationOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    _rotationController.forward(from: 0).then((_) {
      _currentRotationOffset = targetOffset;
    });
  }

  /// Build curved AppBar with rounded bottom corners
  Widget _buildCurvedAppBar(bool isDark, ThemeProvider themeProvider) {
    final appBarColor = isDark ? AppColors.darkSurface : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: appBarColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              // Menu button
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
              // Logo + Title
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (ApiService.currentClient?.logoUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Image.asset(
                          ApiService.currentClient!.logoUrl!,
                          height: 32,
                          width: 32,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    Text(
                      ApiService.currentClient?.displayName ?? AppConstants.appName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Dark mode toggle
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: () => themeProvider.toggleTheme(),
                tooltip: isDark ? 'Light Mode' : 'Dark Mode',
              ),
            ],
          ),
        ),
      ),
    );
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
      extendBody: true, // Allow body to extend behind bottom nav
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _buildCurvedAppBar(isDark, themeProvider),
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
                // Shops (SADA only)
                if (ApiService.currentClient?.features.hasShops ?? false)
                  PermissionWrapper(
                    permissionId: PermissionIds.customersShops,
                    child: ListTile(
                      leading: const Icon(Icons.store, color: AppColors.primary),
                      title: const Text('Shops'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ShopsScreen()),
                        );
                      },
                    ),
                  ),
              ],
            ),
            // Discount Requests (SADA only)
            if (ApiService.currentClient?.features.hasDiscountRequests ?? false)
              PermissionWrapper(
                permissionId: PermissionIds.customerDiscountRequests,
                child: ListTile(
                  leading: const Icon(Icons.discount, color: AppColors.primary),
                  title: const Text('Discount Requests'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DiscountRequestsScreen()),
                    );
                  },
                ),
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
                // New Sales
                PermissionWrapper(
                  permissionId: PermissionIds.sales,
                  child: ListTile(
                    leading: const Icon(Icons.add_shopping_cart, color: AppColors.primary),
                    title: const Text('New Sales'),
                    onTap: () {
                      Navigator.pop(context);
                      // Find the Sales screen index in availableScreens
                      final salesIndex = availableScreens.indexWhere(
                        (config) => config['label'] == 'Sales'
                      );
                      if (salesIndex != -1) {
                        _onItemTapped(salesIndex);
                      }
                    },
                  ),
                ),
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
                leading: const Icon(Icons.inventory, color: AppColors.primary),
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
            // 5. Cash Submit - requires cash_submit module permission (hidden for Leruma)
            if (ApiService.currentClient?.id != 'leruma')
              PermissionWrapper(
                permissionId: PermissionIds.cashSubmit,
                child: ListTile(
                  leading: const Icon(Icons.attach_money, color: AppColors.primary),
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
            // Hidden for leruma clients (they use Financial Banking instead)
            if (!(ApiService.currentClient?.features.hasFinancialBanking ?? false))
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
            // 6.5 Financial Banking - Leruma only (uses 'banking' permission from web)
            if (ApiService.currentClient?.features.hasFinancialBanking ?? false)
              PermissionWrapper(
                permissionId: PermissionIds.banking,
                child: ListTile(
                  leading: const Icon(Icons.analytics, color: AppColors.primary),
                  title: const Text('Financial Banking'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FinancialBankingScreen()),
                    );
                  },
                ),
              ),
            // 7. TRADE (TRA) - requires tra permission
            if (ApiService.currentClient?.features.hasTRA ?? false)
              PermissionWrapper(
                permissionId: PermissionIds.tra,
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: AppColors.primary),
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
                leading: const Icon(Icons.nfc, color: AppColors.primary),
                title: const Text('NFC'),
                childrenPadding: const EdgeInsets.only(left: 16),
                children: [
                  // NFC Cards
                  PermissionWrapper(
                    permissionId: PermissionIds.nfcCardsView,
                    child: ListTile(
                      leading: const Icon(Icons.credit_card, color: AppColors.primary),
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
                      leading: const Icon(Icons.verified, color: AppColors.primary),
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
                      leading: const Icon(Icons.contactless, color: AppColors.primary),
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
            // 10. Financial Position - requires office permission (hidden for Leruma)
            if (ApiService.currentClient?.id != 'leruma')
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
          ? MediaQuery(
              data: MediaQuery.of(context).removePadding(removeBottom: true),
              child: _buildCurvedBottomNav(availableScreens, isDark),
            )
          : null,
    );
  }

  /// Build curved bottom navigation with notch for FAB
  Widget _buildCurvedBottomNav(List<Map<String, dynamic>> screens, bool isDark) {
    // Separate screens into left and right sides (excluding Sales which is the FAB)
    // Left: Home, Summary  |  Center: Sales FAB  |  Right: Seller, Reports
    final leftItems = <Map<String, dynamic>>[];
    final rightItems = <Map<String, dynamic>>[];
    int salesIndex = -1;

    // Define which items go on the left side
    const leftLabels = {'Home', 'Summary', 'Expenses'};

    for (int i = 0; i < screens.length; i++) {
      final label = screens[i]['label'] as String;
      if (label == 'Sales') {
        salesIndex = i;
      } else if (leftLabels.contains(label)) {
        leftItems.add({...screens[i], 'originalIndex': i});
      } else {
        rightItems.add({...screens[i], 'originalIndex': i});
      }
    }

    // If no Sales screen, fall back to standard navigation
    if (salesIndex == -1) {
      return BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: screens.map((config) {
          return BottomNavigationBarItem(
            icon: Icon(config['icon'] as IconData),
            label: config['label'] as String,
          );
        }).toList(),
      );
    }

    // Update total nav items count and sync initial rotation offset
    final itemCount = screens.length;
    _totalNavItems = itemCount;

    // Set initial position on first build
    if (!_initialPositionSet && itemCount > 0) {
      _initialPositionSet = true;
      final centerIndex = (_totalNavItems - 1) / 2.0;
      _currentRotationOffset = centerIndex - _selectedIndex;
    }

    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        // Use animation value when animating, otherwise use current offset
        final rotationOffset = _rotationController.isAnimating
            ? _rotationAnimation.value
            : _currentRotationOffset;

        return SizedBox(
          height: 80,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Custom curved background - ALWAYS at center (0.5)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(double.infinity, 80),
                  painter: _CurvedNavPainter(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    curvePosition: 0.5, // Always center
                  ),
                ),
              ),
              // Navigation items - all visible, circular reorder so selected is at center
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    final itemWidth = screenWidth / screens.length;
                    final itemCount = screens.length;

                    // Build items with animated positions (circular reorder)
                    return Stack(
                      children: screens.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;

                        // Calculate which visual slot this item should be in
                        // offset tells us how much to shift each item's display position
                        double displayPosition = index + rotationOffset;

                        // Wrap around to keep all items in valid slots (0 to itemCount-1)
                        while (displayPosition < 0) displayPosition += itemCount;
                        while (displayPosition >= itemCount) displayPosition -= itemCount;

                        final xPos = displayPosition * itemWidth;

                        return Positioned(
                          left: xPos,
                          top: 0,
                          bottom: 0,
                          width: itemWidth,
                          child: _buildNavItem(
                            item['icon'] as IconData,
                            item['label'] as String,
                            index,
                            isDark,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Center(
        child: isSelected
            // Selected: larger icon only, no label, moved up into curve
            ? Transform.translate(
                offset: const Offset(0, -8),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 38,
                ),
              )
            // Unselected: smaller icon with label
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: AppColors.textLight,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }

}

// Custom painter for curved navigation bar with animated notch position
class _CurvedNavPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double curvePosition; // 0.0 = left edge, 1.0 = right edge

  _CurvedNavPainter({
    required this.color,
    required this.borderColor,
    this.curvePosition = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    // Calculate curve center based on position
    // curvePosition is already the exact ratio (0.0 to 1.0) of where the item center is
    final curveX = size.width * curvePosition;
    const curveRadius = 35.0;
    const curveDepth = 20.0;

    // Start from bottom left
    path.moveTo(0, size.height);
    // Line to top left
    path.lineTo(0, curveDepth);
    // Line to before curve
    path.lineTo(curveX - curveRadius - 10, curveDepth);
    // Curve down and around the selected item
    path.quadraticBezierTo(
      curveX - curveRadius,
      curveDepth,
      curveX - curveRadius + 5,
      curveDepth + 15,
    );
    path.arcToPoint(
      Offset(curveX + curveRadius - 5, curveDepth + 15),
      radius: const Radius.circular(30),
      clockwise: false,
    );
    path.quadraticBezierTo(
      curveX + curveRadius,
      curveDepth,
      curveX + curveRadius + 10,
      curveDepth,
    );
    // Line to top right
    path.lineTo(size.width, curveDepth);
    // Line to bottom right
    path.lineTo(size.width, size.height);
    // Close path
    path.close();

    // Draw fill
    canvas.drawPath(path, paint);

    // Draw border along the top edge only
    final borderPath = Path();
    borderPath.moveTo(0, curveDepth);
    borderPath.lineTo(curveX - curveRadius - 10, curveDepth);
    borderPath.quadraticBezierTo(
      curveX - curveRadius,
      curveDepth,
      curveX - curveRadius + 5,
      curveDepth + 15,
    );
    borderPath.arcToPoint(
      Offset(curveX + curveRadius - 5, curveDepth + 15),
      radius: const Radius.circular(30),
      clockwise: false,
    );
    borderPath.quadraticBezierTo(
      curveX + curveRadius,
      curveDepth,
      curveX + curveRadius + 10,
      curveDepth,
    );
    borderPath.lineTo(size.width, curveDepth);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CurvedNavPainter oldDelegate) {
    return oldDelegate.curvePosition != curvePosition ||
           oldDelegate.color != color ||
           oldDelegate.borderColor != borderColor;
  }
}

