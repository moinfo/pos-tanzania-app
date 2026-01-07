import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../models/sale.dart';
import '../models/stock_location.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import '../widgets/app_bottom_navigation.dart';
import 'package:intl/intl.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
  final TextEditingController _searchController = TextEditingController();

  List<Sale> _sales = [];
  List<Sale> _filteredSales = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  String _startDate = '';
  String _endDate = '';
  String _searchQuery = '';
  String _paymentFilter = 'All'; // All, Cash, Credit Card

  @override
  void initState() {
    super.initState();
    // Default to today
    final now = DateTime.now();
    _startDate = DateFormat('yyyy-MM-dd').format(now);
    _endDate = DateFormat('yyyy-MM-dd').format(now);
    // Initialize location after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
    _loadSales();
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;
    final locationProvider = context.read<LocationProvider>();
    // Initialize for sales module to get sales-specific locations
    await locationProvider.initialize(moduleId: 'sales');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSales() {
    setState(() {
      _filteredSales = _sales.where((sale) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            (sale.customerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

        // Payment type filter
        final matchesPayment = _paymentFilter == 'All' ||
            (sale.paymentType?.toLowerCase().contains(_paymentFilter.toLowerCase()) ?? false);

        return matchesSearch && matchesPayment;
      }).toList();
    });
  }

  Future<void> _loadSales({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _sales.clear();
        _offset = 0;
        _hasMore = true;
      }
    });

    final locationProvider = context.read<LocationProvider>();
    final selectedLocationId = locationProvider.selectedLocation?.locationId;

    final response = await _apiService.getSales(
      startDate: _startDate,
      endDate: _endDate,
      limit: _limit,
      offset: _offset,
      locationId: selectedLocationId,
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      final salesList = (data['sales'] as List)
          .map((s) => Sale.fromJson(s as Map<String, dynamic>))
          .toList();

      setState(() {
        _sales.addAll(salesList);
        _offset += salesList.length;
        _hasMore = salesList.length >= _limit;
        _isLoading = false;
      });
      _filterSales();
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message)),
        );
      }
    }
  }

  void _setDateFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      switch (filter) {
        case 'today':
          _startDate = DateFormat('yyyy-MM-dd').format(now);
          _endDate = DateFormat('yyyy-MM-dd').format(now);
          break;
        case 'week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          _startDate = DateFormat('yyyy-MM-dd').format(weekStart);
          _endDate = DateFormat('yyyy-MM-dd').format(now);
          break;
        case 'month':
          _startDate = DateFormat('yyyy-MM-01').format(now);
          _endDate = DateFormat('yyyy-MM-dd').format(now);
          break;
      }
    });
    _loadSales(refresh: true);
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.parse(_startDate),
        end: DateTime.parse(_endDate),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateFormat('yyyy-MM-dd').format(picked.start);
        _endDate = DateFormat('yyyy-MM-dd').format(picked.end);
      });
      _loadSales(refresh: true);
    }
  }

  Future<void> _viewSaleDetails(Sale sale) async {
    // Load full sale details
    final response = await _apiService.getSaleDetails(sale.saleId!);

    if (response.isSuccess && response.data != null) {
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => SaleDetailsSheet(sale: response.data!),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message)),
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
        title: const Text('Sales History'),
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
                    _loadSales(refresh: true); // Reload sales for new location
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
                                        ? (isDark ? AppColors.darkText : AppColors.primary)
                                        : (isDark ? AppColors.darkText : Colors.black87),
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
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range display
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withOpacity(0.1),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(DateTime.parse(_startDate))} - '
                      '${DateFormat('MMM dd, yyyy').format(DateTime.parse(_endDate))}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Quick filter buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FilterChip(
                      label: 'Today',
                      onTap: () => _setDateFilter('today'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'This Week',
                      onTap: () => _setDateFilter('week'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'This Month',
                      onTap: () => _setDateFilter('month'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by customer name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _filterSales();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _filterSales();
                  },
                ),
                const SizedBox(height: 12),
                // Payment type filter
                Row(
                  children: [
                    const Text(
                      'Payment: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _PaymentFilterChip(
                              label: 'All',
                              isSelected: _paymentFilter == 'All',
                              onTap: () {
                                setState(() => _paymentFilter = 'All');
                                _filterSales();
                              },
                            ),
                            const SizedBox(width: 8),
                            _PaymentFilterChip(
                              label: 'Cash',
                              isSelected: _paymentFilter == 'Cash',
                              onTap: () {
                                setState(() => _paymentFilter = 'Cash');
                                _filterSales();
                              },
                            ),
                            const SizedBox(width: 8),
                            _PaymentFilterChip(
                              label: 'Credit Card',
                              isSelected: _paymentFilter == 'Credit Card',
                              onTap: () {
                                setState(() => _paymentFilter = 'Credit Card');
                                _filterSales();
                              },
                            ),
                            const SizedBox(width: 8),
                            _PaymentFilterChip(
                              label: 'LIPA NAMBA',
                              isSelected: _paymentFilter == 'LIPA NAMBA',
                              onTap: () {
                                setState(() => _paymentFilter = 'LIPA NAMBA');
                                _filterSales();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sales summary
          if (_sales.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryCard(
                    label: _paymentFilter != 'All' ? '$_paymentFilter Sales' : 'Total Sales',
                    value: (_paymentFilter != 'All' || _searchQuery.isNotEmpty)
                        ? _filteredSales.length.toString()
                        : _sales.length.toString(),
                    icon: Icons.receipt_long,
                  ),
                  _SummaryCard(
                    label: _paymentFilter != 'All' ? '$_paymentFilter Amount' : 'Total Amount',
                    value: '${_currencyFormat.format((_paymentFilter != 'All' || _searchQuery.isNotEmpty) ? _filteredSales.fold<double>(0, (sum, s) => sum + s.total) : _sales.fold<double>(0, (sum, s) => sum + s.total))} TSh',
                    icon: Icons.attach_money,
                  ),
                ],
              ),
            ),

          // Sales list
          Expanded(
            child: _sales.isEmpty && !_isLoading
                ? const Center(
                    child: Text('No sales found for this period'),
                  )
                : (_searchQuery.isNotEmpty || _paymentFilter != 'All') && _filteredSales.isEmpty
                    ? const Center(
                        child: Text('No sales match your search/filter'),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadSales(refresh: true),
                        child: ListView.builder(
                          itemCount: (_searchQuery.isNotEmpty || _paymentFilter != 'All'
                              ? _filteredSales.length
                              : _sales.length + (_hasMore ? 1 : 0)),
                          itemBuilder: (context, index) {
                            final displayList = (_searchQuery.isNotEmpty || _paymentFilter != 'All')
                                ? _filteredSales
                                : _sales;

                            if (index == _sales.length && (_searchQuery.isEmpty && _paymentFilter == 'All')) {
                              // Load more indicator (only when not filtering)
                              if (!_isLoading) {
                                _loadSales();
                              }
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final sale = displayList[index];
                            // Check if sale has any offer items (from API response)
                            final hasOfferItems = sale.hasOfferItems == true;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          color: isDark ? AppColors.darkCard : Colors.white,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              radius: 24,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '#${sale.saleId}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sale.customerName ?? 'Walk-in',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.darkText : AppColors.text,
                                    ),
                                  ),
                                ),
                                if (hasOfferItems)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.card_giftcard,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'OFFER',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _dateFormat.format(DateTime.parse(sale.saleTime)),
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                                  ),
                                ),
                                if (sale.paymentType != null)
                                  Text(
                                    sale.paymentType!,
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_currencyFormat.format(sale.total)} TSh',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                                _getSaleStatusBadge(sale.saleStatus),
                              ],
                            ),
                            onTap: () => _viewSaleDetails(sale),
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

  Widget _getSaleStatusBadge(int status) {
    String text;
    Color color;

    switch (status) {
      case 0:
        text = 'Completed';
        color = AppColors.success;
        break;
      case 2:
        text = 'Suspended';
        color = AppColors.warning;
        break;
      default:
        text = 'Unknown';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Sale Details Bottom Sheet
class SaleDetailsSheet extends StatelessWidget {
  final Sale sale;

  const SaleDetailsSheet({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'en_US');
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sale #${sale.saleId}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                    Row(
                      children: [
                        // Print button
                        IconButton(
                          icon: Icon(Icons.print, color: AppColors.primary),
                          tooltip: 'Print Receipt',
                          onPressed: () => _printReceipt(context, sale),
                        ),
                        // Share button
                        IconButton(
                          icon: Icon(Icons.share, color: AppColors.primary),
                          tooltip: 'Share Receipt',
                          onPressed: () => _shareReceipt(context, sale),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: isDark ? AppColors.darkText : AppColors.text),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Sale info
                    _InfoRow(
                      label: 'Date & Time',
                      value: dateFormat.format(DateTime.parse(sale.saleTime)),
                      isDark: isDark,
                    ),
                    _InfoRow(
                      label: 'Customer',
                      value: sale.customerName ?? 'Walk-in',
                      isDark: isDark,
                    ),
                    _InfoRow(
                      label: 'Employee',
                      value: sale.employeeName ?? 'N/A',
                      isDark: isDark,
                    ),
                    if (sale.comment != null && sale.comment!.isNotEmpty)
                      _InfoRow(
                        label: 'Comment',
                        value: sale.comment!,
                        isDark: isDark,
                      ),
                    const SizedBox(height: 16),

                    // Items
                    Text(
                      'Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (sale.items != null)
                      ...sale.items!.map((item) {
                        // Detect free offer items by unitPrice = 0 or quantityOfferFree flag
                        final isFreeItem = item.unitPrice == 0 || item.quantityOfferFree == true;

                        return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isFreeItem
                                ? (isDark ? AppColors.success.withOpacity(0.15) : AppColors.success.withOpacity(0.08))
                                : (isDark ? AppColors.darkBackground : Colors.white),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.itemName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.darkText : AppColors.text,
                                          ),
                                        ),
                                      ),
                                      if (isFreeItem)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.success,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'FREE',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${item.quantity.toStringAsFixed(0)} x '
                                        '${currencyFormat.format(item.unitPrice)} TSh',
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                        ),
                                      ),
                                      Text(
                                        '${currencyFormat.format(item.subtotal)} TSh',
                                        style: TextStyle(
                                          color: isDark ? Colors.grey[400] : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Show if this item was a free offer item
                                  if (isFreeItem) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.success.withOpacity(0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.card_giftcard,
                                            size: 14,
                                            color: AppColors.success,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'FREE (Quantity Offer)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.success,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (item.discount > 0) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Discount:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.error,
                                          ),
                                        ),
                                        Text(
                                          '- ${currencyFormat.format(item.discount)} TSh',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  Divider(height: 12, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Line Total:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.darkText : AppColors.text,
                                        ),
                                      ),
                                      Text(
                                        '${currencyFormat.format(item.lineTotal)} TSh',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                      }),
                    const SizedBox(height: 16),

                    // Totals
                    Card(
                      color: isDark ? AppColors.darkBackground : AppColors.primary.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Subtotal:', style: TextStyle(color: isDark ? AppColors.darkText : AppColors.text)),
                                Text('${currencyFormat.format(sale.subtotal)} TSh', style: TextStyle(color: isDark ? AppColors.darkText : AppColors.text)),
                              ],
                            ),
                            if (sale.items != null && sale.items!.any((item) => item.discount > 0)) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Discount:',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                  Text(
                                    '- ${currencyFormat.format(sale.items!.fold<double>(0, (sum, item) => sum + item.discount))} TSh',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tax:', style: TextStyle(color: isDark ? AppColors.darkText : AppColors.text)),
                                Text('${currencyFormat.format(sale.taxTotal)} TSh', style: TextStyle(color: isDark ? AppColors.darkText : AppColors.text)),
                              ],
                            ),
                            Divider(height: 16, color: isDark ? Colors.grey[600] : Colors.grey[300]),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkText : AppColors.text,
                                  ),
                                ),
                                Text(
                                  '${currencyFormat.format(sale.total)} TSh',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payments
                    if (sale.payments != null && sale.payments!.isNotEmpty) ...[
                      Text(
                        'Payments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...sale.payments!.map((payment) => Card(
                            color: isDark ? AppColors.darkBackground : Colors.white,
                            child: ListTile(
                              leading: Icon(
                                _getPaymentIcon(payment.paymentType),
                                color: AppColors.primary,
                              ),
                              title: Text(
                                payment.paymentType,
                                style: TextStyle(color: isDark ? AppColors.darkText : AppColors.text),
                              ),
                              trailing: Text(
                                '${currencyFormat.format(payment.amount)} TSh',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkText : AppColors.text,
                                ),
                              ),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _printReceipt(BuildContext context, Sale sale) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Preparing receipt...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );

      await PdfService.printSaleReceipt(
        sale,
        companyName: ApiService.currentClient?.name ?? 'POS Tanzania',
        companyAddress: null,
        companyPhone: null,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print receipt: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _shareReceipt(BuildContext context, Sale sale) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Preparing receipt...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );

      await PdfService.shareSaleReceiptPdf(
        sale,
        companyName: ApiService.currentClient?.name ?? 'POS Tanzania',
        companyAddress: null,
        companyPhone: null,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share receipt: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  IconData _getPaymentIcon(String paymentType) {
    final type = paymentType.toLowerCase();
    if (type.contains('cash')) return Icons.money;
    if (type.contains('card')) return Icons.credit_card;
    if (type.contains('lipa') || type.contains('namba')) return Icons.phone_android;
    if (type.contains('credit') || type.contains('due')) return Icons.account_balance_wallet;
    return Icons.payment;
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({required this.label, required this.value, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _PaymentFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
