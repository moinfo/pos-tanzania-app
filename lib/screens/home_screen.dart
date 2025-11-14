import 'package:flutter/material.dart';
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

  // Dashboard data
  double _totalSales = 0;
  double _expenses = 0;
  double _gainLoss = 0;
  double _profit = 0;
  double _bankDifference = 0;
  double _totalUnpaid = 0;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
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
      if (clientId == 'come_and_save') {
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
    // Get today's summary
    final summaryResponse = await _apiService.getCashSubmitTodaySummary();

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

    print('📍 Loading Come & Save dashboard for location: $selectedLocationId');

    // Get today's summary filtered by location
    final summaryResponse = await _apiService.getCashSubmitTodaySummary(
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
                  Container(
                    width: 60,
                    height: 60,
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
                    child: const Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
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

            // Dashboard Title
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
                Text(
                  Formatters.getTodayFormatted(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
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
}
