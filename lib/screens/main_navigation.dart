import 'package:flutter/material.dart' hide Text;
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/permission_provider.dart';
import '../providers/location_provider.dart';
import '../models/stock_location.dart';
import '../models/permission_model.dart';
import '../services/api_service.dart';
import '../widgets/offline_indicator.dart';
import '../widgets/permission_wrapper.dart';
import '../utils/constants.dart';
import '../widgets/brand_backdrop.dart';
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
import 'payment_summary_screen.dart';
import 'approvals_screen.dart';
import 'credit_limits_screen.dart';
import 'notifications_screen.dart';
import '../providers/notification_provider.dart';
import 'receivings/receivings_list_screen.dart';
import 'banking/banking_list_screen.dart';
import 'financial_banking/financial_banking_screen.dart';
import 'profit_submit/profit_submit_list_screen.dart';
import 'transactions/transactions_screen.dart';
import 'reports/reports_screen.dart';
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
import 'borrowed_money/borrowed_money_list_screen.dart';
import 'app_update_screen.dart';
import '../providers/update_provider.dart';
import '../widgets/update_prompt.dart';
import '../services/token_refresher.dart';
import '../widgets/session_dialogs.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late int _selectedIndex;

  /// The permission-filtered tab list from the last build, so actions outside
  /// the bottom bar (e.g. landing on the cart after resuming a suspended
  /// sale) can find a tab's index without re-running the filter logic.
  List<Map<String, dynamic>> _lastAvailableScreens = const [];
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  double _currentRotationOffset = 0.0; // Offset to rotate items (in item units)
  int _totalNavItems = 0; // Will be set on first build to trigger sync
  bool _initialPositionSet = false; // Track if initial position has been set

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialIndex;
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
    _checkAuthStatus();
    // check() notifies listeners straight away, and initState runs inside the
    // build phase: calling it here threw "setState() called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  /// Ask the server once per sign-in whether a newer build is published, and
  /// offer it if so.
  ///
  /// The delay is not cosmetic. This screen mounts the instant the user lands
  /// after signing in, while the first tab is still fetching; raising a sheet
  /// into that is how an update prompt ends up on top of a half-drawn screen,
  /// and how it gets dismissed by a tap that was aimed at something else.
  /// Three seconds is enough for the landing tab to settle.
  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    await context.read<UpdateProvider>().check();

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await maybeShowUpdatePrompt(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Employee grants are managed on the web; pick up any change when the
    // app comes back to the front (throttled inside the provider).
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<PermissionProvider>().refreshInBackground();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
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
        // Renew the session before it lapses, so a seller is not asked for
        // their password mid-shift once a day. Costs a local expiry read on
        // each tick and a round trip only in the last hours of the token.
        await TokenRefresher.instance.refreshIfExpiringSoon();
      }
    }
  }

  // Screen configuration with permissions
  // IMPORTANT: All screens MUST have permission checks based on ospos_permissions table
  // Built dynamically to support client-specific screens
  // - SADA: Home, Sales, Expenses, Summary, Contracts, Reports (or Transactions if no stock location)
  // - Leruma: Home, Sales, Expenses, Credits, Seller (Summary + Reports in drawer)
  // - Come & Save: Home, Sales, Expenses, Summary, Reports (or Transactions if no stock location)
  /// Sign out, once the user has said so twice.
  ///
  /// Lifted out of the drawer list when the action moved into the header: an
  /// icon is easier to hit by accident than a labelled row, so the
  /// confirmation is doing more work than it used to.
  Future<void> _confirmLogout(BuildContext context) async {
    Navigator.pop(context);

    final confirm = await showLogoutConfirmation(context);

    if (!confirm || !context.mounted) return;

    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// Put the seller in front of the till.
  ///
  /// Both ways into suspended sales end here, because resuming loads the cart
  /// and leaving the seller looking at the list reads as nothing having
  /// happened.
  ///
  /// Two routes because the till is a tab for most clients and a drawer item
  /// for Leruma, where Payment Summary took the bar slot. Falling back to a
  /// push rather than doing nothing matters: without it, resuming a sale on
  /// Leruma would silently leave the seller on the suspended list with a cart
  /// they cannot see.
  void _openSales() => _openTab('Sales', () => SalesScreen(key: UniqueKey()));

  /// Open a drawer destination that is also a bottom-bar tab.
  ///
  /// Switches to the tab THROUGH [_onItemTapped], which is what rotates the bar
  /// so the tab's icon lands in the centre notch, active. Setting
  /// `_selectedIndex` alone changed the screen but left the bar's rotation
  /// where it was, so the active icon sat off to one side. Where the client has
  /// no such tab, [fallback] is pushed as a normal screen instead.
  void _openTab(String label, Widget Function() fallback) {
    if (!mounted) return;

    final index =
        _lastAvailableScreens.indexWhere((s) => s['label'] == label);

    if (index >= 0) {
      _onItemTapped(index);
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => fallback()));
  }

  List<Map<String, dynamic>> _buildScreenConfigs(PermissionProvider permissionProvider, LocationProvider locationProvider, String? userId) {
    final isLeruma = ApiService.currentClient?.id == 'leruma';
    final hasContracts = ApiService.currentClient?.features.hasContracts ?? false;
    final hasShops = ApiService.currentClient?.features.hasShops ?? false;
    final hasDiscountRequests = ApiService.currentClient?.features.hasDiscountRequests ?? false;

    // Check if user has a stock location assigned
    final hasStockLocation = locationProvider.selectedLocation != null ||
        locationProvider.allowedLocations.isNotEmpty;

    // Check if user has transactions permission (Come & Save)
    // The module grant itself, as on the web (a lone sub-permission such as
    // transactions_deposit_add does not make the module visible).
    final hasTransactionsPermission =
        permissionProvider.hasPermission(PermissionIds.transactions);

    // Use user ID as key to force widget recreation on user change
    final userKey = ValueKey('user_$userId');

    final configs = <Map<String, dynamic>>[
      {
        'screen': HomeScreen(key: userKey),
        'icon': Icons.home,
        'label': 'Home',
        'permission': PermissionIds.home, // module: home
      },
      // The till. Leruma takes it OUT of the bar and puts Payment Summary in
      // its place -- reconciling what came in is the thing that gets opened
      // between route stops, while a sale is started from the drawer. Every
      // other client keeps Sales here; this slot is the only difference.
      if (!isLeruma)
        {
          'screen': SalesScreen(key: ValueKey('sales_$userId'), embedded: true),
          'icon': Icons.shopping_cart,
          'label': 'Sales',
          'permission': PermissionIds.sales, // module: sales
        }
      else
        {
          'screen': PaymentSummaryScreen(
            key: ValueKey('payment_$userId'),
            embedded: true,
          ),
          'icon': Icons.payments,
          'label': 'Payment',
          'permission': PermissionIds.salesPaymentSummary,
        },
      {
        'screen': ExpensesScreen(key: ValueKey('expenses_$userId')),
        'icon': Icons.receipt_long,
        'label': 'Expenses',
        'permission': PermissionIds.expenses, // module: expenses
      },
    ];

    // Leruma keeps the bottom bar for day-to-day selling: Summary and Reports
    // move to the drawer and Customer Credits takes a slot, because chasing
    // customer debt is a daily task for a seller while reporting is not.
    if (!isLeruma) {
      configs.add({
        'screen': TodaySummaryScreen(key: ValueKey('summary_$userId')),
        'icon': Icons.summarize,
        'label': 'Summary',
        'permission': PermissionIds.cashSubmit, // module: cash_submit
      });
    } else {
      configs.add({
        'screen': CreditsScreen(key: ValueKey('credits_$userId'), embedded: true),
        'icon': Icons.credit_card,
        'label': 'Credits',
        'permission': PermissionIds.credits, // module: credits
      });
    }

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

    // Suspended sales as a tab, Leruma only. It was reachable from the drawer
    // alone, which is two taps and a scroll for something a seller does
    // between customers all day -- a held basket is picked up again within
    // minutes, not hours.
    //
    // onResumed rather than a pop: as a tab this screen owns no route, so
    // popping would take the whole shell down. Resuming loads the cart, so the
    // seller is sent to Sales where the cart is.
    if (isLeruma) {
      configs.add({
        'screen': SuspendedSalesScreen(
          key: ValueKey('suspended_$userId'),
          onResumed: _openSales,
          embedded: true,
        ),
        'icon': Icons.pause_circle_outline,
        'label': 'Suspended',
        'permission': PermissionIds.salesSuspended,
        'lerumaOnly': true,
      });
    }

    // Add Seller screen for Leruma only
    if (isLeruma) {
      configs.add({
        'screen': SellerReportScreen(key: ValueKey('seller_$userId'), embedded: true),
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
        'screen': ShopsScreen(key: ValueKey('shops_$userId'), embedded: true),
        'icon': Icons.store,
        'label': 'Shops',
        'permission': PermissionIds.customersShops, // customers_shops permission
      });
    }

    // Reports is available to all clients -- in the drawer for Leruma
    if (!isLeruma) {
      configs.add({
        'screen': ReportsScreen(key: ValueKey('reports_$userId')),
        'icon': Icons.assessment,
        'label': 'Reports',
        'permission': PermissionIds.reports, // module: reports
      });
    }

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

  /// The sign-in screen's brand gradient, laid left to right for the thin top
  /// and bottom bars so the two read as one strip of colour. Null for clients
  /// without a brand gradient, which keep their flat bars.
  LinearGradient? get _brandBarGradient {
    final colors = BrandBackdrop.gradientFor(ApiService.currentClient);
    if (colors == null) return null;
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: colors,
    );
  }

  /// Build flat AppBar
  Widget _buildCurvedAppBar(bool isDark, ThemeProvider themeProvider) {
    final gradient = _brandBarGradient;
    final appBarColor = isDark ? AppColors.darkSurface : AppColors.brandPrimary;

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? appBarColor : null,
        gradient: gradient,
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
              // Logo + Title. Leruma shows the active stock location here and
              // makes it the store switcher (design_handoff_sale_screen); the
              // client name is redundant on a single-client build.
              Expanded(
                child: ApiService.currentClient?.id == 'leruma'
                    ? _buildStoreSwitcher()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (ApiService.currentClient?.logoUrl != null)
                            // Same traced white outline as the sign-in logo, at
                            // a hairline weight so it stays crisp at 32px.
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: OutlinedLogo(
                                client: ApiService.currentClient,
                                height: 32,
                                stroke: 1,
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
              // Notifications. Sits in the app bar rather than the drawer
              // because its whole value is being seen without being looked
              // for -- a discount approval is only useful while the seller is
              // still standing in the shop.
              Consumer<NotificationProvider>(
                builder: (context, notifications, _) {
                  final count = notifications.badgeCount;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none,
                            color: Colors.white, size: 26),
                        tooltip: 'Notifications',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationsScreen()),
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          top: 8,
                          right: 6,
                          // Gradient ring when the client has one; the badge's
                          // own border (bar colour) is only the fallback.
                          child: BrandBadgeFrame(
                            radius: 9,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              constraints: const BoxConstraints(minWidth: 17),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(9),
                                border: gradient == null
                                    ? Border.all(color: appBarColor, width: 1.5)
                                    : null,
                              ),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
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

  /// Store name in the app bar, tappable to switch when the seller has more
  /// than one allowed location.
  ///
  /// A seller with a single granted store gets a plain label -- there is nothing
  /// to switch to, and a chevron would imply otherwise.
  /// What to show when not one screen survived the permission filter.
  ///
  /// This used to read "No access to any screens" -- true, unhelpful, and
  /// wrong most of the time it appeared. A seller who installs the app and
  /// signs in with no network has no cached permissions and no cached
  /// locations, because both are written by a SUCCESSFUL ONLINE sign-in. The
  /// screen list comes out empty and the drawer with it, and the app looks
  /// broken rather than un-primed.
  ///
  /// Two genuinely different situations, so two different messages.
  Widget _buildNoScreensState(bool isDark) {
    final offline = context.watch<ConnectivityProvider>().isOffline;
    final permissions = context.watch<PermissionProvider>();
    final nothingCached = permissions.permissions.isEmpty;
    final firstRunOffline = offline && nothingCached;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              firstRunOffline ? Icons.cloud_off : Icons.lock_outline,
              size: 56,
              color: AppColors.muted(context),
            ),
            const SizedBox(height: 16),
            Text(
              firstRunOffline
                  ? 'Connect once to set up this device'
                  : 'No screens are available to you',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              firstRunOffline
                  ? 'Your permissions and stock locations are downloaded the '
                      'first time you sign in with a connection. Until that has '
                      'happened once, there is nothing saved on this phone to '
                      'work from offline.'
                  : 'Your account has no permission for any part of the app. '
                      'Ask an administrator to grant you access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.muted(context)),
            ),
            if (firstRunOffline) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final permissionProvider = context.read<PermissionProvider>();
                  final locationProvider = context.read<LocationProvider>();
                  await permissionProvider.fetchPermissions();
                  await locationProvider.initialize();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStoreSwitcher() {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        final selected = locationProvider.selectedLocation;
        final canSwitch = locationProvider.hasMultipleLocations;

        if (selected == null) {
          // The client's own name, not the generic app name. A Leruma seller
          // seeing "POS Tanzania" above an empty screen has no idea whether
          // they opened the wrong app.
          return Center(
            child: Text(
              ApiService.currentClient?.displayName ?? AppConstants.appName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          );
        }

        final label = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                selected.locationName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            if (canSwitch)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: Colors.white70),
              ),
          ],
        );

        if (!canSwitch) return Center(child: label);

        return Center(
          child: PopupMenuButton<StockLocation>(
            offset: const Offset(0, 40),
            color: Colors.white,
            tooltip: 'Switch store',
            onSelected: (location) => locationProvider.selectLocation(location),
            itemBuilder: (context) => locationProvider.allowedLocations
                .map(
                  (location) => PopupMenuItem<StockLocation>(
                    value: location,
                    child: Row(
                      children: [
                        Icon(
                          location.locationId == selected.locationId
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: location.locationId == selected.locationId
                              ? AppColors.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            location.locationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            child: label,
          ),
        );
      },
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
                color: isDark ? AppColors.darkText : AppColors.brandPrimary,
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
        color: isDark ? AppColors.darkText : AppColors.brandPrimary,
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
      // A module shows only when the employee holds the module grant itself,
      // as on the web; holding one of its sub-permissions is not enough. The
      // dashboard is the exception: every signed-in user lands on it.
      final hasPermission = permission == PermissionIds.home ||
          permissionProvider.hasPermission(permission);

      if (hasPermission) {
        indexMapping[availableScreens.length] = i;
        availableScreens.add(config);
      }
    }

    // Adjust selected index if current selection is not available
    if (_selectedIndex >= availableScreens.length) {
      _selectedIndex = 0;
    }

    _lastAvailableScreens = availableScreens;

    return Scaffold(
      extendBody: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _buildCurvedAppBar(isDark, themeProvider),
      ),
      drawer: Drawer(
        // The profile header sits outside the scrolling list so it stays put
        // while the menu moves underneath it.
        child: Column(
          children: [
              DrawerHeader(
                // The sign-in screen's gradient, drawn diagonally as it is
                // there (this is a block, not a thin strip like the bars).
                decoration: () {
                  final brand =
                      BrandBackdrop.gradientFor(ApiService.currentClient);
                  if (brand != null) return BrandBackdrop.decorationFor(brand);
                  return BoxDecoration(
                    color:
                        isDark ? AppColors.darkSurface : AppColors.brandPrimary,
                  );
                }(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Update, settings and sign-out live up here rather than as
                    // three more rows at the bottom of a menu the seller already
                    // has to scroll. They are things you do TO the app, not with
                    // it, and they belong beside the account they apply to.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile picture (Leruma feature) or default icon
                        _buildDrawerAvatar(user, isDark),
                        const Spacer(),
                        Consumer<UpdateProvider>(
                          builder: (context, updates, _) => _DrawerHeaderAction(
                            icon: Icons.system_update,
                            tooltip: updates.updateAvailable
                                ? 'Update available'
                                : 'App update',
                            // The dot is the only nagging that survives "Later".
                            // It is passive, it blocks nothing, and it is how the
                            // user knows the update did not simply vanish.
                            showDot: updates.updateAvailable,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AppUpdateScreen()),
                              );
                            },
                          ),
                        ),
                        _DrawerHeaderAction(
                          icon: Icons.settings,
                          tooltip: 'Settings',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            );
                          },
                        ),
                        _DrawerHeaderAction(
                          icon: Icons.logout,
                          tooltip: 'Log out',
                          onTap: () => _confirmLogout(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user?.displayName ?? 'User',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? AppColors.darkText : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // The installed version comes along with the update button,
                    // so the number stays visible without costing a row.
                    Consumer<UpdateProvider>(
                      builder: (context, updates, _) => Text(
                        updates.updateAvailable
                            ? 'Version ${updates.installedLabel} · update available'
                            : 'Version ${updates.installedLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextLight : Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  // Edge-to-edge on Android 15+: without the bottom inset the last
                  // menu entries scroll to rest underneath the system navigation bar
                  // and cannot be tapped.
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                  children: [
            // 1. Customers Menu
            // Requests and approvals lead the section: raising a discount
            // request happens mid-sale, and an approval waiting on you is the
            // most time-sensitive thing in this menu.
            // Either side of this screen is worth reaching on its own: the
            // inbox needs approvals_view, "my requests" needs only the
            // discount or credit-limit view grant. Gating on the discount
            // grant alone would hide the queue from a credit-limit-only
            // approver, who could then reach it solely by tapping a
            // notification.
            // One entry, not three. The screen's own button raises a request --
            // and asks which kind when the user can raise both -- so separate
            // "Request a Discount" and "Request Extra Credit" rows just said
            // the same thing twice.
            //
            // The create grants are listed too so that anyone who can raise a
            // request can always reach the screen, even if the view grants are
            // changed later.
            PermissionWrapper(
              anyPermissions: const [
                PermissionIds.approvalsView,
                PermissionIds.oneTimeDiscountsView,
                PermissionIds.oneTimeDiscountsAdd,
                PermissionIds.customerCreditLimitsView,
                PermissionIds.customerCreditLimitsAdd,
              ],
              child: Consumer<NotificationProvider>(
                builder: (context, notifications, _) => ListTile(
                  leading: BrandIconTile(Icons.approval, fallbackColor: AppColors.brandPrimary),
                  title: const Text('Discount & Approvals'),
                  trailing: notifications.pendingApprovals > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${notifications.pendingApprovals}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ApprovalsScreen()),
                    );
                  },
                ),
              ),
            ),
            // "Request a Discount" is deliberately NOT here: the approvals
            // screen's own button already raises one. This one stays, because
            // it is the only place the credit limit module is named.
            //
            // It opens the LIST, not the create form. Opening the form
            // directly meant the only thing the app could do with this module
            // was add to it -- no way to see what had been asked for, what was
            // granted, or who is holding an unspent allowance. Creating is now
            // the list's own action, as it is on the web.
            //
            // Gated on _view, not _add: reading the module is the common case
            // (nine people hold _view, two hold _add), and the list's button
            // handles whether this user may raise one.
            PermissionWrapper(
              anyPermissions: const [
                PermissionIds.customerCreditLimitsView,
                PermissionIds.customerCreditLimitsAdd,
              ],
              child: ListTile(
                leading: BrandIconTile(Icons.request_quote_outlined, fallbackColor: AppColors.brandPrimary),
                title: const Text('Credit Limit & Approvals'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreditLimitsScreen()),
                  );
                },
              ),
            ),
            PermissionWrapper(
              anyPermissions: const [
                PermissionIds.customers,
                PermissionIds.credits,
                PermissionIds.customersShops,
                PermissionIds.customerDiscountRequests,
              ],
              child: ExpansionTile(
              leading: BrandIconTile(Icons.people, fallbackColor: AppColors.brandPrimary),
              title: const Text('Customers'),
              childrenPadding: const EdgeInsets.only(left: 16),
              children: [
                // Customers List
                PermissionWrapper(
                  permissionId: PermissionIds.customers,
                  child: ListTile(
                    leading: BrandIconTile(Icons.people_outline, fallbackColor: AppColors.brandPrimary),
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
                    leading: const BrandIconTile(Icons.credit_card, fallbackColor: AppColors.error),
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
                      leading: BrandIconTile(Icons.store, fallbackColor: AppColors.brandPrimary),
                      title: const Text('Shops'),
                      onTap: () {
                        Navigator.pop(context);
                        _openTab('Shops', () => const ShopsScreen());
                      },
                    ),
                  ),
              ],
            ),
            ),
            // Discount Requests (SADA only)
            if (ApiService.currentClient?.features.hasDiscountRequests ?? false)
              PermissionWrapper(
                permissionId: PermissionIds.customerDiscountRequests,
                child: ListTile(
                  leading: BrandIconTile(Icons.discount, fallbackColor: AppColors.brandPrimary),
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
            // Group titles removed: four labelled rows of furniture in a
            // menu that already needs scrolling. A hairline keeps the
            // grouping legible for a pixel instead of forty.
            const Divider(height: 9, thickness: 0.6, indent: 16, endIndent: 16),
            PermissionWrapper(
              permissionId: PermissionIds.items,
              child: ListTile(
                leading: BrandIconTile(Icons.inventory_2, fallbackColor: AppColors.brandPrimary),
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
            PermissionWrapper(
              anyPermissions: const [
                PermissionIds.sales,
                PermissionIds.salesSuspended,
              ],
              child: ExpansionTile(
              leading: BrandIconTile(Icons.point_of_sale, fallbackColor: AppColors.brandPrimary),
              title: const Text('Sales'),
              childrenPadding: const EdgeInsets.only(left: 16),
              children: [
                // New Sales
                PermissionWrapper(
                  permissionId: PermissionIds.sales,
                  child: ListTile(
                    leading: BrandIconTile(Icons.add_shopping_cart, fallbackColor: AppColors.brandPrimary),
                    title: const Text('New Sales'),
                    onTap: () {
                      Navigator.pop(context);
                      // _openSales, not a tab lookup. Leruma has no Sales tab
                      // any more -- Payment Summary took the slot -- so
                      // indexWhere returned -1 and this entry silently did
                      // nothing at all. The shared helper switches to the tab
                      // where there is one and pushes the till where there is
                      // not, so it works for every client.
                      _openSales();
                    },
                  ),
                ),
                // Sales History
                PermissionWrapper(
                  permissionId: PermissionIds.sales,
                  child: ListTile(
                    leading: BrandIconTile(Icons.history, fallbackColor: AppColors.brandPrimary),
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
                    leading: const BrandIconTile(Icons.pause_circle, fallbackColor: AppColors.warning),
                    title: const Text('Suspended Sales'),
                    onTap: () async {
                      Navigator.pop(context);
                      // Resuming loads the cart, so landing back on whatever
                      // tab the drawer was opened from (usually Home) reads as
                      // "nothing happened". A true result means a sale was
                      // resumed -- jump to the Sales tab where the cart is.
                      final resumed = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SuspendedSalesScreen()),
                      );
                      if (resumed == true) _openSales();
                    },
                  ),
                ),
              ],
            ),
            ),
            // 4. Suppliers Menu
            PermissionWrapper(
              anyPermissions: const [
                PermissionIds.suppliers,
                PermissionIds.suppliersCreditors,
              ],
              child: ExpansionTile(
              leading: BrandIconTile(Icons.local_shipping, fallbackColor: AppColors.brandPrimary),
              title: const Text('Suppliers'),
              childrenPadding: const EdgeInsets.only(left: 16),
              children: [
                // Suppliers List
                PermissionWrapper(
                  permissionId: PermissionIds.suppliers,
                  child: ListTile(
                    leading: BrandIconTile(Icons.local_shipping_outlined, fallbackColor: AppColors.brandPrimary),
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
                // Supplier Credits. The web lists it under the
                // suppliers_creditors module, and its pages open only with
                // the credits module too (Suppliers_creditors is built on
                // 'credits'); showing it without either is a dead end.
                PermissionWrapper(
                  allPermissions: const [
                    PermissionIds.suppliersCreditors,
                    PermissionIds.credits,
                  ],
                  child: ListTile(
                    leading: const BrandIconTile(Icons.credit_card, fallbackColor: AppColors.error),
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
            ),
            // 4. Receivings - requires receivings permission
            PermissionWrapper(
              permissionId: PermissionIds.receivings,
              child: ListTile(
                leading: BrandIconTile(Icons.inventory, fallbackColor: AppColors.brandPrimary),
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
            // Group titles removed: four labelled rows of furniture in a
            // menu that already needs scrolling. A hairline keeps the
            // grouping legible for a pixel instead of forty.
            const Divider(height: 9, thickness: 0.6, indent: 16, endIndent: 16),
            if (ApiService.currentClient?.id != 'leruma')
              PermissionWrapper(
                permissionId: PermissionIds.cashSubmit,
                child: ListTile(
                  leading: BrandIconTile(Icons.attach_money, fallbackColor: AppColors.brandPrimary),
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
            //
            // Keyed on its own flag, not on the absence of Financial Banking.
            // That inverse was a proxy for "Leruma uses the other one", and it
            // broke the moment Financial Banking was switched off for Leruma:
            // hiding one entry silently un-hid the other.
            if (ApiService.currentClient?.features.hasBanking ?? true)
              PermissionWrapper(
                permissionId: PermissionIds.cashSubmitBanking,
                child: ListTile(
                  leading: BrandIconTile(Icons.account_balance, fallbackColor: AppColors.brandPrimary),
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
                  leading: BrandIconTile(Icons.analytics, fallbackColor: AppColors.brandPrimary),
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
            // 6.6 Borrowed Money - SADA only
            if (ApiService.currentClient?.features.hasBorrowedMoney ?? false)
              PermissionWrapper(
                permissionId: PermissionIds.borrowedMoney,
                child: ListTile(
                  leading: BrandIconTile(Icons.account_balance_wallet, fallbackColor: AppColors.brandPrimary),
                  title: const Text('Borrowed Money'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BorrowedMoneyListScreen()),
                    );
                  },
                ),
              ),
            // 7. TRADE (TRA) - requires tra permission
            if (ApiService.currentClient?.features.hasTRA ?? false)
              PermissionWrapper(
                permissionId: PermissionIds.tra,
                child: ListTile(
                  leading: BrandIconTile(Icons.receipt_long, fallbackColor: AppColors.brandPrimary),
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
              PermissionWrapper(
                anyPermissions: const [
                  PermissionIds.nfcCardsView,
                  PermissionIds.nfcConfirmationsView,
                ],
                child: ExpansionTile(
                leading: BrandIconTile(Icons.nfc, fallbackColor: AppColors.brandPrimary),
                title: const Text('NFC'),
                childrenPadding: const EdgeInsets.only(left: 16),
                children: [
                  // NFC Cards
                  PermissionWrapper(
                    permissionId: PermissionIds.nfcCardsView,
                    child: ListTile(
                      leading: BrandIconTile(Icons.credit_card, fallbackColor: AppColors.brandPrimary),
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
                      leading: BrandIconTile(Icons.verified, fallbackColor: AppColors.brandPrimary),
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
                      leading: BrandIconTile(Icons.contactless, fallbackColor: AppColors.brandPrimary),
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
              ),
            // Group titles removed: four labelled rows of furniture in a
            // menu that already needs scrolling. A hairline keeps the
            // grouping legible for a pixel instead of forty.
            const Divider(height: 9, thickness: 0.6, indent: 16, endIndent: 16),
            // Payment Summary sits with Seller Report, not under Sales: it is
            // a reconciliation view (what came in, by type, per route stop),
            // not an action a seller takes while selling.
            // Leruma has this in the bottom bar now, so showing it here too
            // would be the same screen twice in one menu.
            if (ApiService.currentClient?.id != 'leruma')
            PermissionWrapper(
              permissionId: PermissionIds.salesPaymentSummary,
              child: ListTile(
                leading: BrandIconTile(Icons.payments, fallbackColor: AppColors.brandPrimary),
                title: const Text('Payment Summary'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PaymentSummaryScreen()),
                  );
                },
              ),
            ),
            // Reports and Summary live here for Leruma -- they were moved out of
            // the bottom bar to make room for Customer Credits.
            if (ApiService.currentClient?.id == 'leruma') ...[
              PermissionWrapper(
                permissionId: PermissionIds.reports,
                child: ListTile(
                  leading: BrandIconTile(Icons.assessment, fallbackColor: AppColors.brandPrimary),
                  title: const Text('Reports'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsScreen()),
                    );
                  },
                ),
              ),
              PermissionWrapper(
                permissionId: PermissionIds.cashSubmit,
                child: ListTile(
                  leading: BrandIconTile(Icons.summarize, fallbackColor: AppColors.brandPrimary),
                  title: const Text('Summary'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TodaySummaryScreen()),
                    );
                  },
                ),
              ),
            ],
            // 10. Financial Position - requires office permission (hidden for Leruma)
            if (ApiService.currentClient?.id != 'leruma')
              PermissionWrapper(
                permissionId: PermissionIds.office,
                child: ListTile(
                  leading: BrandIconTile(Icons.analytics, fallbackColor: AppColors.brandPrimary),
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
                leading: BrandIconTile(Icons.description, fallbackColor: AppColors.brandPrimary),
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
                leading: BrandIconTile(Icons.trending_up, fallbackColor: AppColors.brandPrimary),
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
            // Transactions - requires transactions permission
            PermissionWrapper(
              permissionId: PermissionIds.transactions,
              child: ListTile(
                leading: BrandIconTile(Icons.swap_horiz, fallbackColor: AppColors.brandPrimary),
                title: const Text('Transactions'),
                onTap: () {
                  Navigator.pop(context);
                  _openTab('Transactions', () => const TransactionsScreen());
                },
              ),
            ),
            // Contracts - requires contracts permission
            PermissionWrapper(
              permissionId: PermissionIds.contracts,
              child: ListTile(
                leading: BrandIconTile(Icons.assignment, fallbackColor: AppColors.brandPrimary),
                title: const Text('Contracts'),
                onTap: () {
                  Navigator.pop(context);
                  _openTab('Contracts', () => const ContractsScreen());
                },
              ),
            ),
                  ],
                ),
              ),
          ],
        ),
      ),
      // The connection strip sits above whichever screen is selected rather
      // than inside each one, so a seller cannot navigate away from the news
      // that sales are queued. It collapses to nothing when there is nothing
      // to say, and the bottom navigation is untouched.
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: availableScreens.isNotEmpty
                ? availableScreens[_selectedIndex]['screen'] as Widget
                : _buildNoScreensState(isDark),
          ),
        ],
      ),
      bottomNavigationBar: availableScreens.length > 1
          ? (ApiService.currentClient?.id == 'leruma'
              // Leruma uses the flat bar from design_handoff_home_credit 1.7.
              // The curved bar with the notched Sales FAB stays for every other
              // client -- it is their shipped navigation, not a shared style.
              ? _buildLerumaBottomNav(availableScreens)
              // Android 15+ draws edge to edge for targetSdk 36, so the system
              // navigation bar overlays the app. The bar's own SafeArea sees no
              // inset by the time it is laid out as the Scaffold's bottom bar,
              // which slid it underneath. Apply the inset here, from the
              // context that still has it, and keep the inner SafeArea from
              // adding it a second time.
              // With a brand gradient the curved painter draws its own fill, so
              // this wrapper is only the gradient behind the inset strip.
              : DecoratedBox(
                  decoration: _brandBarGradient != null
                      ? BoxDecoration(gradient: _brandBarGradient)
                      : BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                        ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom,
                    ),
                    child: MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      child: _buildCurvedBottomNav(availableScreens, isDark),
                    ),
                  ),
                ))
          : null,
    );
  }

  /// Flat bottom navigation (design_handoff_home_credit 1.7).
  ///
  /// White, hairline top border, equal columns, no notch and no rotation --
  /// the curved bar moved the active item to the centre on every tap, so the
  /// labels never sat still long enough to be learned.
  ///
  /// The design lists Seller / Home / Sales / Customers / Reports. Credits and
  /// Expenses stand in for the last two here because Reports was moved to the
  /// drawer on request and Credits was moved into the bar; only the order below
  /// needs changing if that decision is revisited.
  Widget _buildLerumaBottomNav(List<Map<String, dynamic>> screens) {
    // Home first, then the held baskets a seller reaches for between
    // customers, then the till. Expenses is unnamed by the design and keeps
    // its position at the end.
    const order = ['Home', 'Suspended', 'Payment', 'Credits', 'Seller', 'Expenses'];

    final ordered = [...screens.asMap().entries]
      ..sort((a, b) {
        // Anything the design does not name keeps its original position at the
        // end rather than being dropped -- a permission-gated screen with no
        // tab is unreachable.
        int rank(MapEntry<int, Map<String, dynamic>> e) {
          final i = order.indexOf(e.value['label'] as String);
          return i == -1 ? order.length + e.key : i;
        }

        return rank(a).compareTo(rank(b));
      });

    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: dark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFEEF1F5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 7, bottom: 6),
          child: Row(
            children: ordered.map((entry) {
              final active = entry.key == _selectedIndex;
              final color = active
                  ? (dark ? const Color(0xFF6FA8DC) : const Color(0xFF1668A6))
                  : (dark ? AppColors.darkTextLight : const Color(0xFF64748B));

              return Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(entry.key),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(entry.value['icon'] as IconData,
                          size: 20, color: color),
                      const SizedBox(height: 4),
                      Text(
                        entry.value['label'] as String,
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

    final gradient = _brandBarGradient;

    // If no Sales screen, fall back to standard navigation
    if (salesIndex == -1) {
      return BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: gradient != null ? Colors.transparent : null,
        elevation: gradient != null ? 0 : null,
        selectedItemColor: gradient != null ? Colors.white : AppColors.brandPrimary,
        unselectedItemColor:
            gradient != null ? Colors.white70 : AppColors.textLight,
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
                    borderColor: gradient != null
                        ? Colors.white.withValues(alpha: 0.35)
                        : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    curvePosition: 0.5, // Always center
                    gradient: gradient,
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
                        while (displayPosition < 0) {
                          displayPosition += itemCount;
                        }
                        while (displayPosition >= itemCount) {
                          displayPosition -= itemCount;
                        }

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
    // On the brand gradient the idle items turn white; the selected icon sits
    // in the notch, which shows the page behind it, so it keeps the brand blue.
    final idleColor =
        _brandBarGradient != null ? Colors.white : AppColors.textLight;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Center(
        child: isSelected
            // Selected: icon only, no label, moved up into the curve and
            // ringed in red so the active menu is unmistakable.
            ? Transform.translate(
                offset: const Offset(0, -8),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? AppColors.darkCard : Colors.white,
                    border: Border.all(color: AppColors.error, width: 2.5),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.brandPrimary,
                    size: 28,
                  ),
                ),
              )
            // Unselected: smaller icon with label
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // On the brand gradient each idle icon sits on its own
                  // gradient tile (run the other way so it reads against the
                  // bar) with a hairline white edge.
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: _brandBarGradient == null
                        ? null
                        : BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: BrandBackdrop.gradientFor(
                                  ApiService.currentClient)!,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 1,
                            ),
                          ),
                    child: Icon(
                      icon,
                      color: idleColor,
                      size: _brandBarGradient == null ? 22 : 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: idleColor,
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

  /// When set it replaces [color] as the fill.
  final Gradient? gradient;

  _CurvedNavPainter({
    required this.color,
    required this.borderColor,
    this.curvePosition = 0.5,
    this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    if (gradient != null) {
      paint.shader = gradient!.createShader(Offset.zero & size);
    }

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
           oldDelegate.borderColor != borderColor ||
           oldDelegate.gradient != gradient;
  }
}

/// Section heading in the drawer (design_handoff_home_credit, screen 2).

/// One of the small actions in the drawer header.
///
/// White on the header's own colour rather than the brand blue the list rows
/// use -- these sit ON the header, not under it.
class _DrawerHeaderAction extends StatelessWidget {
  const _DrawerHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// A quiet marker, not a count. Used for "an update is waiting".
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colour = dark ? AppColors.darkText : Colors.white;

    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 21, color: colour),
              if (showDot)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: colour, width: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
