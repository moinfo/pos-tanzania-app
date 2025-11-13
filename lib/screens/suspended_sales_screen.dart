import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/sale.dart';
import '../models/stock_location.dart';
import '../providers/sale_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/location_provider.dart';
import '../utils/constants.dart';
import '../widgets/app_bottom_navigation.dart';

class SuspendedSalesScreen extends StatefulWidget {
  const SuspendedSalesScreen({super.key});

  @override
  State<SuspendedSalesScreen> createState() => _SuspendedSalesScreenState();
}

class _SuspendedSalesScreenState extends State<SuspendedSalesScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

  List<SuspendedSale> _suspendedSales = [];
  bool _isLoading = false;

  // Date range filter - Initialize to last 30 days
  String? _startDate;
  String? _endDate;

  String get startDate {
    if (_startDate == null || _startDate!.isEmpty) {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      _startDate = DateFormat('yyyy-MM-dd').format(thirtyDaysAgo);
    }
    return _startDate!;
  }

  String get endDate {
    if (_endDate == null || _endDate!.isEmpty) {
      final now = DateTime.now();
      _endDate = DateFormat('yyyy-MM-dd').format(now);
    }
    return _endDate!;
  }

  @override
  void initState() {
    super.initState();
    // Defer location initialization until after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;
    final locationProvider = context.read<LocationProvider>();
    // Initialize for sales module to get sales-specific locations
    await locationProvider.initialize(moduleId: 'sales');
    // Load suspended sales after location is initialized
    _loadSuspendedSales();
  }

  Future<void> _loadSuspendedSales() async {
    setState(() => _isLoading = true);

    try {
      final locationProvider = context.read<LocationProvider>();
      final selectedLocationId = locationProvider.selectedLocation?.locationId;

      final response = await _apiService.getSuspendedSales(
        locationId: selectedLocationId,
        startDate: startDate,
        endDate: endDate,
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _suspendedSales = response.data!;
          // Sort by date descending (newest first)
          _suspendedSales.sort((a, b) =>
            DateTime.parse(b.saleTime).compareTo(DateTime.parse(a.saleTime))
          );
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        // Only show error if it's not a format exception (which might be from other API calls)
        if (mounted && !response.message.contains('FormatException')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // Silently handle errors - don't show to user
      print('Error loading suspended sales: $e');
    }
  }

  Future<void> _resumeSale(SuspendedSale sale) async {
    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Get sale details
    final response = await _apiService.getSaleDetails(sale.saleId);

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (response.isSuccess && response.data != null) {
      final saleProvider = context.read<SaleProvider>();

      // Load sale into cart
      saleProvider.clearCart();

      // Set customer
      if (sale.customerId != null) {
        // We'll need to load the customer details
        // For now, just set the ID - the provider should handle loading customer
        // This is a simplification - you may need to fetch customer details from API
      }

      // Add items to cart
      for (final item in response.data!.items ?? []) {
        saleProvider.addSaleItem(item);
      }

      // Delete the suspended sale after loading
      await _apiService.deleteSuspendedSale(sale.saleId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale resumed successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate back to sales screen
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resume sale: ${response.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateFormat apiFormat = DateFormat('yyyy-MM-dd');

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.parse(startDate),
        end: DateTime.parse(endDate),
      ),
      builder: (context, child) {
        final themeProvider = context.read<ThemeProvider>();
        final isDark = themeProvider.isDarkMode;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.darkCard,
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = apiFormat.format(picked.start);
        _endDate = apiFormat.format(picked.end);
      });
      _loadSuspendedSales();
    }
  }

  void _setDateRangePreset(String preset) {
    final now = DateTime.now();
    final DateFormat apiFormat = DateFormat('yyyy-MM-dd');

    setState(() {
      switch (preset) {
        case 'today':
          _startDate = apiFormat.format(now);
          _endDate = apiFormat.format(now);
          break;
        case 'week':
          _startDate = apiFormat.format(now.subtract(const Duration(days: 7)));
          _endDate = apiFormat.format(now);
          break;
        case 'month':
          _startDate = apiFormat.format(now.subtract(const Duration(days: 30)));
          _endDate = apiFormat.format(now);
          break;
      }
    });
    _loadSuspendedSales();
  }

  Future<void> _deleteSale(SuspendedSale sale) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Suspended Sale'),
        content: Text('Are you sure you want to delete sale #${sale.saleId}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final response = await _apiService.deleteSuspendedSale(sale.saleId);

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (response.isSuccess) {
      setState(() {
        _suspendedSales.removeWhere((s) => s.saleId == sale.saleId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete sale: ${response.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suspended Sales'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Location selector
          if (locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PopupMenuButton<StockLocation>(
                  offset: const Offset(0, 40),
                  color: isDark ? AppColors.darkCard : Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        locationProvider.selectedLocation!.locationName,
                        style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 20, color: Colors.white),
                    ],
                  ),
                  onSelected: (location) async {
                    await locationProvider.selectLocation(location);
                    _loadSuspendedSales(); // Reload for new location
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
                                    color: isDark ? Colors.white : Colors.black87,
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
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSuspendedSales,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range display and quick filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppColors.darkCard : Colors.white,
            child: Column(
              children: [
                // Current date range display
                InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: isDark ? Colors.white70 : Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('MMM dd, yyyy').format(DateTime.parse(startDate))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(endDate))}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Quick filter buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickFilterButton('Today', 'today', isDark),
                    _buildQuickFilterButton('This Week', 'week', isDark),
                    _buildQuickFilterButton('This Month', 'month', isDark),
                  ],
                ),
              ],
            ),
          ),
          // Sales list
          Expanded(
            child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _suspendedSales.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pause_circle_outline,
                        size: 80,
                        color: isDark ? AppColors.darkTextLight : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No suspended sales',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? AppColors.darkText : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Suspend a sale to see it here',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextLight : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSuspendedSales,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _suspendedSales.length,
                    itemBuilder: (context, index) {
                      final sale = _suspendedSales[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _resumeSale(sale),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.pause_circle,
                                                size: 16,
                                                color: AppColors.warning,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Sale #${sale.saleId}',
                                                style: TextStyle(
                                                  color: AppColors.warning,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                      onPressed: () => _deleteSale(sale),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Customer & Employee
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Customer',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            sale.customerName ?? 'Walk-in',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Employee',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            sale.employeeName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Date & Time
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      _dateFormat.format(DateTime.parse(sale.saleTime)),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),

                                // Comment if any
                                if (sale.comment != null && sale.comment!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.comment, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            sale.comment!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const Divider(height: 24),

                                // Items & Amount
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.shopping_cart, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${sale.itemCount} item${sale.itemCount > 1 ? 's' : ''}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${_currencyFormat.format(sale.subtotal)} TSh',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Resume button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _resumeSale(sale),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Resume Sale'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildQuickFilterButton(String label, String preset, bool isDark) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          onPressed: () => _setDateRangePreset(preset),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white : AppColors.primary,
            side: BorderSide(color: isDark ? Colors.grey.shade700 : AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }
}
