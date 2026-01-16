import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/supplier_credit.dart';
import '../models/supplier.dart' hide SupplierTransaction;
import '../models/stock_location.dart';
import '../models/permission_model.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/permission_provider.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/permission_wrapper.dart';
import '../utils/constants.dart';

/// Suppliers Credits Screen - Shows list of suppliers with their credit balances
/// Similar to web /suppliers_creditors page
class SuppliersCreditsScreen extends StatefulWidget {
  const SuppliersCreditsScreen({super.key});

  @override
  State<SuppliersCreditsScreen> createState() => _SuppliersCreditsScreenState();
}

class _SuppliersCreditsScreenState extends State<SuppliersCreditsScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _formatter = NumberFormat('#,###');

  SupplierCreditsResponse? _creditsData;
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

    final response = await _apiService.getSupplierCreditors(
      locationIds: locationIds,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _creditsData = response.data;
        } else {
          _errorMessage = response.message ?? 'Failed to load supplier credits';
        }
      });
    }
  }

  List<SupplierCredit> get _filteredSuppliers {
    if (_creditsData == null) return [];
    if (_searchQuery.isEmpty) return _creditsData!.suppliers;

    final query = _searchQuery.toLowerCase();
    return _creditsData!.suppliers.where((s) {
      return s.displayName.toLowerCase().contains(query) ||
          s.phone.toLowerCase().contains(query) ||
          s.companyName.toLowerCase().contains(query);
    }).toList();
  }

  void _viewSupplierAccount(SupplierCredit supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierAccountScreen(
          supplierId: supplier.supplierId,
          supplierName: supplier.displayName,
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
        title: const Text('Supplier Credits'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Location selector - Leruma only
          if (isLeruma && locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            _buildLocationSelector(locationProvider),
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

            // Daily Reports Row
            _buildDailyReportsRow(isDark),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GlassmorphicCard(
                isDark: isDark,
                borderRadius: 12,
                padding: EdgeInsets.zero,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search supplier or company...',
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
                    Icon(Icons.local_shipping, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${_filteredSuppliers.length} suppliers',
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

            // Suppliers List
            Expanded(
              child: _isLoading
                  ? _buildSkeletonList(isDark)
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _filteredSuppliers.isEmpty
                          ? _buildEmptyView()
                          : _buildSuppliersList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelector(LocationProvider locationProvider) {
    return Center(
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
    );
  }

  Widget _buildDailyReportsRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Daily Credit Report Button
          Expanded(
            child: GlassmorphicCard(
              isDark: isDark,
              borderRadius: 12,
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupplierDailyCreditReportScreen()),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.receipt, color: AppColors.error, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Credit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Credit purchases',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Daily Debt Report Button
          Expanded(
            child: GlassmorphicCard(
              isDark: isDark,
              borderRadius: 12,
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupplierDailyDebtReportScreen()),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.payments, color: AppColors.success, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Debt',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Payments made',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
                        'Total Owed',
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

  Widget _buildSuppliersList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadCredits,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredSuppliers.length,
        itemBuilder: (context, index) {
          final supplier = _filteredSuppliers[index];
          return _buildSupplierCard(supplier, isDark, index + 1);
        },
      ),
    );
  }

  Widget _buildSupplierCard(SupplierCredit supplier, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 14,
        child: InkWell(
          onTap: () => _viewSupplierAccount(supplier),
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
                            supplier.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (supplier.phone.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.phone, size: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  supplier.phone,
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
                        child: _buildStatColumn('Credit', supplier.credit, AppColors.error, isDark),
                      ),
                      Container(
                        width: 1,
                        height: 35,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildStatColumn('Paid', supplier.debit, AppColors.success, isDark),
                      ),
                      Container(
                        width: 1,
                        height: 35,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildStatColumn('Balance', supplier.balance,
                          supplier.balance > 0 ? AppColors.error : AppColors.success, isDark, isBold: true),
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
          Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No suppliers with credit balance'
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

/// Screen to show individual supplier account details
class SupplierAccountScreen extends StatefulWidget {
  final int supplierId;
  final String supplierName;

  const SupplierAccountScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<SupplierAccountScreen> createState() => _SupplierAccountScreenState();
}

class _SupplierAccountScreenState extends State<SupplierAccountScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _formatter = NumberFormat('#,###');
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');

  SupplierAccountResponse? _accountData;
  bool _isLoading = true;
  String? _errorMessage;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getSupplierCreditorAccount(
      widget.supplierId,
      startDate: _dateFormat.format(_startDate),
      endDate: _dateFormat.format(_endDate),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _accountData = response.data;
        } else {
          _errorMessage = response.message ?? 'Failed to load account';
        }
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAccount();
    }
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => SupplierPaymentDialog(
        supplierId: widget.supplierId,
        supplierName: widget.supplierName,
        currentBalance: _accountData?.currentBalance ?? 0,
        onPaymentComplete: () {
          _loadAccount();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplierName),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccount,
            tooltip: 'Refresh',
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
      // Only show Add Payment button when there's a balance to pay
      // Uses suppliers_creditors_make_payment permission
      floatingActionButton: (_accountData?.currentBalance ?? 0) > 0
          ? PermissionFAB(
              permissionId: PermissionIds.suppliersCreditorsPayment,
              onPressed: _showPaymentDialog,
              backgroundColor: AppColors.success,
              tooltip: 'Add Payment',
              child: const Icon(Icons.payment, color: Colors.white),
            )
          : null,
      body: Container(
        color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorView()
                : _buildContent(isDark),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Range Selector
          GlassmorphicCard(
            isDark: isDark,
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: InkWell(
              onTap: _selectDateRange,
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date Range', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                        Text(
                          '${_displayDateFormat.format(_startDate)} - ${_displayDateFormat.format(_endDate)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_calendar, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Balance Summary
          if (_accountData != null)
            GlassmorphicCard(
              isDark: isDark,
              borderRadius: 14,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildBalanceItem('Total Credit', _accountData!.totalCredit, AppColors.error, isDark),
                      ),
                      Container(width: 1, height: 40, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      Expanded(
                        child: _buildBalanceItem('Total Paid', _accountData!.totalDebit, AppColors.success, isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (_accountData!.currentBalance > 0 ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Balance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          _formatter.format(_accountData!.currentBalance),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _accountData!.currentBalance > 0 ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Credit Transactions (Receivings on Credit)
          if (_accountData != null && _accountData!.creditTransactions.isNotEmpty) ...[
            Text(
              'Credit Purchases',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ..._accountData!.creditTransactions.map((t) => _buildCreditTransactionCard(t, isDark)),
          ],

          const SizedBox(height: 20),

          // Statement Transactions
          if (_accountData != null && _accountData!.transactions.isNotEmpty) ...[
            Text(
              'Statement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ..._accountData!.transactions.map((t) => _buildTransactionCard(t, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, double value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          _formatter.format(value),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildCreditTransactionCard(SupplierCreditTransaction trans, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 12,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text(
                      'RCV #${trans.receivingId}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Text(
                  trans.date,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildMiniStat('Credit', trans.credit, AppColors.error, isDark)),
                Expanded(child: _buildMiniStat('Paid', trans.paid, AppColors.success, isDark)),
                Expanded(child: _buildMiniStat('Balance', trans.balance,
                  trans.balance > 0 ? AppColors.error : AppColors.success, isDark, isBold: true)),
              ],
            ),
            if (trans.employeeName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    trans.employeeName,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(SupplierTransaction trans, bool isDark) {
    final isCredit = trans.credit > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 10,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isCredit ? AppColors.error : AppColors.success).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCredit ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: isCredit ? AppColors.error : AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trans.date,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (trans.description != null && trans.description!.isNotEmpty)
                    Text(
                      trans.description!,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}${_formatter.format(isCredit ? trans.credit : trans.debit)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? AppColors.error : AppColors.success,
                  ),
                ),
                Text(
                  'Bal: ${_formatter.format(trans.balance)}',
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, double value, Color color, bool isDark, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          _formatter.format(value),
          style: TextStyle(fontSize: isBold ? 12 : 11, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color),
        ),
      ],
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
            onPressed: _loadAccount,
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
}

/// Daily Credit Report Screen for Suppliers
class SupplierDailyCreditReportScreen extends StatefulWidget {
  const SupplierDailyCreditReportScreen({super.key});

  @override
  State<SupplierDailyCreditReportScreen> createState() => _SupplierDailyCreditReportScreenState();
}

class _SupplierDailyCreditReportScreenState extends State<SupplierDailyCreditReportScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _formatter = NumberFormat('#,###');
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');

  SupplierDailyCreditResponse? _reportData;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAndLoad());
  }

  Future<void> _initializeAndLoad() async {
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.initialize(moduleId: 'credits');
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final locationProvider = context.read<LocationProvider>();
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    List<int>? locationIds;
    if (isLeruma && locationProvider.selectedLocation != null) {
      locationIds = [locationProvider.selectedLocation!.locationId];
    } else if (locationProvider.allowedLocations.isNotEmpty) {
      locationIds = locationProvider.allowedLocations.map((loc) => loc.locationId).toList();
    }

    final response = await _apiService.getSupplierDailyCreditReport(
      startDate: _dateFormat.format(_startDate),
      endDate: _dateFormat.format(_endDate),
      locationIds: locationIds,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _reportData = response.data;
        } else {
          _errorMessage = response.message ?? 'Failed to load report';
        }
      });
    }
  }

  List<SupplierDailyCreditEntry> get _filteredCredits {
    if (_reportData == null) return [];
    if (_searchQuery.isEmpty) return _reportData!.credits;
    final query = _searchQuery.toLowerCase();
    return _reportData!.credits.where((c) =>
      c.displayName.toLowerCase().contains(query) ||
      c.employeeName.toLowerCase().contains(query)
    ).toList();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Credit Purchases'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isLeruma && locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            _buildLocationSelector(locationProvider),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReport),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
      body: Container(
        color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
        child: Column(
          children: [
            _buildDateRangeSelector(isDark),
            if (_reportData != null && !_isLoading) _buildSummaryCard(isDark),
            _buildSearchBar(isDark),
            if (_reportData != null && !_isLoading) _buildResultsCount(isDark),
            const SizedBox(height: 8),
            Expanded(child: _buildContent(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelector(LocationProvider locationProvider) {
    return Center(
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
                constraints: const BoxConstraints(maxWidth: 80),
                child: Text(
                  locationProvider.selectedLocation!.locationName,
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
            ],
          ),
          onSelected: (location) async {
            await locationProvider.selectLocation(location);
            _loadReport();
          },
          itemBuilder: (context) => locationProvider.allowedLocations
              .map((location) => PopupMenuItem<StockLocation>(
                    value: location,
                    child: Text(location.locationName),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: InkWell(
          onTap: _selectDateRange,
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date Range', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                    Text(
                      '${_displayDateFormat.format(_startDate)} - ${_displayDateFormat.format(_endDate)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_calendar, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final summary = _reportData!.summary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 14,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.receipt, color: AppColors.error, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Credit Purchases', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  Text(_formatter.format(summary.totalAmount), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.error)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
              child: Text('${summary.count} entries', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 12,
        padding: EdgeInsets.zero,
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search supplier, employee...',
            hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  Widget _buildResultsCount(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.receipt_long, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('${_filteredCredits.length} entries', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) return _buildSkeletonList(isDark);
    if (_errorMessage != null) return _buildErrorView();
    if (_filteredCredits.isEmpty) return _buildEmptyView();
    return _buildCreditsList(isDark);
  }

  Widget _buildCreditsList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredCredits.length,
        itemBuilder: (context, index) => _buildCreditCard(_filteredCredits[index], isDark, index + 1),
      ),
    );
  }

  Widget _buildCreditCard(SupplierDailyCreditEntry credit, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 12,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.error, AppColors.error.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(credit.displayName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      Row(children: [
                        Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(credit.date, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(_formatter.format(credit.amount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(child: _buildDetailItem('Receiving', '#${credit.receivingId}', isDark)),
                  Container(width: 1, height: 30, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                  Expanded(child: _buildDetailItem('Employee', credit.employeeName, isDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value.isNotEmpty ? value : '-', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: GlassmorphicCard(isDark: isDark, padding: const EdgeInsets.all(14), child: Column(children: [
          Row(children: [
            SkeletonLoader(width: 36, height: 36, borderRadius: 10, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonLoader(width: 120, height: 14, isDark: isDark),
              const SizedBox(height: 6),
              SkeletonLoader(width: 80, height: 10, isDark: isDark),
            ])),
          ]),
          const SizedBox(height: 10),
          SkeletonLoader(width: double.infinity, height: 50, borderRadius: 8, isDark: isDark),
        ])),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 64, color: AppColors.error),
      const SizedBox(height: 16),
      Text(_errorMessage ?? 'An error occurred', style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _loadReport, icon: const Icon(Icons.refresh), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
    ]));
  }

  Widget _buildEmptyView() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
      const SizedBox(height: 16),
      Text(_searchQuery.isEmpty ? 'No credit purchases for this period' : 'No results found', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
    ]));
  }
}

/// Daily Debt Report Screen for Suppliers (payments made to suppliers)
class SupplierDailyDebtReportScreen extends StatefulWidget {
  const SupplierDailyDebtReportScreen({super.key});

  @override
  State<SupplierDailyDebtReportScreen> createState() => _SupplierDailyDebtReportScreenState();
}

class _SupplierDailyDebtReportScreenState extends State<SupplierDailyDebtReportScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _formatter = NumberFormat('#,###');
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');

  SupplierDailyDebtResponse? _reportData;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAndLoad());
  }

  Future<void> _initializeAndLoad() async {
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.initialize(moduleId: 'credits');
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final locationProvider = context.read<LocationProvider>();
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    List<int>? locationIds;
    if (isLeruma && locationProvider.selectedLocation != null) {
      locationIds = [locationProvider.selectedLocation!.locationId];
    } else if (locationProvider.allowedLocations.isNotEmpty) {
      locationIds = locationProvider.allowedLocations.map((loc) => loc.locationId).toList();
    }

    final response = await _apiService.getSupplierDailyDebtReport(
      startDate: _dateFormat.format(_startDate),
      endDate: _dateFormat.format(_endDate),
      locationIds: locationIds,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _reportData = response.data;
        } else {
          _errorMessage = response.message ?? 'Failed to load report';
        }
      });
    }
  }

  List<SupplierDailyDebtEntry> get _filteredDebts {
    if (_reportData == null) return [];
    if (_searchQuery.isEmpty) return _reportData!.debts;
    final query = _searchQuery.toLowerCase();
    return _reportData!.debts.where((d) =>
      d.supplierName.toLowerCase().contains(query) ||
      d.employeeName.toLowerCase().contains(query)
    ).toList();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments to Suppliers'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isLeruma && locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            _buildLocationSelector(locationProvider),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReport),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
      body: Container(
        color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
        child: Column(
          children: [
            _buildDateRangeSelector(isDark),
            if (_reportData != null && !_isLoading) _buildSummaryCard(isDark),
            _buildSearchBar(isDark),
            if (_reportData != null && !_isLoading) _buildResultsCount(isDark),
            const SizedBox(height: 8),
            Expanded(child: _buildContent(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelector(LocationProvider locationProvider) {
    return Center(
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
                constraints: const BoxConstraints(maxWidth: 80),
                child: Text(
                  locationProvider.selectedLocation!.locationName,
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
            ],
          ),
          onSelected: (location) async {
            await locationProvider.selectLocation(location);
            _loadReport();
          },
          itemBuilder: (context) => locationProvider.allowedLocations
              .map((location) => PopupMenuItem<StockLocation>(
                    value: location,
                    child: Text(location.locationName),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: InkWell(
          onTap: _selectDateRange,
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date Range', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                    Text(
                      '${_displayDateFormat.format(_startDate)} - ${_displayDateFormat.format(_endDate)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_calendar, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final summary = _reportData!.summary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 14,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.payments, color: AppColors.success, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Payments Made', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  Text(_formatter.format(summary.totalAmount), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
              child: Text('${summary.count} payments', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 12,
        padding: EdgeInsets.zero,
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search supplier, employee...',
            hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  Widget _buildResultsCount(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.receipt_long, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('${_filteredDebts.length} payments', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) return _buildSkeletonList(isDark);
    if (_errorMessage != null) return _buildErrorView();
    if (_filteredDebts.isEmpty) return _buildEmptyView();
    return _buildDebtsList(isDark);
  }

  Widget _buildDebtsList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredDebts.length,
        itemBuilder: (context, index) => _buildDebtCard(_filteredDebts[index], isDark, index + 1),
      ),
    );
  }

  Widget _buildDebtCard(SupplierDailyDebtEntry debt, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 12,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.success, AppColors.success.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(debt.supplierName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      Row(children: [
                        Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(debt.date, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(_formatter.format(debt.amount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(child: _buildDetailItem('Employee', debt.employeeName, isDark)),
                  Container(width: 1, height: 30, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                  Expanded(child: _buildDetailItem('Description', debt.description.isNotEmpty ? debt.description : '-', isDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value.isNotEmpty ? value : '-', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: GlassmorphicCard(isDark: isDark, padding: const EdgeInsets.all(14), child: Column(children: [
          Row(children: [
            SkeletonLoader(width: 36, height: 36, borderRadius: 10, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonLoader(width: 120, height: 14, isDark: isDark),
              const SizedBox(height: 6),
              SkeletonLoader(width: 80, height: 10, isDark: isDark),
            ])),
          ]),
          const SizedBox(height: 10),
          SkeletonLoader(width: double.infinity, height: 50, borderRadius: 8, isDark: isDark),
        ])),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 64, color: AppColors.error),
      const SizedBox(height: 16),
      Text(_errorMessage ?? 'An error occurred', style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _loadReport, icon: const Icon(Icons.refresh), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
    ]));
  }

  Widget _buildEmptyView() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
      const SizedBox(height: 16),
      Text(_searchQuery.isEmpty ? 'No payments for this period' : 'No results found', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
    ]));
  }
}

/// Dialog for adding payment to supplier
class SupplierPaymentDialog extends StatefulWidget {
  final int supplierId;
  final String supplierName;
  final double currentBalance;
  final VoidCallback onPaymentComplete;

  const SupplierPaymentDialog({
    super.key,
    required this.supplierId,
    required this.supplierName,
    required this.currentBalance,
    required this.onPaymentComplete,
  });

  @override
  State<SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends State<SupplierPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ApiService _apiService = ApiService();
  final NumberFormat _formatter = NumberFormat('#,###');

  bool _isSubmitting = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    final formData = SupplierPaymentFormData(
      supplierId: widget.supplierId,
      amount: amount,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      paymentMode: 1,
      paidPaymentType: 2, // Bank payment by default for suppliers
    );

    final response = await _apiService.addSupplierCreditorPayment(formData);

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (response.isSuccess) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment added successfully')),
        );
        widget.onPaymentComplete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? 'Failed to add payment')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionProvider = context.watch<PermissionProvider>();
    final canEditDate = permissionProvider.hasPermission(PermissionIds.suppliersCreditorsEditDate);

    return AlertDialog(
      title: const Text('Add Payment'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Supplier info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.supplierName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Balance: ${_formatter.format(widget.currentBalance)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount *',
                  border: OutlineInputBorder(),
                  prefixText: 'TSh ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter payment amount';
                  }
                  final amount = double.tryParse(value.replaceAll(',', ''));
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount > widget.currentBalance) {
                    return 'Payment cannot exceed balance of ${_formatter.format(widget.currentBalance)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date field - only show if user has suppliers_creditors_edit_date permission
              if (canEditDate) ...[
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Payment Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Description field
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Payment'),
        ),
      ],
    );
  }
}
