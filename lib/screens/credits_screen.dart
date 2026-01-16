import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/credit.dart';
import '../models/stock_location.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/glassmorphic_card.dart';
import '../utils/constants.dart';
import 'customer_credit_screen.dart';
import 'daily_debt_report_screen.dart';

/// Credits Screen - Shows list of supervisors with their credit balances
/// Similar to web /credits page
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _formatter = NumberFormat('#,###');

  SupervisorCreditsResponse? _creditsData;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndLoad();
    });
  }

  Future<void> _initializeAndLoad() async {
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.initialize(moduleId: 'credits');
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Get location IDs from location provider
    final locationProvider = context.read<LocationProvider>();
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    List<int>? locationIds;
    if (isLeruma && locationProvider.selectedLocation != null) {
      // For Leruma: filter by selected location only
      locationIds = [locationProvider.selectedLocation!.locationId];
    } else if (locationProvider.allowedLocations.isNotEmpty) {
      // For other clients: use all allowed locations
      locationIds = locationProvider.allowedLocations
          .map((loc) => loc.locationId)
          .toList();
    }

    final response = await _apiService.getSupervisorCredits(
      locationIds: locationIds,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _creditsData = response.data;
        } else {
          _errorMessage = response.message ?? 'Failed to load credits';
        }
      });
    }
  }

  List<SupervisorCredit> get _filteredSupervisors {
    if (_creditsData == null) return [];
    if (_searchQuery.isEmpty) return _creditsData!.supervisors;

    final query = _searchQuery.toLowerCase();
    return _creditsData!.supervisors.where((s) {
      return s.name.toLowerCase().contains(query) ||
          s.phone.toLowerCase().contains(query);
    }).toList();
  }

  void _viewSupervisorCustomers(SupervisorCredit supervisor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupervisorCustomersScreen(
          supervisorId: supervisor.supervisorId,
          supervisorName: supervisor.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Credits'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Location selector - Leruma only
          if (isLeruma && locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PopupMenuButton<StockLocation>(
                  offset: const Offset(0, 40),
                  color: Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          locationProvider.selectedLocation!.locationName,
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
                    ],
                  ),
                  onSelected: (location) async {
                    await locationProvider.selectLocation(location);
                    _loadCredits();
                  },
                  itemBuilder: (context) => locationProvider.allowedLocations
                      .map((location) => PopupMenuItem<StockLocation>(
                            value: location,
                            child: Row(
                              children: [
                                Icon(
                                  location.locationId == locationProvider.selectedLocation?.locationId
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: location.locationId == locationProvider.selectedLocation?.locationId
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  location.locationName,
                                  style: TextStyle(
                                    color: location.locationId == locationProvider.selectedLocation?.locationId
                                        ? AppColors.primary
                                        : Colors.black87,
                                    fontWeight: location.locationId == locationProvider.selectedLocation?.locationId
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCredits,
            tooltip: 'Refresh',
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
      body: Container(
        color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
        child: Column(
          children: [
            // Summary Card with glassmorphic design
            if (_creditsData != null && !_isLoading)
              _buildSummaryCard(isDark),

            // Daily Debt Report Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassmorphicCard(
                isDark: isDark,
                borderRadius: 12,
                padding: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DailyDebtReportScreen()),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.payments, color: AppColors.success, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Debt Collection',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                'View all debt payments received',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GlassmorphicCard(
                isDark: isDark,
                borderRadius: 12,
                padding: EdgeInsets.zero,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search supervisor or phone...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ),

            // Results count
            if (_creditsData != null && !_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.supervisor_account, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${_filteredSupervisors.length} supervisors',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Supervisors List
            Expanded(
              child: _isLoading
                  ? _buildSkeletonList(isDark)
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _filteredSupervisors.isEmpty
                          ? _buildEmptyView()
                          : _buildSupervisorsList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final summary = _creditsData!.summary;

    return Container(
      margin: const EdgeInsets.all(16),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 16,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Credit',
                    _formatter.format(summary.totalCredit),
                    AppColors.error,
                    Icons.arrow_upward,
                    isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Paid',
                    _formatter.format(summary.totalDebit),
                    AppColors.success,
                    Icons.arrow_downward,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (summary.totalBalance > 0 ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: summary.totalBalance > 0 ? AppColors.error : AppColors.success,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Total Balance',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatter.format(summary.totalBalance),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: summary.totalBalance > 0 ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, IconData icon, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSupervisorsList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadCredits,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredSupervisors.length,
        itemBuilder: (context, index) {
          final supervisor = _filteredSupervisors[index];
          return _buildSupervisorCard(supervisor, isDark, index + 1);
        },
      ),
    );
  }

  Widget _buildSupervisorCard(SupervisorCredit supervisor, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 14,
        child: InkWell(
          onTap: () => _viewSupervisorCustomers(supervisor),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supervisor.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (supervisor.phone.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.phone, size: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  supervisor.phone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatColumn('Credit', supervisor.credit, AppColors.error, isDark),
                      ),
                      Container(
                        width: 1,
                        height: 35,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildStatColumn('Paid', supervisor.debit, AppColors.success, isDark),
                      ),
                      Container(
                        width: 1,
                        height: 35,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildStatColumn('Balance', supervisor.balance,
                          supervisor.balance > 0 ? AppColors.error : AppColors.success, isDark, isBold: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, double value, Color color, bool isDark, {bool isBold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _formatter.format(value),
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: GlassmorphicCard(
          isDark: isDark,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  SkeletonLoader(width: 44, height: 44, borderRadius: 12, isDark: isDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(width: 140, height: 16, isDark: isDark),
                        const SizedBox(height: 6),
                        SkeletonLoader(width: 100, height: 12, isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SkeletonLoader(width: double.infinity, height: 50, borderRadius: 10, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadCredits,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No supervisors with credit balance'
                : 'No results found for "$_searchQuery"',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Screen to show customers under a specific supervisor
class SupervisorCustomersScreen extends StatefulWidget {
  final int supervisorId;
  final String supervisorName;

  const SupervisorCustomersScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<SupervisorCustomersScreen> createState() => _SupervisorCustomersScreenState();
}

class _SupervisorCustomersScreenState extends State<SupervisorCustomersScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _formatter = NumberFormat('#,###');

  SupervisorCustomersResponse? _customersData;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getSupervisorCustomers(widget.supervisorId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _customersData = response.data;
        } else {
          _errorMessage = response.message ?? 'Failed to load customers';
        }
      });
    }
  }

  List<CustomerCredit> get _filteredCustomers {
    if (_customersData == null) return [];
    if (_searchQuery.isEmpty) return _customersData!.customers;

    final query = _searchQuery.toLowerCase();
    return _customersData!.customers.where((c) {
      return c.fullName.toLowerCase().contains(query) ||
          c.phone.toLowerCase().contains(query);
    }).toList();
  }

  void _viewCustomerCredit(CustomerCredit customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerCreditScreen(
          customerId: customer.customerId,
          customerName: customer.fullName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supervisorName),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
      body: Container(
        color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
        child: Column(
          children: [
            // Summary Card
            if (_customersData != null && !_isLoading)
              _buildSummaryCard(isDark),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GlassmorphicCard(
                isDark: isDark,
                borderRadius: 12,
                padding: EdgeInsets.zero,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search customer or phone...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ),

            // Results count
            if (_customersData != null && !_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.people, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${_filteredCustomers.length} customers',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Customers List
            Expanded(
              child: _isLoading
                  ? _buildSkeletonList(isDark)
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _filteredCustomers.isEmpty
                          ? _buildEmptyView()
                          : _buildCustomersList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final summary = _customersData!.summary;

    return Container(
      margin: const EdgeInsets.all(16),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 16,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Credit',
                    _formatter.format(summary.totalCredit),
                    AppColors.error,
                    Icons.arrow_upward,
                    isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Paid',
                    _formatter.format(summary.totalDebit),
                    AppColors.success,
                    Icons.arrow_downward,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (summary.totalBalance > 0 ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: summary.totalBalance > 0 ? AppColors.error : AppColors.success,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Total Balance',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatter.format(summary.totalBalance),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: summary.totalBalance > 0 ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, IconData icon, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomersList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadCustomers,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredCustomers.length,
        itemBuilder: (context, index) {
          final customer = _filteredCustomers[index];
          return _buildCustomerCard(customer, isDark, index + 1);
        },
      ),
    );
  }

  Widget _buildCustomerCard(CustomerCredit customer, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 14,
        child: InkWell(
          onTap: () => _viewCustomerCredit(customer),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.secondary, AppColors.secondary.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          customer.firstName.isNotEmpty
                              ? customer.firstName[0].toUpperCase()
                              : '$index',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.fullName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (customer.phone.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.phone, size: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  customer.phone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatColumn('Credit', customer.credit, AppColors.error, isDark),
                      ),
                      Container(
                        width: 1,
                        height: 35,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildStatColumn('Paid', customer.debit, AppColors.success, isDark),
                      ),
                      Container(
                        width: 1,
                        height: 35,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildStatColumn('Balance', customer.balance,
                          customer.balance > 0 ? AppColors.error : AppColors.success, isDark, isBold: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, double value, Color color, bool isDark, {bool isBold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _formatter.format(value),
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: GlassmorphicCard(
          isDark: isDark,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  SkeletonLoader(width: 44, height: 44, borderRadius: 12, isDark: isDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(width: 140, height: 16, isDark: isDark),
                        const SizedBox(height: 6),
                        SkeletonLoader(width: 100, height: 12, isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SkeletonLoader(width: double.infinity, height: 50, borderRadius: 10, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadCustomers,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No customers with credit balance'
                : 'No results found for "$_searchQuery"',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
