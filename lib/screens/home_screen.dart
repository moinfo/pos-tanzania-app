import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/location_provider.dart';
import '../providers/permission_provider.dart';
import '../models/permission_model.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/glassmorphic_card.dart';
import 'daily_debt_report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  // Dashboard data
  double _totalSales = 0;
  double _expenses = 0;
  double _gainLoss = 0;
  double _profit = 0;
  double _bankDifference = 0;
  double _totalUnpaid = 0;
  // Come & Save specific - sales breakdown
  double _cashSales = 0;
  double _customerCredit = 0;
  double _lipaNamba = 0;

  // Leruma Commission Dashboard data
  Map<String, dynamic>? _commissionData;
  Map<String, dynamic>? _salesSummary;

  // Enhanced Leruma data (new)
  Map<String, dynamic>? _topStats;

  /// Daily debt collection for the last 14 days, oldest first, used by the
  /// credits KPI card (design_handoff_home_credit 1.2).
  ///
  /// The handoff had no data behind its chart or its "vs last week" figure.
  /// Both are derived here from the debt-collection report, which returns
  /// individual payments with dates -- so the bars and the delta are the
  /// seller's actual collections, not sample numbers.
  /// Null until the fetch finishes; an all-zero list is a real answer (a week
  /// with no collections) and must still draw the chart, so emptiness cannot
  /// double as "not loaded".
  List<double>? _dailyCollections;

  /// 1.5 segmented control: false = My commission, true = Team.
  bool _showTeamCommission = false;

  LocationProvider? _locationProvider;
  int? _loadedLocationId;
  Map<String, dynamic>? _progressCommission;
  Map<String, dynamic>? _progressCustomers;
  Map<String, dynamic>? _myCommissions; // User's individual commission data

  // Transactions Dashboard data (Come & Save)
  WakalaReport? _transactionsDashboardData;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locationProvider = context.read<LocationProvider>()
        ..addListener(_onLocationChanged);
      _initializeDashboard();
    });
  }

  @override
  void dispose() {
    _locationProvider?.removeListener(_onLocationChanged);
    super.dispose();
  }

  /// Reloads when the store changes.
  ///
  /// The switcher moved to the app bar, which knows nothing about this screen,
  /// so without this the figures kept describing the previous store while the
  /// title named the new one.
  void _onLocationChanged() {
    final locationId = _locationProvider?.selectedLocation?.locationId;
    if (locationId == _loadedLocationId) return;

    _loadedLocationId = locationId;
    _loadDashboardData();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final themeProvider = context.read<ThemeProvider>();
        final isDark = themeProvider.isDarkMode;

        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppColors.brandPrimary,
                    onPrimary: Colors.white,
                    surface: AppColors.darkSurface,
                    onSurface: AppColors.darkText,
                  )
                : ColorScheme.light(
                    primary: AppColors.brandPrimary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppColors.text,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadDashboardData();
    }
  }

  Future<void> _initializeDashboard() async {
    final currentClient = ApiService.currentClient;
    final hasCommissionDashboard = currentClient?.features.hasCommissionDashboard ?? false;
    final clientId = currentClient?.id ?? 'sada';

    // Initialize location provider for Leruma and Come and Save
    if ((hasCommissionDashboard || clientId == 'come_and_save') && mounted) {
      final authProvider = context.read<AuthProvider>();
      final locationProvider = context.read<LocationProvider>();
      // Pass user's location_id to use as default
      final userLocationId = authProvider.user?.locationId;
      await locationProvider.initialize(
        moduleId: 'sales',
        userLocationId: userLocationId,
      );
    }

    await _loadDashboardData();
  }

  /// Pull-to-refresh: bust the server-side dashboard cache first, so a
  /// deliberate refresh always shows live numbers. Initial loads skip this
  /// and may ride the server's 5-minute cache -- that trade keeps opening
  /// the app fast.
  Future<void> _refreshDashboard() async {
    await _apiService.clearDashboardServerCache();
    await _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentClient = ApiService.currentClient;
      final clientId = currentClient?.id ?? 'sada';

      print('📊 Loading dashboard for client: $clientId');

      // Load dashboard based on client type
      final hasCommissionDashboard = currentClient?.features.hasCommissionDashboard ?? false;

      if (hasCommissionDashboard) {
        await _loadLerumaDashboard();
      } else if (clientId == 'come_and_save') {
        await _loadComeAndSaveDashboard();
      } else {
        await _loadSadaDashboard();
      }
    } catch (e) {
      print('❌ Dashboard error: $e');
      setState(() {
        _error = 'Failed to load dashboard data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Load dashboard for SADA (with contracts and full features)
  Future<void> _loadSadaDashboard() async {
    // Format selected date for API
    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Get summary for selected date
    final summaryResponse = await _apiService.getCashSubmitTodaySummary(
      date: dateString,
    );

    // Get contracts for unpaid calculation
    final hasContracts = ApiService.currentClient?.features.hasContracts ?? false;
    double totalUnpaid = 0;

    if (hasContracts) {
      final contractsResponse = await _apiService.getContracts();
      if (contractsResponse.isSuccess) {
        final contracts = contractsResponse.data ?? [];
        for (var contract in contracts) {
          totalUnpaid += (contract.daysUnpaid * 10000);
        }
      }
    }

    if (summaryResponse.isSuccess) {
      final summaryData = summaryResponse.data;

      setState(() {
        _totalSales = (summaryData?['all_sales'] ?? 0).toDouble();
        _expenses = (summaryData?['expenses'] ?? 0).toDouble();
        _gainLoss = (summaryData?['gain_loss'] ?? 0).toDouble();
        _profit = (summaryData?['profit'] ?? 0).toDouble();

        final bankingAmount = (summaryData?['banking_amount'] ?? 0).toDouble();
        final supplierBank = (summaryData?['supplier_debit_bank'] ?? 0).toDouble();
        _bankDifference = bankingAmount - supplierBank;

        _totalUnpaid = totalUnpaid;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = summaryResponse.message;
        _isLoading = false;
      });
    }
  }

  /// Load dashboard for Come & Save (filtered by selected location)
  Future<void> _loadComeAndSaveDashboard() async {
    // Get selected location from provider
    final locationProvider = context.read<LocationProvider>();
    final permissionProvider = context.read<PermissionProvider>();
    final selectedLocationId = locationProvider.selectedLocation?.locationId;

    // Format selected date for API
    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Check permissions
    final hasTransactionsPermission = permissionProvider.hasPermission(PermissionIds.transactions) ||
        permissionProvider.hasModulePermission(PermissionIds.transactions);
    final hasLocation = selectedLocationId != null;

    print('📍 Come & Save dashboard - location: $selectedLocationId, hasTransactions: $hasTransactionsPermission');

    // If user has neither location nor transactions permission, show error
    if (!hasLocation && !hasTransactionsPermission) {
      setState(() {
        _error = 'Please select a stock location';
        _isLoading = false;
      });
      return;
    }

    // Load Transactions Dashboard if user has transactions permission (no location required)
    if (hasTransactionsPermission) {
      print('📊 User has transactions permission, loading transactions dashboard');
      final transactionsResponse = await _apiService.getWakalaReport(
        startDate: dateString,
        endDate: dateString,
      );

      if (transactionsResponse.isSuccess && transactionsResponse.data != null) {
        _transactionsDashboardData = transactionsResponse.data;
        print('✅ Transactions dashboard data loaded successfully');
      } else {
        print('⚠️ Failed to load transactions dashboard: ${transactionsResponse.message}');
        _transactionsDashboardData = null;
      }
    } else {
      _transactionsDashboardData = null;
    }

    // Load Sales Dashboard only if user has a location
    if (hasLocation) {
      print('📍 Loading sales dashboard for location: $selectedLocationId on $dateString');

      final summaryResponse = await _apiService.getCashSubmitTodaySummary(
        date: dateString,
        locationId: selectedLocationId,
      );

      if (summaryResponse.isSuccess) {
        final summaryData = summaryResponse.data;

        setState(() {
          // Come & Save specific - sales breakdown
          _cashSales = (summaryData?['cash_sales'] ?? 0).toDouble();
          _customerCredit = (summaryData?['customer_credit'] ?? 0).toDouble();
          _lipaNamba = (summaryData?['lipa_namba'] ?? 0).toDouble();

          // Total Sales = Cash + Credit + LIPA NAMBA (all payment types)
          _totalSales = _cashSales + _customerCredit + _lipaNamba;

          _expenses = (summaryData?['expenses'] ?? 0).toDouble();
          _gainLoss = (summaryData?['gain_loss'] ?? 0).toDouble();
          _profit = (summaryData?['profit'] ?? 0).toDouble();

          final bankingAmount = (summaryData?['banking_amount'] ?? 0).toDouble();
          final supplierBank = (summaryData?['supplier_debit_bank'] ?? 0).toDouble();
          _bankDifference = bankingAmount - supplierBank;

          _totalUnpaid = 0; // Come & Save doesn't have contracts
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = summaryResponse.message;
          _isLoading = false;
        });
      }
    } else {
      // No location - just finish loading (transactions dashboard will show if available)
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Load dashboard for Leruma (commission tracking focused)
  Future<void> _loadLerumaDashboard() async {
    // Get selected location from provider
    final locationProvider = context.read<LocationProvider>();
    final selectedLocationId = locationProvider.selectedLocation?.locationId;
    _loadedLocationId = selectedLocationId;

    // Format dates for API
    final startDate = DateFormat('yyyy-MM-dd').format(DateTime(_selectedDate.year, _selectedDate.month, 1));
    final endDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    print('📊 Loading Leruma dashboard: $startDate to $endDate, location: $selectedLocationId');

    // Cache-then-network: paint the last known dashboard for this location
    // instantly (stale is better than a spinner on a slow link), then let the
    // network response overwrite it. Only when nothing is on screen yet --
    // a refresh of visible data must not flash backwards.
    final cacheKey = 'leruma_dashboard_${selectedLocationId ?? 0}';
    if (_commissionData == null && _myCommissions == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        if (cached != null && mounted) {
          _applyLerumaDashboard(
              json.decode(cached) as Map<String, dynamic>, selectedLocationId,
              fromCache: true);
        }
      } catch (_) {}
    }

    // Clear cache when location changes
    ApiService.clearDashboardCache();

    // Get full dashboard data
    final dashboardResponse = await _apiService.getCommissionDashboard(
      startDate: startDate,
      endDate: endDate,
      locationId: selectedLocationId,
    );

    if (dashboardResponse.isSuccess && dashboardResponse.data != null) {
      final data = dashboardResponse.data!;
      _applyLerumaDashboard(data, selectedLocationId);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, json.encode(data));
      } catch (_) {}
    } else if (_commissionData == null && _myCommissions == null) {
      // Only surface the error when the cached paint gave us nothing.
      setState(() {
        _error = dashboardResponse.message ?? 'Failed to load dashboard';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _applyLerumaDashboard(Map<String, dynamic> data, int? selectedLocationId,
      {bool fromCache = false}) {
    setState(() {
      _commissionData = data['commission_progress'] as Map<String, dynamic>?;
      _salesSummary = data['sales_summary'] as Map<String, dynamic>?;
      _topStats = data['top_stats'] as Map<String, dynamic>?;
      _progressCommission = data['progress_commission'] as Map<String, dynamic>?;
      _progressCustomers = data['progress_customers'] as Map<String, dynamic>?;
      _myCommissions = data['my_commissions'] as Map<String, dynamic>?;

      final todaySummary = _salesSummary?['today'] as Map<String, dynamic>?;
      if (todaySummary != null) {
        _totalSales = (todaySummary['total_sales'] ?? 0).toDouble();
        _expenses = (todaySummary['expenses'] ?? 0).toDouble();
        _profit = (todaySummary['profit'] ?? 0).toDouble();
      }

      _isLoading = false;
    });

    if (!fromCache) {
      _loadDailyCollections(selectedLocationId);
    }
  }

  /// Buckets the last 14 days of debt payments into one total per day.
  ///
  /// Deliberately not awaited by the dashboard load: the card renders without
  /// the chart if this is slow or fails, rather than holding up every stat.
  Future<void> _loadDailyCollections(int? locationId) async {
    final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = end.subtract(const Duration(days: 13));
    final format = DateFormat('yyyy-MM-dd');

    // Fall back to every allowed store, matching the debt-collection screen.
    // Passing null would ask the API for the whole company.
    final locationProvider = context.read<LocationProvider>();
    final locationIds = locationId != null
        ? [locationId]
        : locationProvider.allowedLocations.map((l) => l.locationId).toList();

    try {
      final response = await _apiService.getDailyDebtReport(
        startDate: format.format(start),
        endDate: format.format(end),
        locationIds: locationIds.isEmpty ? null : locationIds,
      );

      if (!mounted) return;

      if (!response.isSuccess || response.data == null) {
        print('📊 Daily collections failed: ${response.message}');
        return;
      }

      final totals = List<double>.filled(14, 0);
      for (final debt in response.data!.debts) {
        final date = DateTime.tryParse(debt.date);
        if (date == null) continue;

        final index =
            DateTime(date.year, date.month, date.day).difference(start).inDays;
        if (index >= 0 && index < 14) totals[index] += debt.amount;
      }

      print('📊 Daily collections: ${response.data!.debts.length} payments, '
          'week total ${totals.sublist(7).fold<double>(0, (a, b) => a + b)}');

      setState(() => _dailyCollections = totals);
    } catch (e) {
      // Not awaited by the caller, so an uncaught throw here would vanish
      // silently and leave the card looking like it simply had no data.
      print('📊 Daily collections error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.darkBackground, AppColors.darkSurface]
              : [AppColors.lightBackground, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),

            // Dashboard Title and Date Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.brandPrimary.withOpacity(0.15)
                          : AppColors.brandPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.brandPrimary.withOpacity(isDark ? 0.3 : 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // The store switcher lives in the app bar (StoreSwitcherTitle) for
            // Leruma, so the in-body selector duplicated it -- two controls for
            // one piece of state, one of them scrolling out of view. Kept for
            // Come and Save, which has no switcher in its top bar.
            if (ApiService.currentClient?.id == 'come_and_save')
              Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  // Only show if user has multiple locations
                  if (!locationProvider.hasMultipleLocations) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      GlassmorphicCard(
                        isDark: isDark,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.store,
                              color: isDark ? AppColors.brandPrimary : AppColors.brandPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: locationProvider.selectedLocation?.locationId,
                                  isExpanded: true,
                                  hint: Text(
                                    'Select Location',
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkText : AppColors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                  ),
                                  items: locationProvider.allowedLocations.map((location) {
                                    return DropdownMenuItem<int>(
                                      value: location.locationId,
                                      child: Text(location.locationName),
                                    );
                                  }).toList(),
                                  onChanged: (newLocationId) async {
                                    if (newLocationId != null) {
                                      final newLocation = locationProvider.allowedLocations
                                          .firstWhere((loc) => loc.locationId == newLocationId);
                                      await locationProvider.selectLocation(newLocation);
                                      // Reload dashboard with new location
                                      await _loadDashboardData();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

            // Dashboard Content
            if (_isLoading)
              // Show skeleton placeholders while loading
              _buildDashboardSkeleton(isDark)
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (ApiService.currentClient?.features.hasCommissionDashboard ?? false)
              // Leruma Commission Dashboard
              _buildLerumaDashboard(isDark)
            else
              // Come & Save / SADA Dashboard
              Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  final hasLocation = locationProvider.selectedLocation != null;

                  return Column(
                    children: [
                      // Sales Dashboard (only show if user has a location)
                      if (hasLocation) ...[
                        // Row 1: Total Sales & Expenses
                        Row(
                          children: [
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Total Sales',
                                amount: _totalSales,
                                icon: Icons.shopping_cart,
                                color: AppColors.success,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Expenses',
                                amount: _expenses,
                                icon: Icons.money_off,
                                color: AppColors.error,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // SADA: Show Profit & Gain/Loss in Row 2, then Bank Difference & Contract Unpaid
                        if (ApiService.currentClient?.features.hasContracts ?? false) ...[
                          // Row 2: Profit & Gain/Loss
                          Row(
                            children: [
                              Expanded(
                                child: _buildDashboardCard(
                                  title: 'Profit',
                                  amount: _profit,
                                  icon: Icons.trending_up,
                                  color: AppColors.brandPrimary,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDashboardCard(
                                  title: 'Gain/Loss',
                                  amount: _gainLoss,
                                  icon: _gainLoss >= 0
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: _gainLoss >= 0
                                      ? AppColors.success
                                      : AppColors.error,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Row 3: Bank Difference & Contract Unpaid
                          Row(
                            children: [
                              Expanded(
                                child: _buildDashboardCard(
                                  title: 'Bank Difference',
                                  amount: _bankDifference,
                                  icon: Icons.account_balance,
                                  color: AppColors.info,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDashboardCard(
                                  title: 'Contract Unpaid',
                                  amount: _totalUnpaid,
                                  icon: Icons.assignment_late,
                                  color: AppColors.warning,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Come & Save: Show Sales Breakdown first, then Profit, then Gain/Loss alone
                          // Row 2: Cash Sales & Credit Sales
                          Row(
                            children: [
                              Expanded(
                                child: _buildDashboardCard(
                                  title: 'Cash Sales',
                                  amount: _cashSales,
                                  icon: Icons.money,
                                  color: AppColors.success,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDashboardCard(
                                  title: 'Credit Sales',
                                  amount: _customerCredit,
                                  icon: Icons.credit_card,
                                  color: AppColors.warning,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Row 3: LIPA NAMBA & Profit
                          Row(
                            children: [
                              Expanded(
                                child: _buildDashboardCard(
                                  title: 'LIPA NAMBA',
                                  amount: _lipaNamba,
                                  icon: Icons.phone_android,
                                  color: AppColors.info,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDashboardCard(
                                  title: 'Profit',
                                  amount: _profit,
                                  icon: Icons.trending_up,
                                  color: AppColors.brandPrimary,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Row 4: Gain/Loss (centered alone)
                          Center(
                            child: SizedBox(
                              width: (MediaQuery.of(context).size.width - 44) / 2,
                              child: _buildDashboardCard(
                                title: 'Gain/Loss',
                                amount: _gainLoss,
                                icon: _gainLoss >= 0
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: _gainLoss >= 0
                                    ? AppColors.success
                                    : AppColors.error,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ],
                      ],

                      // Transactions Dashboard (Come & Save - only if user has transactions permission)
                      // Shows regardless of location
                      if (_transactionsDashboardData != null) ...[
                        if (hasLocation) const SizedBox(height: 24),
                        _buildTransactionsDashboard(isDark),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
      ),
    );
  }

  /// Build Transactions Dashboard for Come & Save
  Widget _buildTransactionsDashboard(bool isDark) {
    final data = _transactionsDashboardData!;

    // Calculate totals
    final totalFloat = data.sims.total + data.bankBasis.total;
    final totalFloatPlusCashBasis = totalFloat + data.cashBasis.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          'Transactions Dashboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.text,
          ),
        ),
        const SizedBox(height: 16),

        // Row 1: Opening & Total SIMs
        Row(
          children: [
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Opening',
                amount: data.openingBalance,
                icon: Icons.account_balance_wallet,
                color: AppColors.info,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Total SIMs',
                amount: data.sims.total,
                icon: Icons.sim_card,
                color: AppColors.brandPrimary,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Bank Basis & Float
        Row(
          children: [
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Bank Basis',
                amount: data.bankBasis.total,
                icon: Icons.account_balance,
                color: const Color(0xFF2563EB),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Float',
                amount: totalFloat,
                icon: Icons.trending_up,
                color: const Color(0xFF10B981),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 3: Cash Basis & Total (Float + Cash Basis)
        Row(
          children: [
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Cash Basis',
                amount: data.cashBasis.total,
                icon: Icons.payments,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Float + Cash',
                amount: totalFloatPlusCashBasis,
                icon: Icons.calculate,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 4: Total Deposited & Total Net
        Row(
          children: [
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Total Deposited',
                amount: data.totalDeposited,
                icon: Icons.arrow_downward,
                color: AppColors.success,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Total Net',
                amount: data.netTotal,
                icon: Icons.summarize,
                color: const Color(0xFF06B6D4),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 5: Total Withdrawn & Capital Calculated
        Row(
          children: [
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Total Withdrawn',
                amount: data.totalWithdrawn,
                icon: Icons.arrow_upward,
                color: AppColors.error,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Capital Calc.',
                amount: data.calculatedCapital,
                icon: Icons.functions,
                color: const Color(0xFF7C3AED),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 6: Actual Capital & Wakala Expenses
        Row(
          children: [
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Actual Capital',
                amount: data.actualCapital,
                icon: Icons.account_box,
                color: const Color(0xFF0EA5E9),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTransactionStatCard(
                title: 'Wakala Exp.',
                amount: data.wakalaExpenses.total,
                icon: Icons.receipt_long,
                color: const Color(0xFFEF4444),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build individual stat card for Transactions Dashboard
  Widget _buildTransactionStatCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return GlassmorphicCard(
      isDark: isDark,
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(isDark ? 0.3 : 0.2),
                  color.withOpacity(isDark ? 0.2 : 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: color.withOpacity(isDark ? 0.4 : 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark ? color.withOpacity(0.9) : color,
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Amount
          Text(
            Formatters.formatCurrency(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return GlassmorphicCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container with gradient
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.8),
                  color,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Amount
          Text(
            Formatters.formatCurrency(amount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build Leruma Commission Dashboard
  Widget _buildLerumaDashboard(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------------------------------------------------------
        // Parked on request -- kept in the tree to be brought back later.
        // Uncomment the block below to restore; the builders it calls
        // (_buildCreditsKpiCard, _buildStatCard, _buildProgressCard) are
        // all still live further down this file.
        // ---------------------------------------------------------------
        // // Primary KPI card (design_handoff_home_credit 1.2).
        // if (_topStats != null) ...[
        // _buildCreditsKpiCard(),
        // const SizedBox(height: 12),
        // ],
        //
        // // Stat grid (design_handoff_home_credit 1.4). White cards with tinted
        // // icon squares replace the four saturated tiles: red is reserved for
        // // real problems, and "Shops served" is not one.
        // if (_topStats != null) ...[
        // Row(
        // children: [
        // Expanded(child: _buildStatCard(
        // value: '${_topStats!['total_customers'] ?? 0}',
        // label: 'Total customers',
        // icon: Icons.people_outline,
        // fg: const Color(0xFF1D7DC4), bg: const Color(0xFFEAF3FB),
        // )),
        // const SizedBox(width: 10),
        // Expanded(child: _buildStatCard(
        // value: '${_topStats!['total_shop_serves'] ?? 0}',
        // label: 'Shops served',
        // icon: Icons.storefront_outlined,
        // fg: const Color(0xFF7A57C9), bg: const Color(0xFFF0EBFA),
        // )),
        // ],
        // ),
        // const SizedBox(height: 10),
        // Row(
        // children: [
        // Expanded(child: _buildStatCard(
        // value: '${_progressCustomers?['served'] ?? 0}',
        // label: 'Served today',
        // icon: Icons.shopping_cart_outlined,
        // fg: const Color(0xFF16A34A), bg: const Color(0xFFE7F6EE),
        // )),
        // const SizedBox(width: 10),
        // Expanded(child: _buildStatCard(
        // value: '${_topStats!['total_disciplinary'] ?? 0}',
        // label: 'Disciplinary cases',
        // icon: Icons.shield_outlined,
        // fg: const Color(0xFF5A6577), bg: const Color(0xFFEEF1F5),
        // // The only chip the handoff marks as real: everything else
        // // ("+4", "98%", "+0.8%") is sample data it says not to ship.
        // chip: (_topStats!['total_disciplinary'] ?? 0) == 0 ? 'Clean' : null,
        // chipFg: const Color(0xFF4A5462), chipBg: const Color(0xFFEEF1F5),
        // )),
        // ],
        // ),
        // const SizedBox(height: 20),
        // ],

        // ---------------------------------------------------------------
        // Parked on request -- kept in the tree to be brought back later.
        // Uncomment the block below to restore; the builders it calls
        // (_buildCreditsKpiCard, _buildStatCard, _buildProgressCard) are
        // all still live further down this file.
        // ---------------------------------------------------------------
        // // Progress Commission & Progress Customers
        // if (_progressCommission != null || _progressCustomers != null) ...[
        // Row(
        // children: [
        // if (_progressCommission != null)
        // Expanded(
        // child: _buildProgressCard(
        // title: _progressCommission!['user_name'] != null && _progressCommission!['user_name'].toString().isNotEmpty
        // ? 'Progress Commission'
        // : 'Progress Commission',
        // icon: Icons.shopping_cart,
        // current: (_progressCommission!['average'] ?? 0).toDouble(),
        // target: (_progressCommission!['target'] ?? 0).toDouble(),
        // percentage: (_progressCommission!['percentage'] ?? 0).toDouble(),
        // isDark: isDark,
        // ),
        // ),
        // if (_progressCommission != null && _progressCustomers != null)
        // const SizedBox(width: 12),
        // if (_progressCustomers != null)
        // Expanded(
        // child: _buildProgressCard(
        // title: 'Customers Served',
        // icon: Icons.people,
        // current: (_progressCustomers!['served'] ?? 0).toDouble(),
        // target: (_progressCustomers!['total'] ?? 0).toDouble(),
        // percentage: (_progressCustomers!['percentage'] ?? 0).toDouble(),
        // isDark: isDark,
        // isCount: true,
        // ),
        // ),
        // ],
        // ),
        // const SizedBox(height: 24),
        // ],

        // Commissions (design_handoff_home_credit 1.5) -- the segmented control
        // replaces the two stacked sections ("<name> Commissions" and "Team
        // Commission"), which showed six near-identical cards at once.
        _buildCommissionsSection(),

        const SizedBox(height: 14),

        // 1.6 Discipline banner.
        _buildDisciplineBanner(),

        const SizedBox(height: 24),

      ],
    );
  }

  /// Build Top Stat Card (colorful cards like web dashboard)
  /// Stat card for the dashboard grid (design_handoff_home_credit 1.4).
  // ---------------------------------------------------------------------------
  // Dark-mode surfaces for the redesigned dashboard.
  //
  // The handoff specifies one light palette. Rather than hardcode white and
  // #103863 everywhere, the new cards read these, so the design colours stay
  // in one place and dark mode is not a second copy of every widget.
  //
  // build() watches ThemeProvider, so a read here still rebuilds on toggle.
  // ---------------------------------------------------------------------------

  bool get _dark => context.read<ThemeProvider>().isDarkMode;

  /// Card surface (design white).
  Color get _cardBg => _dark ? AppColors.darkCard : Colors.white;

  /// Headline / figure text (design #103863).
  Color get _inkStrong => _dark ? AppColors.darkText : const Color(0xFF103863);

  /// Secondary label text (design #5C6675 / #64748B / #6B7684).
  Color get _inkMuted => _dark ? AppColors.darkTextLight : const Color(0xFF5C6675);

  /// Inset blocks inside a card (design #F5F8FC / #F1F4F8).
  Color get _inset =>
      _dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF5F8FC);

  /// Hairlines and progress tracks (design #F1F4F8 / #EEF2F7).
  Color get _hairline =>
      _dark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFF1F4F8);

  Color get _track =>
      _dark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFEEF2F7);

  /// Tinted icon squares: the light tints are far too bright on black, so in
  /// dark mode they become a wash of the icon's own colour instead.
  Color _tint(Color fg, Color lightBg) =>
      _dark ? fg.withValues(alpha: 0.20) : lightBg;

  List<BoxShadow> get _cardShadow => _dark
      ? const []
      : const [
          BoxShadow(color: Color(0x0D103863), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x12103863), blurRadius: 18, offset: Offset(0, 6)),
        ];

  /// 1.5 Commissions.
  Widget _buildCommissionsSection() {
    final myLevels = _myCommissions?['levels'] as Map<String, dynamic>?;
    final hasData = _showTeamCommission ? _commissionData != null : myLevels != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Commissions',
              style: TextStyle(
                fontSize: 16.5, fontWeight: FontWeight.w800,
                letterSpacing: -0.3, color: _inkStrong,
              ),
            ),
            Text(
              DateFormat('MMMM yyyy').format(_selectedDate),
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCommissionTabs(),
        const SizedBox(height: 12),
        if (!hasData)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: _cardShadow,
            ),
            child: Text(
              'No commission data available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _inkMuted,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: _cardShadow,
            ),
            child: Column(
              children: [
                for (final level in const ['i', 'ii', 'iii'])
                  _buildCommissionLevelRow(
                    level: level,
                    data: _levelData(level, myLevels),
                    isLast: level == 'iii',
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Map<String, dynamic>? _levelData(String level, Map<String, dynamic>? myLevels) {
    final source = _showTeamCommission ? _commissionData : myLevels;
    return source?['level_$level'] as Map<String, dynamic>?;
  }

  Widget _buildCommissionTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEAEFF5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          for (final team in const [false, true])
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showTeamCommission = team),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _showTeamCommission == team
                        ? (_dark ? AppColors.darkCard : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _showTeamCommission == team
                        ? const [
                            BoxShadow(
                              color: Color(0x1F103863),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    team ? 'Team' : 'My commission',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: _showTeamCommission == team
                          ? _inkStrong
                          : _inkMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommissionLevelRow({
    required String level,
    required Map<String, dynamic>? data,
    required bool isLast,
  }) {
    const badgeBg = {
      'i': Color(0xFFE7F6EE), 'ii': Color(0xFFFDF1DC), 'iii': Color(0xFFEAF3FB)
    };
    const badgeFg = {
      'i': Color(0xFF12833C), 'ii': Color(0xFF8A5F0B), 'iii': Color(0xFF1668A6)
    };
    const barColor = {
      'i': Color(0xFF16A34A), 'ii': Color(0xFFE5A227), 'iii': Color(0xFF1D7DC4)
    };
    const amountColor = {
      'i': Color(0xFF12833C), 'ii': Color(0xFF103863), 'iii': Color(0xFF6B7684)
    };

    final numeral = level.toUpperCase();

    late final String subtitle;
    late final double amount;
    late final double percent;

    if (_showTeamCommission) {
      final achieved = _asDouble(data?['achieved_count']);
      final total = _asDouble(data?['total_customers']);
      subtitle = '${achieved.round()} / ${total.round()} customers';
      amount = _asDouble(data?['actual_commission']);
      percent = _asDouble(data?['progress_percent']);
    } else {
      final target = _asDouble(data?['target']);
      final average = _asDouble(data?['average']);
      subtitle = 'Target ${_formatCompact(target)} · avg ${_formatCompact(average)}';
      amount = _asDouble(data?['commission']);
      // my_commissions carries no percentage of its own; the level is reached
      // when the running average clears the target.
      percent = target > 0 ? (average / target) * 100 : 0;
    }

    final reached = amount > 0;

    return Column(
      children: [
        InkWell(
          onTap: data == null
              ? null
              : () => _showCommissionDetail(numeral, data, badgeFg[level]!, false),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tint(badgeFg[level]!, badgeBg[level]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        numeral,
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          letterSpacing: 0.4, color: badgeFg[level],
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level $numeral',
                            style: TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w800,
                              color: _inkStrong,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: _inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          reached ? _formatCompact(amount) : '0',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800,
                            color: reached
                                ? (amountColor[level] == const Color(0xFF103863)
                                    ? _inkStrong
                                    : amountColor[level])
                                : _inkMuted,
                          ),
                        ),
                        Text(
                          reached
                              ? (_showTeamCommission ? 'net' : 'commission')
                              : 'not reached',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: _inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.chevron_right, size: 15, color: Color(0xFF9AA5B4)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: (percent / 100).clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor: _track,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor[level]!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${percent.round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: _inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, thickness: 1, color: _hairline),
      ],
    );
  }

  /// 1.6 Discipline banner.
  Widget _buildDisciplineBanner() {
    final cases = (_topStats?['total_disciplinary'] ?? 0);
    final clean = _asDouble(cases) == 0;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _dark
            ? (clean ? const Color(0xFF3A2F17) : const Color(0xFF3A1E1E))
            : (clean ? const Color(0xFFFFF8EC) : const Color(0xFFFDECEC)),
        border: Border.all(
            color: _dark
                ? Colors.white.withValues(alpha: 0.10)
                : (clean ? const Color(0xFFF3DDB4) : const Color(0xFFF3BDBD))),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : (clean ? const Color(0xFFFBEDD2) : const Color(0xFFF9D9D9)),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 17,
              color: clean ? const Color(0xFFE0A93C) : const Color(0xFFE06B5E),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clean
                      ? 'No disciplinary cases'
                      : '${_asDouble(cases).round()} disciplinary cases',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _dark
                        ? (clean ? const Color(0xFFF0D9A8) : const Color(0xFFF3C4BE))
                        : (clean ? const Color(0xFF8A5F0B) : const Color(0xFFC0392B)),
                  ),
                ),
                Text(
                  clean
                      ? 'Keep the record clean to unlock Level III bonus'
                      : 'Clear these to stay eligible for the Level III bonus',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _dark
                        ? (clean ? const Color(0xFFCDB98F) : const Color(0xFFDBA9A2))
                        : (clean ? const Color(0xFF8A5F0B) : const Color(0xFFC0392B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 1.2 Credits KPI card.
  Widget _buildCreditsKpiCard() {
    final loaded = _dailyCollections;
    final thisWeek = loaded != null ? loaded.sublist(7) : const <double>[];
    final lastWeek = loaded != null ? loaded.sublist(0, 7) : const <double>[];

    final collected = thisWeek.fold<double>(0, (sum, v) => sum + v);
    final previous = lastWeek.fold<double>(0, (sum, v) => sum + v);
    final outstanding = _asDouble(_topStats!['total_credits']);

    // Null when there is no prior week to compare against -- a "+100%" against
    // zero would read as growth when it only means last week had no data.
    final double? delta =
        previous > 0 ? ((collected - previous) / previous) * 100 : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'TOTAL CREDITS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w800,
                    letterSpacing: 1, color: _inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: _tint(const Color(0xFF1D7DC4), const Color(0xFFF1F5FB)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 13, color: Color(0xFF1D7DC4)),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: Color(0xFF1D7DC4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  _formatCompact(outstanding),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w800,
                    letterSpacing: -1.4, color: _inkStrong,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text('TSh',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _inkMuted)),
            ],
          ),
          if (thisWeek.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCollectionChart(thisWeek),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildKpiSplit('COLLECTED', collected, const Color(0xFF12833C)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiSplit('OUTSTANDING', outstanding, const Color(0xFF103863)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: _hairline),
          const SizedBox(height: 11),
          Row(
            children: [
              if (delta != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: delta >= 0
                        ? _tint(const Color(0xFF12833C), const Color(0xFFE7F6EE))
                        : _tint(const Color(0xFFC0392B), const Color(0xFFFDECEC)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        delta >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 11,
                        color: delta >= 0 ? const Color(0xFF12833C) : const Color(0xFFC0392B),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${delta.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: delta >= 0 ? const Color(0xFF12833C) : const Color(0xFFC0392B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'vs last week',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: _inkMuted,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DailyDebtReportScreen()),
                ),
                child: const Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1668A6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Seven bars, one per day of the current week, scaled to the busiest day.
  Widget _buildCollectionChart(List<double> week) {
    final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final labels = List.generate(
      7,
      (i) => DateFormat('E').format(end.subtract(Duration(days: 6 - i)))[0],
    );
    final peak = week.reduce((a, b) => a > b ? a : b);
    final todayIndex = week.length - 1;

    return SizedBox(
      height: 98,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final value = week[index];
          // A flat 6px floor keeps empty days visible as an empty slot rather
          // than a gap the eye reads as missing data.
          final height = peak > 0 ? 6 + (value / peak) * 64 : 6.0;
          final today = index == todayIndex;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: today
                          ? const Color(0xFF3C7CBF)
                          : (_dark
                              ? Colors.white.withValues(alpha: 0.14)
                              : const Color(0xFFD6E3F1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: today ? FontWeight.w800 : FontWeight.w700,
                      color: today
                          ? (_dark ? const Color(0xFF6FA8DC) : const Color(0xFF1668A6))
                          : _inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKpiSplit(String label, double value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _inset,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w800,
              letterSpacing: 0.7, color: _inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCompact(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800,
              color: valueColor == const Color(0xFF103863) ? _inkStrong : valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color fg,
    required Color bg,
    String? chip,
    Color? chipFg,
    Color? chipBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _tint(fg, bg),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 15, color: fg),
              ),
              const Spacer(),
              if (chip != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _tint(chipFg ?? fg, chipBg ?? bg),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: _dark ? Colors.white : (chipFg ?? fg),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 21, height: 1.15, fontWeight: FontWeight.w800,
              letterSpacing: -0.7, color: _inkStrong,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w600,
              color: _inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatCard({
    required String title,
    required dynamic value,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isCurrency = false,
  }) {
    // Format value - use compact format for large numbers
    String displayValue;
    if (isCurrency) {
      final numValue = (value ?? 0).toDouble();
      displayValue = _formatCompact(numValue);
    } else {
      displayValue = '${value ?? 0}';
    }

    // For dark mode: use muted/darker versions of colors
    final cardColor = isDark
        ? HSLColor.fromColor(color).withSaturation(0.4).withLightness(0.25).toColor()
        : color;
    final accentColor = isDark ? color : Colors.white;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isDark
              ? [cardColor, cardColor.withOpacity(0.85)]
              : [color.withOpacity(0.9), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? color.withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : color.withOpacity(0.35),
            blurRadius: isDark ? 10 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? accentColor : Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? color.withOpacity(0.2) : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDark ? color.withOpacity(0.8) : Colors.white.withOpacity(0.9),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextLight : Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Progress Card (Progress Commission / Customers Served)
  /// The dashboard sums arrive as numbers on some builds and as strings on
  /// others (MySQL SUM() through CI's json encoder), so parse defensively --
  /// a bare .toDouble() throws on the string form.
  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  String _formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  /// Progress pair below the stat grid.
  ///
  /// Restyled to the same compact language as the stat cards: the old version
  /// stacked a large icon tile, a title, a value and a bar with generous gaps,
  /// so two cards took more height than the four above them.
  Widget _buildProgressCard({
    required String title,
    required IconData icon,
    required double current,
    required double target,
    required double percentage,
    required bool isDark,
    bool isCount = false,
  }) {
    final reached = percentage >= 100;
    final fg = reached ? const Color(0xFF12833C) : const Color(0xFF1D7DC4);
    final bg = reached ? const Color(0xFFE7F6EE) : const Color(0xFFEAF3FB);

    final value = isCount
        ? '${current.round()}'
        : '${_formatCompact(current)} / ${_formatCompact(target)}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _tint(fg, bg),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 15, color: fg),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _tint(fg, bg),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: _dark ? Colors.white : fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19, height: 1.15, fontWeight: FontWeight.w800,
              letterSpacing: -0.6, color: _inkStrong,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w600,
              color: _inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: _track,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionLevelCard({
    required String level,
    required Map<String, dynamic>? data,
    required Color color,
    required bool isDark,
  }) {
    if (data == null) {
      return const SizedBox.shrink();
    }

    final progressPercent = (data['progress_percent'] ?? 0).toDouble();
    final totalCommission = (data['total_commission'] ?? 0).toDouble();
    final actualCommission = (data['actual_commission'] ?? 0).toDouble();
    final achievedCount = data['achieved_count'] ?? 0;
    final totalCustomers = data['total_customers'] ?? 0;
    final status = data['status'] ?? 'in_progress';
    final isAchieved = status == 'achieved';

    return GlassmorphicCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.8), color],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        level,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level $level',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                      Text(
                        '$achievedCount / $totalCustomers customers',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAchieved ? AppColors.success.withOpacity(0.2) : color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isAchieved ? 'Achieved' : 'In Progress',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAchieved ? AppColors.success : color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ),
                  ),
                  Text(
                    '${progressPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (progressPercent / 100).clamp(0.0, 1.0),
                  backgroundColor: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Commission Amount Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commission',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(totalCommission),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.text,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Net Commission',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(actualCommission),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: actualCommission >= 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build My Commission Level Card (user's individual data, clickable)
  Widget _buildMyCommissionLevelCard({
    required String level,
    required Map<String, dynamic>? data,
    required Color color,
    required bool isDark,
  }) {
    if (data == null) {
      return const SizedBox.shrink();
    }

    final purchases = (data['purchases'] ?? 0).toDouble();
    final average = (data['average'] ?? 0).toDouble();
    final target = (data['target'] ?? 0).toDouble();
    final days = data['days'] ?? 0;
    final commission = (data['commission'] ?? 0).toDouble();
    final disciplinary = (data['disciplinary'] ?? 0).toDouble();
    final actual = (data['actual'] ?? 0).toDouble();
    final status = data['status'] ?? 'not_achieved';
    final isAchieved = status == 'achieved';
    final items = data['items'] as List<dynamic>? ?? [];
    final totalWithItems = (data['total_with_items'] ?? 0).toDouble();

    // Calculate progress percentage
    final progressPercent = target > 0 ? (average / target * 100).clamp(0.0, 100.0) : 0.0;

    // Muted colors for dark mode
    final badgeColor = isDark
        ? HSLColor.fromColor(color).withSaturation(0.5).withLightness(0.35).toColor()
        : color;
    final statusColor = isAchieved ? AppColors.success : color;
    final mutedStatusColor = isDark
        ? HSLColor.fromColor(statusColor).withSaturation(0.5).withLightness(0.35).toColor()
        : statusColor;
    final progressBarColor = isDark
        ? HSLColor.fromColor(color).withSaturation(0.6).withLightness(0.45).toColor()
        : color;

    return GestureDetector(
      onTap: () => _showCommissionDetail(level, data, color, isDark),
      child: GlassmorphicCard(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [badgeColor.withOpacity(0.9), badgeColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: isDark
                            ? Border.all(color: color.withOpacity(0.3), width: 1)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          level,
                          style: TextStyle(
                            color: isDark ? color.withOpacity(0.9) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level $level',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        Text(
                          'Target: ${_formatCompact(target)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: mutedStatusColor.withOpacity(isDark ? 0.3 : 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: isDark
                            ? Border.all(color: statusColor.withOpacity(0.3), width: 1)
                            : null,
                      ),
                      child: Text(
                        isAchieved ? 'Achieved' : 'In Progress',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? statusColor.withOpacity(0.85) : statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Average: ${_formatCompact(average)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      ),
                    ),
                    Text(
                      '${progressPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (progressPercent / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [progressBarColor.withOpacity(0.8), progressBarColor],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Commission Amount Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commission',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(commission),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total (Base + Items)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(totalWithItems),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? (totalWithItems >= 0 ? AppColors.success.withOpacity(0.85) : AppColors.error.withOpacity(0.85))
                            : (totalWithItems >= 0 ? AppColors.success : AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show commission detail bottom sheet
  void _showCommissionDetail(String level, Map<String, dynamic> data, Color color, bool isDark) {
    final purchases = (data['purchases'] ?? 0).toDouble();
    final average = (data['average'] ?? 0).toDouble();
    final target = (data['target'] ?? 0).toDouble();
    final days = data['days'] ?? 0;
    final commission = (data['commission'] ?? 0).toDouble();
    final disciplinary = (data['disciplinary'] ?? 0).toDouble();
    final actual = (data['actual'] ?? 0).toDouble();
    final status = data['status'] ?? 'not_achieved';
    final isAchieved = status == 'achieved';
    final name = data['name'] ?? '';
    final items = data['items'] as List<dynamic>? ?? [];
    final itemSubtotal = (data['item_subtotal'] ?? 0).toDouble();
    final totalWithItems = (data['total_with_items'] ?? 0).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.8), color],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          level,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Commission Level $level',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkText : AppColors.text,
                            ),
                          ),
                          if (name.isNotEmpty)
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAchieved ? AppColors.success.withOpacity(0.2) : color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isAchieved ? 'ACHIEVED' : 'NOT ACHIEVED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAchieved ? AppColors.success : color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Purchases', Formatters.formatCurrency(purchases), isDark),
                          _buildDetailRow('Average', Formatters.formatCurrency(average), isDark),
                          _buildDetailRow('Target', Formatters.formatCurrency(target), isDark),
                          _buildDetailRow('Days', '$days', isDark),
                          const Divider(height: 24),
                          _buildDetailRow('Commission', Formatters.formatCurrency(commission), isDark, valueColor: AppColors.success),
                          _buildDetailRow('Disciplinary', Formatters.formatCurrency(disciplinary), isDark, valueColor: AppColors.error),
                          _buildDetailRow('Actual', Formatters.formatCurrency(actual), isDark, valueColor: AppColors.success, isBold: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Items Section
                    if (items.isNotEmpty) ...[
                      Text(
                        'Item Commissions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...items.map((item) {
                        final itemData = item as Map<String, dynamic>;
                        final itemName = itemData['item_name'] ?? 'Unknown Item';
                        final qtyPurchased = (itemData['qty_purchased'] ?? 0).toDouble();
                        final qtyTarget = (itemData['qty_target'] ?? 0).toDouble();
                        final ratePerUnit = (itemData['rate_per_unit'] ?? 0).toDouble();
                        final itemStatus = itemData['status'] ?? 'not_achieved';
                        final itemCommission = (itemData['commission'] ?? 0).toDouble();
                        final itemAchieved = itemStatus == 'achieved';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: itemAchieved ? AppColors.success.withOpacity(0.3) : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      itemName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkText : AppColors.text,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: itemAchieved ? AppColors.success.withOpacity(0.2) : AppColors.error.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      itemAchieved ? 'ACHIEVED' : 'NOT ACHIEVED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: itemAchieved ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMiniStat('Qty Purchased', '${qtyPurchased.toInt()}', isDark),
                                  ),
                                  Expanded(
                                    child: _buildMiniStat('Qty Target', '${qtyTarget.toInt()}', isDark),
                                  ),
                                  Expanded(
                                    child: _buildMiniStat('Rate/Unit', '${ratePerUnit.toInt()}', isDark),
                                  ),
                                  Expanded(
                                    child: _buildMiniStat('Commission', Formatters.formatCurrency(itemCommission), isDark,
                                        valueColor: itemCommission > 0 ? AppColors.success : null),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('Item Subtotal', Formatters.formatCurrency(itemSubtotal), isDark),
                            const Divider(height: 16),
                            _buildDetailRow('Total (Base + Items)', Formatters.formatCurrency(totalWithItems), isDark,
                                valueColor: AppColors.success, isBold: true),
                          ],
                        ),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No item commissions for this level',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build detail row for bottom sheet
  Widget _buildDetailRow(String label, String value, bool isDark, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? (isDark ? AppColors.darkText : AppColors.text),
            ),
          ),
        ],
      ),
    );
  }

  /// Build mini stat widget for item details
  Widget _buildMiniStat(String label, String value, bool isDark, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? AppColors.darkText : AppColors.text),
          ),
        ),
      ],
    );
  }

  /// Build Quick Stat Card
  /// Build Activity Item
  /// Build profile avatar with profile picture (Leruma feature) or default icon
  Widget _buildProfileAvatar(dynamic user, double size) {
    final hasCommissionDashboard = ApiService.currentClient?.features.hasCommissionDashboard ?? false;
    final profilePicture = user?.profilePicture;

    // Show profile picture only for Leruma (hasCommissionDashboard) and if picture exists
    if (hasCommissionDashboard && profilePicture != null && profilePicture.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.brandPrimary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            profilePicture,
            width: size,
            height: size,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              // Skeleton/shimmer placeholder while loading
              return _buildSkeletonAvatar(size);
            },
            errorBuilder: (context, error, stackTrace) {
              // Fallback to default icon on error
              return _buildDefaultAvatar(size);
            },
          ),
        ),
      );
    }

    // Default avatar with icon
    return _buildDefaultAvatar(size);
  }

  /// Build skeleton/shimmer placeholder for loading avatar
  Widget _buildSkeletonAvatar(double size) {
    return _ShimmerBox(
      width: size,
      height: size,
      borderRadius: size / 2,
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: Colors.grey.withOpacity(0.3),
      ),
    );
  }

  /// Build skeleton placeholders for dashboard loading
  Widget _buildDashboardSkeleton(bool isDark) {
    final hasCommissionDashboard = ApiService.currentClient?.features.hasCommissionDashboard ?? false;

    if (hasCommissionDashboard) {
      return _buildLerumaDashboardSkeleton(isDark);
    } else {
      return _buildStandardDashboardSkeleton(isDark);
    }
  }

  /// Build Leruma dashboard skeleton with shimmer effect
  Widget _buildLerumaDashboardSkeleton(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Stats Row (4 cards)
        Row(
          children: [
            Expanded(child: _buildStatCardSkeleton(isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCardSkeleton(isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildStatCardSkeleton(isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCardSkeleton(isDark)),
          ],
        ),
        const SizedBox(height: 16),

        // Progress Cards Row
        Row(
          children: [
            Expanded(child: _buildProgressCardSkeleton(isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildProgressCardSkeleton(isDark)),
          ],
        ),
        const SizedBox(height: 20),

        // My Commissions Section Title
        _ShimmerBox(
          width: 140,
          height: 20,
          borderRadius: 4,
        ),
        const SizedBox(height: 12),

        // Commission Level Cards
        _buildCommissionCardSkeleton(isDark),
        const SizedBox(height: 12),
        _buildCommissionCardSkeleton(isDark),
        const SizedBox(height: 12),
        _buildCommissionCardSkeleton(isDark),
      ],
    );
  }

  /// Build standard dashboard skeleton
  Widget _buildStandardDashboardSkeleton(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDashboardCardSkeleton(isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildDashboardCardSkeleton(isDark)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDashboardCardSkeleton(isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildDashboardCardSkeleton(isDark)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDashboardCardSkeleton(isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildDashboardCardSkeleton(isDark)),
          ],
        ),
      ],
    );
  }

  /// Build stat card skeleton (small cards for top stats)
  Widget _buildStatCardSkeleton(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShimmerBox(width: 28, height: 28, borderRadius: 6),
              const SizedBox(width: 8),
              Expanded(
                child: _ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ShimmerBox(width: 80, height: 20, borderRadius: 4),
        ],
      ),
    );
  }

  /// Build progress card skeleton
  Widget _buildProgressCardSkeleton(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ShimmerBox(width: 32, height: 32, borderRadius: 8),
              _ShimmerBox(width: 50, height: 18, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 8),
          _ShimmerBox(width: 100, height: 14, borderRadius: 4),
          const SizedBox(height: 8),
          _ShimmerBox(width: double.infinity, height: 6, borderRadius: 3),
        ],
      ),
    );
  }

  /// Build commission level card skeleton
  Widget _buildCommissionCardSkeleton(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _ShimmerBox(width: 40, height: 40, borderRadius: 10),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(width: 70, height: 16, borderRadius: 4),
                      const SizedBox(height: 4),
                      _ShimmerBox(width: 90, height: 12, borderRadius: 4),
                    ],
                  ),
                ],
              ),
              _ShimmerBox(width: 70, height: 24, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ShimmerBox(width: 100, height: 12, borderRadius: 4),
              _ShimmerBox(width: 50, height: 12, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 8),
          _ShimmerBox(width: double.infinity, height: 8, borderRadius: 4),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(width: 70, height: 11, borderRadius: 4),
                  const SizedBox(height: 4),
                  _ShimmerBox(width: 80, height: 14, borderRadius: 4),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ShimmerBox(width: 90, height: 11, borderRadius: 4),
                  const SizedBox(height: 4),
                  _ShimmerBox(width: 80, height: 14, borderRadius: 4),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build dashboard card skeleton (for standard dashboard)
  Widget _buildDashboardCardSkeleton(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShimmerBox(width: 44, height: 44, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(width: 80, height: 12, borderRadius: 4),
                    const SizedBox(height: 6),
                    _ShimmerBox(width: 100, height: 18, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build default avatar with person icon
  Widget _buildDefaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.brandPrimary.withOpacity(0.8),
            AppColors.brandPrimary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.person,
        size: size * 0.53,
        color: Colors.white,
      ),
    );
  }
}

/// Shimmer box widget for skeleton loading effect
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Widget? child;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 4,
    this.child,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _animation.value, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                Colors.grey.withOpacity(0.2),
                Colors.grey.withOpacity(0.4),
                Colors.grey.withOpacity(0.2),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: widget.child != null
              ? Center(child: widget.child)
              : null,
        );
      },
    );
  }
}
