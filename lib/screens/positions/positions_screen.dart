import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/position.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';

class PositionsScreen extends StatefulWidget {
  const PositionsScreen({super.key});

  @override
  State<PositionsScreen> createState() => _PositionsScreenState();
}

class _PositionsScreenState extends State<PositionsScreen> {
  final ApiService _apiService = ApiService();
  final _currencyFormat = NumberFormat('#,##0', 'en_US');

  PositionsReport? _report;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 4));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    final response = await _apiService.getPositions(
      startDate: startDateStr,
      endDate: endDateStr,
    );

    if (response.isSuccess && response.data != null) {
      setState(() {
        _report = response.data;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response.message ?? 'Failed to load positions';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
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

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReport();
    }
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
              _buildDateFilter(isDark),
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
              'Financial Position',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: _selectDateRange,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.date_range,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                  style: TextStyle(
                    color: isDark ? AppColors.darkText : AppColors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ],
          ),
        ),
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
            Icons.analytics_outlined,
            size: 48,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No position data available',
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

            // Positions Table
            _buildPositionsTable(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    final totals = _report!.totals;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                isDark: isDark,
                title: 'Total Profit',
                value: totals.profit,
                icon: Icons.trending_up,
                color: totals.profit >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                isDark: isDark,
                title: 'Total Capital',
                value: totals.capital,
                icon: Icons.account_balance,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                isDark: isDark,
                title: 'Cash Submitted',
                value: totals.cashSubmitted,
                icon: Icons.payments,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                isDark: isDark,
                title: 'Expenses',
                value: totals.expenses,
                icon: Icons.receipt_long,
                color: Colors.red,
              ),
            ),
          ],
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
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _currencyFormat.format(value),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionsTable(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.table_chart, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Daily Positions (${_report!.positions.length})',
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
              columnSpacing: 12,
              horizontalMargin: 16,
              headingRowHeight: 40,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 48,
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
              dataTextStyle: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Opening'), numeric: true),
                DataColumn(label: Text('Receiving'), numeric: true),
                DataColumn(label: Text('Sales'), numeric: true),
                DataColumn(label: Text('Closing'), numeric: true),
                DataColumn(label: Text('Changes'), numeric: true),
                DataColumn(label: Text('Frustration'), numeric: true),
                DataColumn(label: Text('Bank'), numeric: true),
                DataColumn(label: Text('Cust Credit'), numeric: true),
                DataColumn(label: Text('Supp Credit'), numeric: true),
                DataColumn(label: Text('Cash Sub'), numeric: true),
                DataColumn(label: Text('Expenses'), numeric: true),
                DataColumn(label: Text('Profit'), numeric: true),
                DataColumn(label: Text('Capital'), numeric: true),
              ],
              rows: _report!.positions.asMap().entries.map((entry) {
                final index = entry.key;
                final pos = entry.value;
                return DataRow(
                  cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(Text(_formatDate(pos.date))),
                    DataCell(Text(_currencyFormat.format(pos.openingStock))),
                    DataCell(Text(_currencyFormat.format(pos.receiving))),
                    DataCell(Text(_currencyFormat.format(pos.salesCost))),
                    DataCell(Text(_currencyFormat.format(pos.closingStock))),
                    DataCell(Text(_currencyFormat.format(pos.changes))),
                    DataCell(Text(
                      _currencyFormat.format(pos.stockFrustration),
                      style: TextStyle(
                        color: pos.stockFrustration != 0 ? Colors.red : null,
                      ),
                    )),
                    DataCell(Text(_currencyFormat.format(pos.bankBalance))),
                    DataCell(Text(_currencyFormat.format(pos.creditCustomer))),
                    DataCell(Text(_currencyFormat.format(pos.creditSupplier))),
                    DataCell(Text(_currencyFormat.format(pos.cashSubmitted))),
                    DataCell(Text(_currencyFormat.format(pos.expenses))),
                    DataCell(Text(
                      _currencyFormat.format(pos.profit),
                      style: TextStyle(
                        color: pos.profit >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                    DataCell(Text(
                      _currencyFormat.format(pos.capital),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildSkeletonList(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          // Table skeleton
          _buildSkeletonTable(isDark),
        ],
      ),
    );
  }

  Widget _buildSkeletonSummaryCard(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonLoader(width: 34, height: 34, borderRadius: 8, isDark: isDark),
                const SizedBox(width: 8),
                Expanded(
                  child: SkeletonLoader(width: 60, height: 11, isDark: isDark),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SkeletonLoader(width: 80, height: 16, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonTable(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header skeleton
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                SkeletonLoader(width: 20, height: 20, isDark: isDark),
                const SizedBox(width: 8),
                SkeletonLoader(width: 120, height: 16, isDark: isDark),
              ],
            ),
          ),
          // Table rows skeleton
          ...List.generate(5, (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SkeletonLoader(width: 20, height: 14, isDark: isDark),
                const SizedBox(width: 12),
                SkeletonLoader(width: 60, height: 14, isDark: isDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (_) =>
                      SkeletonLoader(width: 50, height: 14, isDark: isDark),
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
