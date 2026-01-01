import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/stock_tracking.dart';
import '../../models/stock_location.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';
import 'item_tracking_screen.dart';

class StockTrackingScreen extends StatefulWidget {
  const StockTrackingScreen({super.key});

  @override
  State<StockTrackingScreen> createState() => _StockTrackingScreenState();
}

class _StockTrackingScreenState extends State<StockTrackingScreen> {
  final ApiService _apiService = ApiService();
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  StockTrackingReport? _report;
  List<StockLocation> _locations = [];
  StockLocation? _selectedLocation;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    print('=== STOCK TRACKING DEBUG ===');
    print('Loading stock locations...');

    final response = await _apiService.getStockTrackingLocations();

    print('Locations Response - isSuccess: ${response.isSuccess}');
    print('Locations Response - message: ${response.message}');
    print('Locations Response - data: ${response.data}');
    print('Locations Response - statusCode: ${response.statusCode}');

    if (response.isSuccess && response.data != null) {
      print('Locations loaded successfully: ${response.data!.length} locations');
      for (var loc in response.data!) {
        print('  - Location: ${loc.locationId} - ${loc.locationName}');
      }
      setState(() {
        _locations = response.data!;
        if (_locations.isNotEmpty) {
          _selectedLocation = _locations.first;
          print('Selected first location: ${_selectedLocation!.locationName}');
          _loadReport();
        }
      });
    } else {
      print('ERROR loading locations: ${response.message}');
      setState(() {
        _errorMessage = response.message ?? 'Failed to load locations';
      });
    }
  }

  Future<void> _loadReport() async {
    if (_selectedLocation == null) {
      print('ERROR: No location selected');
      return;
    }

    print('=== LOADING STOCK REPORT ===');
    print('Location ID: ${_selectedLocation!.locationId}');
    print('Location Name: ${_selectedLocation!.locationName}');
    print('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    print('Calling API: getStockTracking(date: $dateStr, stockLocationId: ${_selectedLocation!.locationId})');

    final response = await _apiService.getStockTracking(
      date: dateStr,
      stockLocationId: _selectedLocation!.locationId,
    );

    print('Report Response - isSuccess: ${response.isSuccess}');
    print('Report Response - message: ${response.message}');
    print('Report Response - statusCode: ${response.statusCode}');

    if (response.isSuccess && response.data != null) {
      print('Report loaded successfully!');
      print('Items count: ${response.data!.items.length}');
      print('Total Net Sales: ${response.data!.totals.totalNetSales}');
      print('Stock Value: ${response.data!.totals.stockValue}');
      setState(() {
        _report = response.data;
        _isLoading = false;
      });
    } else {
      print('ERROR loading report: ${response.message}');
      setState(() {
        _errorMessage = response.message ?? 'Failed to load stock tracking';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
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
      _loadReport();
    }
  }

  void _navigateToItemTracking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ItemTrackingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [AppColors.lightBackground, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              _buildFilters(isDark),
              Expanded(
                child: _isLoading
                    ? _buildSkeletonList(isDark)
                    : _errorMessage != null
                        ? _buildError(isDark)
                        : _report == null
                            ? _buildEmpty(isDark)
                            : _buildContent(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Stock Tracking',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _navigateToItemTracking,
            icon: Icon(Icons.search, color: AppColors.primary),
            label: Text(
              'Item Tracking',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Date Picker
          Expanded(
            child: GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      style: TextStyle(
                        color: isDark ? AppColors.darkText : AppColors.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Location Dropdown
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.1),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<StockLocation>(
                  value: _selectedLocation,
                  isExpanded: true,
                  dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                  items: _locations.map((location) {
                    return DropdownMenuItem<StockLocation>(
                      value: location,
                      child: Text(
                        location.locationName,
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : AppColors.text,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLocation = value;
                    });
                    _loadReport();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'Select a location to view stock tracking',
            style: TextStyle(
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            _buildSummaryCards(isDark),
            const SizedBox(height: 16),

            // Items Table
            _buildItemsSection(isDark),
            const SizedBox(height: 16),

            // Cash Flow Section
            _buildCashFlowSection(isDark),
            const SizedBox(height: 16),

            // Customer Credits Section
            if (_report!.customerCreditsList.isNotEmpty) ...[
              _buildCustomerCreditsSection(isDark),
              const SizedBox(height: 16),
            ],

            // Customer Payments Section
            if (_report!.customerPaymentsList.isNotEmpty) ...[
              _buildCustomerPaymentsSection(isDark),
              const SizedBox(height: 16),
            ],

            // Supplier Bank Payments Section
            if (_report!.supplierBankPaymentsList.isNotEmpty) ...[
              _buildSupplierPaymentsSection(isDark),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            isDark: isDark,
            title: 'Net Sales',
            value: _report!.totals.totalNetSales,
            icon: Icons.point_of_sale,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            isDark: isDark,
            title: 'Stock Value',
            value: _report!.totals.stockValue,
            icon: Icons.inventory,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required bool isDark,
    required String title,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _currencyFormat.format(value),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Stock Items (${_report!.items.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 16,
              headingRowHeight: 40,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 48,
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
              dataTextStyle: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Opening'), numeric: true),
                DataColumn(label: Text('In'), numeric: true),
                DataColumn(label: Text('Total'), numeric: true),
                DataColumn(label: Text('Sold'), numeric: true),
                DataColumn(label: Text('Closing'), numeric: true),
                DataColumn(label: Text('Actual'), numeric: true),
                DataColumn(label: Text('Price'), numeric: true),
                DataColumn(label: Text('Net Sales'), numeric: true),
              ],
              rows: _report!.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return DataRow(
                  cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(_formatNumber(item.opening))),
                    DataCell(Text(_formatNumber(item.purchased))),
                    DataCell(Text(_formatNumber(item.total))),
                    DataCell(Text(_formatNumber(item.sold))),
                    DataCell(Text(_formatNumber(item.closing))),
                    DataCell(Text(
                      _formatNumber(item.actual),
                      style: TextStyle(
                        color: item.isBalanced ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                    DataCell(Text(_currencyFormat.format(item.unitPrice))),
                    DataCell(Text(_currencyFormat.format(item.netSales))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowSection(bool isDark) {
    final cashFlow = _report!.cashFlow;
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Cash Flow',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCashFlowRow('Net Sales', cashFlow.netSales, isDark),
            _buildCashFlowRow('Customer Credit', -cashFlow.customerCredit, isDark, isNegative: true),
            _buildCashFlowRow('Cash Sales', cashFlow.cashSales, isDark, isBold: true),
            const Divider(),
            _buildCashFlowRow('Customer Payments', cashFlow.customerPayments, isDark),
            _buildCashFlowRow('Total Cash', cashFlow.totalCash, isDark, isBold: true),
            const Divider(),
            _buildCashFlowRow('Expenses', -cashFlow.expenses, isDark, isNegative: true),
            _buildCashFlowRow('Cash After Expenses', cashFlow.cashAfterExpenses, isDark, isBold: true),
            const Divider(),
            _buildCashFlowRow('Bank Deposits', -cashFlow.bankDeposits, isDark, isNegative: true),
            _buildCashFlowRow('Net Cash', cashFlow.netCash, isDark, isBold: true, isHighlighted: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowRow(String label, double value, bool isDark, {bool isBold = false, bool isNegative = false, bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
          Text(
            _currencyFormat.format(value.abs()),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted
                  ? (value >= 0 ? Colors.green : Colors.red)
                  : (isNegative ? Colors.red : (isDark ? AppColors.darkText : AppColors.text)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCreditsSection(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.credit_card, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Customer Credits',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                  ],
                ),
                Text(
                  _currencyFormat.format(_report!.customerCreditsTotal),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...(_report!.customerCreditsList.map((credit) => _buildListTile(
              isDark: isDark,
              title: credit.customerName,
              subtitle: credit.items,
              value: credit.amount,
            ))),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerPaymentsSection(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Customer Payments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                  ],
                ),
                Text(
                  _currencyFormat.format(_report!.customerPaymentsTotal),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...(_report!.customerPaymentsList.map((payment) => _buildListTile(
              isDark: isDark,
              title: payment.customerName,
              subtitle: 'Paid',
              value: payment.amount,
            ))),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierPaymentsSection(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Supplier Bank Payments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                  ],
                ),
                Text(
                  _currencyFormat.format(_report!.supplierBankPaymentsTotal),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...(_report!.supplierBankPaymentsList.map((payment) => _buildListTile(
              isDark: isDark,
              title: payment.supplierName,
              subtitle: 'Paid',
              value: payment.amount,
            ))),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required bool isDark,
    required String title,
    required String subtitle,
    required double value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(value),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  Widget _buildSkeletonList(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary cards skeleton
          Row(
            children: [
              Expanded(child: _buildSkeletonSummaryCard(isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildSkeletonSummaryCard(isDark)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSkeletonSummaryCard(isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildSkeletonSummaryCard(isDark)),
            ],
          ),
          const SizedBox(height: 16),
          // Category skeletons
          ...List.generate(4, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSkeletonCategoryCard(isDark),
          )),
        ],
      ),
    );
  }

  Widget _buildSkeletonSummaryCard(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonLoader(width: 32, height: 32, borderRadius: 8, isDark: isDark),
                const SizedBox(width: 8),
                SkeletonLoader(width: 60, height: 10, isDark: isDark),
              ],
            ),
            const SizedBox(height: 8),
            SkeletonLoader(width: 80, height: 18, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCategoryCard(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SkeletonLoader(width: 40, height: 40, borderRadius: 8, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 120, height: 14, isDark: isDark),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: 80, height: 12, isDark: isDark),
                ],
              ),
            ),
            SkeletonLoader(width: 70, height: 16, isDark: isDark),
          ],
        ),
      ),
    );
  }
}
