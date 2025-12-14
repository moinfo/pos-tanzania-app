import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/location_provider.dart';
import '../models/stock_location.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/glassmorphic_card.dart';

/// Seller Report Screen - Leruma specific
/// Shows seller/supervisor performance data by stock location
/// NOTE: This screen is ONLY for Leruma client
class SellerReportScreen extends StatefulWidget {
  const SellerReportScreen({super.key});

  @override
  State<SellerReportScreen> createState() => _SellerReportScreenState();
}

class _SellerReportScreenState extends State<SellerReportScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _sellers = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  bool _isAdmin = false;
  StockLocation? _selectedLocation;

  /// Check if current client is Leruma
  bool get _isLeruma => ApiService.currentClient?.id == 'leruma';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only initialize if Leruma client
      if (_isLeruma) {
        _initializeLocation();
      }
    });
  }

  Future<void> _initializeLocation() async {
    final locationProvider = context.read<LocationProvider>();

    // Load locations if not already loaded (use same module as Items screen)
    if (locationProvider.allowedLocations.isEmpty) {
      await locationProvider.initialize();
    }

    // Use LocationProvider's selected location or first available
    if (locationProvider.allowedLocations.isNotEmpty && _selectedLocation == null) {
      setState(() {
        _selectedLocation = locationProvider.selectedLocation ?? locationProvider.allowedLocations.first;
      });
    }

    _loadSellersReport();
  }

  Future<void> _loadSellersReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dateStr = Formatters.formatDateForApi(_selectedDate);

    final result = await _apiService.getSellersReport(
      startDate: dateStr,
      endDate: dateStr,
      locationId: _selectedLocation?.locationId,
    );

    setState(() {
      if (result.isSuccess && result.data != null) {
        _sellers = List<Map<String, dynamic>>.from(result.data!['sellers'] ?? []);
        _isAdmin = result.data!['is_admin'] ?? false;
        _errorMessage = null;
      } else {
        _sellers = [];
        _errorMessage = result.message ?? 'Failed to load sellers report';
      }
      _isLoading = false;
    });
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      _loadSellersReport();
    }
  }

  void _showLocationPicker() {
    final locationProvider = context.read<LocationProvider>();
    final locations = locationProvider.allowedLocations;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final themeProvider = context.watch<ThemeProvider>();
        final isDark = themeProvider.isDarkMode;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
              ),
              const Divider(height: 1),
              // "All Locations" option for admin
              ListTile(
                leading: Icon(
                  Icons.all_inclusive,
                  color: _selectedLocation == null ? AppColors.primary : (isDark ? AppColors.darkTextLight : AppColors.textLight),
                ),
                title: Text(
                  'All Locations',
                  style: TextStyle(
                    color: isDark ? AppColors.darkText : AppColors.text,
                    fontWeight: _selectedLocation == null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: _selectedLocation == null
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedLocation = null;
                  });
                  Navigator.pop(context);
                  _loadSellersReport();
                },
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final location = locations[index];
                    final isSelected = _selectedLocation?.locationId == location.locationId;

                    return ListTile(
                      leading: Icon(
                        Icons.store,
                        color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextLight : AppColors.textLight),
                      ),
                      title: Text(
                        location.locationName,
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : AppColors.text,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedLocation = location;
                        });
                        Navigator.pop(context);
                        _loadSellersReport();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    // Block access for non-Leruma clients
    if (!_isLeruma) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Seller Report'),
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                ),
                const SizedBox(height: 16),
                Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This feature is only available for Leruma.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Report'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Location selector
          IconButton(
            icon: const Icon(Icons.store),
            onPressed: _showLocationPicker,
            tooltip: _selectedLocation?.locationName ?? 'Select Location',
          ),
          // Date selector
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeletonLoading(isDark)
          : _errorMessage != null
              ? _buildErrorView(isDark)
              : _sellers.isEmpty
                  ? _buildEmptyView(isDark)
                  : _buildContent(isDark),
    );
  }

  Widget _buildSkeletonLoading(bool isDark) {
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header skeleton
          _buildSkeletonHeader(isDark),
          const SizedBox(height: 16),
          // Seller card skeletons
          _buildSkeletonSellerCard(isDark),
          const SizedBox(height: 12),
          _buildSkeletonSellerCard(isDark),
        ],
      ),
    );
  }

  Widget _buildSkeletonHeader(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Location row skeleton
            Row(
              children: [
                _buildShimmerBox(40, 40, isDark, borderRadius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(80, 12, isDark),
                      const SizedBox(height: 6),
                      _buildShimmerBox(120, 16, isDark),
                    ],
                  ),
                ),
                _buildShimmerBox(70, 30, isDark, borderRadius: 16),
              ],
            ),
            const SizedBox(height: 12),
            // Date row skeleton
            Row(
              children: [
                _buildShimmerBox(40, 40, isDark, borderRadius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(70, 12, isDark),
                      const SizedBox(height: 6),
                      _buildShimmerBox(100, 16, isDark),
                    ],
                  ),
                ),
                _buildShimmerBox(60, 28, isDark, borderRadius: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonSellerCard(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            Row(
              children: [
                _buildShimmerBox(44, 44, isDark, borderRadius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(150, 16, isDark),
                      const SizedBox(height: 6),
                      _buildShimmerBox(100, 12, isDark),
                    ],
                  ),
                ),
                _buildShimmerBox(80, 32, isDark, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 16),
            // Stats row skeleton
            Row(
              children: [
                Expanded(child: _buildShimmerBox(double.infinity, 50, isDark, borderRadius: 8)),
                const SizedBox(width: 6),
                Expanded(child: _buildShimmerBox(double.infinity, 50, isDark, borderRadius: 8)),
                const SizedBox(width: 6),
                Expanded(child: _buildShimmerBox(double.infinity, 50, isDark, borderRadius: 8)),
                const SizedBox(width: 6),
                Expanded(child: _buildShimmerBox(double.infinity, 50, isDark, borderRadius: 8)),
              ],
            ),
            const SizedBox(height: 16),
            // Section skeleton
            _buildShimmerBox(100, 14, isDark),
            const SizedBox(height: 12),
            ...List.generate(4, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildShimmerBox(100, 14, isDark),
                  _buildShimmerBox(80, 14, isDark),
                ],
              ),
            )),
            const SizedBox(height: 8),
            // Another section skeleton
            _buildShimmerBox(80, 14, isDark),
            const SizedBox(height: 12),
            ...List.generate(3, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildShimmerBox(90, 14, isDark),
                  _buildShimmerBox(70, 14, isDark),
                ],
              ),
            )),
            const SizedBox(height: 12),
            // Summary skeleton
            _buildShimmerBox(double.infinity, 48, isDark, borderRadius: 8),
            const SizedBox(height: 8),
            _buildShimmerBox(double.infinity, 48, isDark, borderRadius: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox(double width, double height, bool isDark, {double borderRadius = 4}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: value * 0.15),
                      Colors.white.withValues(alpha: 0.05),
                    ]
                  : [
                      Colors.grey.withValues(alpha: 0.1),
                      Colors.grey.withValues(alpha: value * 0.25),
                      Colors.grey.withValues(alpha: 0.1),
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
      onEnd: () {
        // Restart animation
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSellersReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No seller data for this date',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          if (_selectedLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Location: ${_selectedLocation!.locationName}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
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
        onRefresh: _loadSellersReport,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Location & Date header
            GlassmorphicCard(
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Location row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.store, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stock Location',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                ),
                              ),
                              Text(
                                _selectedLocation?.locationName ?? 'All Locations',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkText : AppColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _showLocationPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Change',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Date row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calendar_today, color: AppColors.success, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report Date',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM yyyy').format(_selectedDate),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkText : AppColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_sellers.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_sellers.length} Seller${_sellers.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sellers list - one per row
            ..._sellers.map((seller) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSellerCard(seller, isDark),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerCard(Map<String, dynamic> seller, bool isDark) {
    final supervisorName = seller['supervisor_name'] ?? 'Unknown';
    final locationName = seller['location_name'] ?? '';

    // Stock & Customer stats
    final unbalanceStock = (seller['unbalance_stock'] as num?)?.toDouble() ?? 0;
    final totalCustomers = seller['total_customers'] ?? 0;
    final customersServed = seller['customers_served'] ?? 0;
    final newCustomers = seller['new_customers'] ?? 0;

    // MS & Receiving
    final ms = (seller['ms'] as num?)?.toDouble() ?? 0;
    final receiving = (seller['receiving'] as num?)?.toDouble() ?? 0;
    final msR = (seller['ms_r'] as num?)?.toDouble() ?? 0;

    // Sales data
    final allSales = (seller['all_sales'] as num?)?.toDouble() ?? 0;
    final offerDiscount = (seller['do'] as num?)?.toDouble() ?? 0;
    final rSdo = (seller['r_s_do'] as num?)?.toDouble() ?? 0;
    final cashSales = (seller['cash_sales'] as num?)?.toDouble() ?? 0;
    final creditSales = (seller['credit_sales'] as num?)?.toDouble() ?? 0;
    final turnover = (seller['turnover'] as num?)?.toDouble() ?? 0;
    final discount = (seller['discount'] as num?)?.toDouble() ?? 0;
    final customerDebit = (seller['customer_debit'] as num?)?.toDouble() ?? 0;

    // Financial
    final chipDeposited = (seller['chip_deposited'] as num?)?.toDouble() ?? 0;
    final chipUsed = (seller['chip_used'] as num?)?.toDouble() ?? 0;
    final expenses = (seller['expenses'] as num?)?.toDouble() ?? 0;
    final bankAmount = (seller['bank_amount'] as num?)?.toDouble() ?? 0;
    final directDeposit = (seller['direct_deposit'] as num?)?.toDouble() ?? 0;
    final differenceDeposit = (seller['difference_deposit'] as num?)?.toDouble() ?? 0;
    final bankDifference = (seller['bank_difference'] as num?)?.toDouble() ?? 0;
    final banking = (seller['banking'] as num?)?.toDouble() ?? 0;
    final gainLoss = (seller['gain_loss'] as num?)?.toDouble() ?? 0;
    final totalDifferences = (seller['total_differences'] as num?)?.toDouble() ?? 0;
    final profit = (seller['profit'] as num?)?.toDouble() ?? 0;

    // Supplier & Returns
    final supplierBank = (seller['supplier_bank'] as num?)?.toDouble() ?? 0;
    final receivingReturn = (seller['receiving_return'] as num?)?.toDouble() ?? 0;
    final bongeSalesReturn = (seller['bonge_sales_return'] as num?)?.toDouble() ?? 0;
    final supplierCredits = (seller['supplier_credits'] as num?)?.toDouble() ?? 0;
    final salesReturn = (seller['sales_return'] as num?)?.toDouble() ?? 0;
    final returnDifference = (seller['return_difference'] as num?)?.toDouble() ?? 0;

    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with supervisor name and location
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    supervisorName.isNotEmpty ? supervisorName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supervisorName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                      if (locationName.isNotEmpty)
                        Text(
                          locationName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
                // Gain/Loss indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: gainLoss >= 0
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    Formatters.formatCurrency(gainLoss),
                    style: TextStyle(
                      color: gainLoss >= 0 ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stock & Customer stats row
            Row(
              children: [
                _buildStatChip('Unbal', unbalanceStock.toStringAsFixed(0), Icons.inventory, isDark),
                const SizedBox(width: 6),
                _buildStatChip('Total', totalCustomers.toString(), Icons.people, isDark),
                const SizedBox(width: 6),
                _buildStatChip('Served', customersServed.toString(), Icons.check_circle, isDark),
                const SizedBox(width: 6),
                _buildStatChip('New', newCustomers.toString(), Icons.person_add, isDark),
              ],
            ),
            const Divider(height: 24),

            // MS & Receiving section
            _buildSectionHeader('MS & Receiving', isDark),
            const SizedBox(height: 8),
            _buildDataRow('MS', ms, isDark),
            _buildDataRow('Receiving', receiving, isDark),
            _buildDataRow('MS-R', msR, isDark),
            const Divider(height: 16),

            // Sales section
            _buildSectionHeader('Sales', isDark),
            const SizedBox(height: 8),
            _buildDataRow('All Sales', allSales, isDark),
            _buildDataRow('DO', offerDiscount, isDark),
            _buildDataRow('R-S-DO', rSdo, isDark),
            _buildDataRow('Cash Sales', cashSales, isDark),
            _buildDataRow('Credit Sales', creditSales, isDark),
            _buildDataRow('Turnover', turnover, isDark),
            _buildDataRow('Sales Discount', discount, isDark, isNegative: true),
            _buildDataRow('Debit Sales', customerDebit, isDark),
            const Divider(height: 16),

            // Financial section
            _buildSectionHeader('Financial', isDark),
            const SizedBox(height: 8),
            _buildDataRow('Chip Deposited', chipDeposited, isDark),
            _buildDataRow('Chip Used', chipUsed, isDark, isNegative: true),
            _buildDataRow('Expenses', expenses, isDark, isNegative: true),
            _buildDataRow('Bank Amount', bankAmount, isDark),
            _buildDataRow('Direct Deposit', directDeposit, isDark),
            _buildDataRow('Difference Deposit', differenceDeposit, isDark),
            _buildDataRow('Bank Difference', bankDifference, isDark),
            _buildDataRow('Banking', banking, isDark),
            const Divider(height: 16),

            // Supplier & Returns section
            _buildSectionHeader('Supplier & Returns', isDark),
            const SizedBox(height: 8),
            _buildDataRow('Supplier Bank', supplierBank, isDark),
            _buildDataRow('Receiving Return', receivingReturn, isDark, isNegative: true),
            _buildDataRow('Bonge Sales Return', bongeSalesReturn, isDark, isNegative: true),
            _buildDataRow('Supplier Credits', supplierCredits, isDark),
            _buildDataRow('Sales Return', salesReturn, isDark, isNegative: true),
            _buildDataRow('Return Difference', returnDifference, isDark),
            const Divider(height: 16),

            // Summary
            _buildHighlightRow('Gain/Loss', gainLoss, isDark,
                color: gainLoss >= 0 ? AppColors.success : AppColors.error),
            _buildHighlightRow('Total Differences', totalDifferences, isDark,
                color: totalDifferences > 1000 ? AppColors.error : (totalDifferences > 100 ? Colors.orange : AppColors.success)),
            _buildHighlightRow('Profit', profit, isDark,
                color: profit >= 0 ? AppColors.success : AppColors.error),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.text,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
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

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDataRow(String label, double value, bool isDark, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
          Text(
            Formatters.formatCurrency(isNegative ? -value.abs() : value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isNegative ? AppColors.error : (isDark ? AppColors.darkText : AppColors.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightRow(String label, double value, bool isDark, {Color? color}) {
    final displayColor = color ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: displayColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: displayColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: displayColor,
                ),
              ),
            ],
          ),
          Text(
            Formatters.formatCurrency(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: displayColor,
            ),
          ),
        ],
      ),
    );
  }
}
