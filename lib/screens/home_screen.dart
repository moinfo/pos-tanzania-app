import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/location_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/glassmorphic_card.dart';

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

  // Leruma Commission Dashboard data
  Map<String, dynamic>? _commissionData;
  Map<String, dynamic>? _salesSummary;
  List<Map<String, dynamic>> _recentActivity = [];
  Map<String, dynamic>? _quickStats;

  // Enhanced Leruma data (new)
  Map<String, dynamic>? _topStats;
  Map<String, dynamic>? _progressCommission;
  Map<String, dynamic>? _progressCustomers;
  Map<String, dynamic>? _myCommissions; // User's individual commission data

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
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
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.darkSurface,
                    onSurface: AppColors.darkText,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
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
    final clientId = currentClient?.id ?? 'sada';

    // Initialize location provider for Come & Save
    if (clientId == 'come_and_save' && mounted) {
      final locationProvider = context.read<LocationProvider>();
      await locationProvider.initialize(moduleId: 'items');
    }

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
    final selectedLocationId = locationProvider.selectedLocation?.locationId;

    if (selectedLocationId == null) {
      setState(() {
        _error = 'Please select a stock location';
        _isLoading = false;
      });
      return;
    }

    // Format selected date for API
    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);

    print('📍 Loading Come & Save dashboard for location: $selectedLocationId on $dateString');

    // Get summary for selected date and location
    final summaryResponse = await _apiService.getCashSubmitTodaySummary(
      date: dateString,
      locationId: selectedLocationId,
    );

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

        _totalUnpaid = 0; // Come & Save doesn't have contracts
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = summaryResponse.message;
        _isLoading = false;
      });
    }
  }

  /// Load dashboard for Leruma (commission tracking focused)
  Future<void> _loadLerumaDashboard() async {
    // Format dates for API
    final startDate = DateFormat('yyyy-MM-dd').format(DateTime(_selectedDate.year, _selectedDate.month, 1));
    final endDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    print('📊 Loading Leruma dashboard: $startDate to $endDate');

    // Get full dashboard data
    final dashboardResponse = await _apiService.getCommissionDashboard(
      startDate: startDate,
      endDate: endDate,
    );

    if (dashboardResponse.isSuccess && dashboardResponse.data != null) {
      final data = dashboardResponse.data!;

      setState(() {
        _commissionData = data['commission_progress'] as Map<String, dynamic>?;
        _salesSummary = data['sales_summary'] as Map<String, dynamic>?;
        _quickStats = data['quick_stats'] as Map<String, dynamic>?;

        // New enhanced data
        _topStats = data['top_stats'] as Map<String, dynamic>?;
        _progressCommission = data['progress_commission'] as Map<String, dynamic>?;
        _progressCustomers = data['progress_customers'] as Map<String, dynamic>?;
        _myCommissions = data['my_commissions'] as Map<String, dynamic>?;

        // Parse recent activity
        final activityList = data['recent_activity'] as List<dynamic>?;
        if (activityList != null) {
          _recentActivity = activityList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }

        // Also update the standard fields from sales summary
        final todaySummary = _salesSummary?['today'] as Map<String, dynamic>?;
        if (todaySummary != null) {
          _totalSales = (todaySummary['total_sales'] ?? 0).toDouble();
          _expenses = (todaySummary['expenses'] ?? 0).toDouble();
          _profit = (todaySummary['profit'] ?? 0).toDouble();
        }

        _isLoading = false;
      });
    } else {
      setState(() {
        _error = dashboardResponse.message ?? 'Failed to load dashboard';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.user;
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
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Card with Glassmorphism
            GlassmorphicCard(
              isDark: isDark,
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Profile picture (Leruma feature) or default icon
                  _buildProfileAvatar(user, 60),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.displayName ?? 'User',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        if (user?.email != null && user!.email!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.email!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                      color: (isDark ? AppColors.darkSurface : Colors.white).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isDark ? AppColors.darkDivider : AppColors.lightDivider).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: isDark ? AppColors.primary : AppColors.primary,
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

            // Location Selector (Come & Save only)
            if (ApiService.currentClient?.id == 'come_and_save')
              Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  if (locationProvider.allowedLocations.isEmpty) {
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
                              color: isDark ? AppColors.primary : AppColors.primary,
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
              Column(
                children: [
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

                  // Row 2: Profit & Gain/Loss
                  Row(
                    children: [
                      Expanded(
                        child: _buildDashboardCard(
                          title: 'Profit',
                          amount: _profit,
                          icon: Icons.trending_up,
                          color: AppColors.primary,
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

                  // Row 3: Bank Difference & Contract Unpaid (contracts only for SADA)
                  if (ApiService.currentClient?.features.hasContracts ?? false)
                    // SADA: Show both Bank Difference and Contract Unpaid
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
                    )
                  else
                    // Come & Save: Show only Bank Difference (no contracts)
                    _buildDashboardCard(
                      title: 'Bank Difference',
                      amount: _bankDifference,
                      icon: Icons.account_balance,
                      color: AppColors.info,
                      isDark: isDark,
                    ),
                ],
              ),
          ],
        ),
      ),
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
        // Top Stats Cards (like web dashboard)
        if (_topStats != null) ...[
          // Row 1: Total Customers & Total Credits
          Row(
            children: [
              Expanded(
                child: _buildTopStatCard(
                  title: 'Total Customers',
                  value: _topStats!['total_customers'] ?? 0,
                  icon: Icons.people,
                  color: const Color(0xFF2563EB), // Blue
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTopStatCard(
                  title: 'Total Credits',
                  value: _topStats!['total_credits'] ?? 0,
                  icon: Icons.credit_card,
                  color: const Color(0xFF10B981), // Green
                  isDark: isDark,
                  isCurrency: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Disciplinary & Shop Serves
          Row(
            children: [
              Expanded(
                child: _buildTopStatCard(
                  title: 'Disciplinary',
                  value: _topStats!['total_disciplinary'] ?? 0,
                  icon: Icons.warning_amber,
                  color: const Color(0xFFF59E0B), // Orange
                  isDark: isDark,
                  isCurrency: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTopStatCard(
                  title: 'Shop Serves',
                  value: _topStats!['total_shop_serves'] ?? 0,
                  icon: Icons.store,
                  color: const Color(0xFFEF4444), // Red
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Progress Commission & Progress Customers
        if (_progressCommission != null || _progressCustomers != null) ...[
          Row(
            children: [
              if (_progressCommission != null)
                Expanded(
                  child: _buildProgressCard(
                    title: 'Progress Commission',
                    icon: Icons.shopping_cart,
                    current: (_progressCommission!['average'] ?? 0).toDouble(),
                    target: (_progressCommission!['target'] ?? 0).toDouble(),
                    percentage: (_progressCommission!['percentage'] ?? 0).toDouble(),
                    isDark: isDark,
                  ),
                ),
              if (_progressCommission != null && _progressCustomers != null)
                const SizedBox(width: 12),
              if (_progressCustomers != null)
                Expanded(
                  child: _buildProgressCard(
                    title: 'Customers Served',
                    icon: Icons.people,
                    current: (_progressCustomers!['served'] ?? 0).toDouble(),
                    target: (_progressCustomers!['total'] ?? 0).toDouble(),
                    percentage: (_progressCustomers!['percentage'] ?? 0).toDouble(),
                    isDark: isDark,
                    isCount: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // Commission Progress Section
        Text(
          'My Commissions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.text,
          ),
        ),
        const SizedBox(height: 12),

        // Commission Level Cards - Use my_commissions (user's individual data)
        if (_myCommissions != null) ...[
          _buildMyCommissionLevelCard(
            level: 'I',
            data: _myCommissions!['level_i'] as Map<String, dynamic>?,
            color: AppColors.success,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildMyCommissionLevelCard(
            level: 'II',
            data: _myCommissions!['level_ii'] as Map<String, dynamic>?,
            color: AppColors.warning,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildMyCommissionLevelCard(
            level: 'III',
            data: _myCommissions!['level_iii'] as Map<String, dynamic>?,
            color: AppColors.primary,
            isDark: isDark,
          ),
        ] else
          GlassmorphicCard(
            isDark: isDark,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No commission data available',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                ),
              ),
            ),
          ),

        const SizedBox(height: 24),

        // Quick Stats
        if (_quickStats != null) ...[
          Text(
            'Quick Stats',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickStatCard(
                  title: 'Sales Today',
                  value: '${_quickStats!['sales_today_count'] ?? 0}',
                  icon: Icons.receipt_long,
                  color: AppColors.info,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickStatCard(
                  title: 'Active Customers',
                  value: '${_quickStats!['active_customers'] ?? 0}',
                  icon: Icons.people,
                  color: AppColors.success,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),

        // Recent Activity
        if (_recentActivity.isNotEmpty) ...[
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          GlassmorphicCard(
            isDark: isDark,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: _recentActivity.take(5).map((activity) {
                return _buildActivityItem(activity, isDark);
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  /// Build Top Stat Card (colorful cards like web dashboard)
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.9), color],
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
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                icon,
                color: Colors.white.withOpacity(0.3),
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Progress Card (Progress Commission / Customers Served)
  Widget _buildProgressCard({
    required String title,
    required IconData icon,
    required double current,
    required double target,
    required double percentage,
    required bool isDark,
    bool isCount = false,
  }) {
    return GlassmorphicCard(
      isDark: isDark,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and percentage badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    const Icon(Icons.arrow_upward, size: 8, color: AppColors.success),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Title on its own line
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Value
          Text(
            isCount
                ? '${current.toInt()}'
                : '${_formatCompact(current)} / ${_formatCompact(target)}',
            style: TextStyle(
              fontSize: isCount ? 26 : 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              backgroundColor: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  /// Format large numbers to compact form (e.g., 15.50M)
  String _formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  /// Build Commission Level Card with progress bar
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
                        color: totalWithItems >= 0 ? AppColors.success : AppColors.error,
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
  Widget _buildQuickStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return GlassmorphicCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withOpacity(0.2),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build Activity Item
  Widget _buildActivityItem(Map<String, dynamic> activity, bool isDark) {
    final type = activity['type'] ?? 'sale';
    final description = activity['description'] ?? '';
    final amount = (activity['amount'] ?? 0).toDouble();
    final timestamp = activity['timestamp'] ?? '';

    final isSale = type == 'sale';
    final color = isSale ? AppColors.success : AppColors.error;
    final icon = isSale ? Icons.shopping_cart : Icons.money_off;

    // Format timestamp
    String formattedTime = '';
    try {
      final dateTime = DateTime.parse(timestamp);
      formattedTime = DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      formattedTime = timestamp;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isSale ? '+' : '-'}${Formatters.formatCurrency(amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

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
              color: AppColors.primary.withOpacity(0.3),
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
            AppColors.primary.withOpacity(0.8),
            AppColors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
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
