import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../../utils/formatters.dart' show Formatters;
import '../../utils/constants.dart';

class WakalaReportScreen extends StatefulWidget {
  const WakalaReportScreen({super.key});

  @override
  State<WakalaReportScreen> createState() => _WakalaReportScreenState();
}

class _WakalaReportScreenState extends State<WakalaReportScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  WakalaReport? _report;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      final response = await _apiService.getWakalaReport(
        startDate: startDateStr,
        endDate: endDateStr,
      );

      if (response.isSuccess && mounted) {
        setState(() {
          _report = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load report: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wakala Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
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
                _loadReport();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [AppColors.lightBackground, Colors.white],
          ),
        ),
        child: _isLoading
            ? _buildSkeletonList(isDark)
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadReport,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _report == null
                    ? const Center(child: Text('No report data available'))
                    : _buildReportContent(),
      ),
    );
  }

  Widget _buildReportContent() {
    final report = _report!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Range
          GlassmorphicCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Report Period:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  Text(
                    '${report.startDate} - ${report.endDate}',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // SIMs Section
          _buildSectionHeader('SIM Cards Float', isDark: isDark),
          const SizedBox(height: 8),
          _buildReportSection(report.sims, context),
          const SizedBox(height: 24),

          // Bank Basis Section
          _buildSectionHeader('Bank / Mobile Money', isDark: isDark),
          const SizedBox(height: 8),
          _buildReportSection(report.bankBasis, context),
          const SizedBox(height: 24),

          // Cash Basis Section
          _buildSectionHeader('Cash Transactions', isDark: isDark),
          const SizedBox(height: 8),
          _buildReportSection(report.cashBasis, context),
          const SizedBox(height: 24),

          // Wakala Expenses Section
          _buildSectionHeader('Wakala Expenses', isDark: isDark),
          const SizedBox(height: 8),
          _buildExpensesSection(report.wakalaExpenses, context),
          const SizedBox(height: 24),

          // Summary Section
          _buildSectionHeader('Financial Summary', isDark: isDark),
          const SizedBox(height: 8),
          _buildSummaryCard(report, context),
          const SizedBox(height: 24),

          // Gain/Loss Card
          _buildGainLossCard(report, context),
          const SizedBox(height: 24),

          // Creditors/Withdraw Section
          if (report.creditors.list.isNotEmpty) ...[
            _buildSectionHeader('Today Creditors/Withdraw', isDark: isDark),
            const SizedBox(height: 8),
            _buildCreditorDebtorSection(report.creditors, context, isCreditor: true),
            const SizedBox(height: 24),
          ],

          // Debtors/Deposit Section
          if (report.debtors.list.isNotEmpty) ...[
            _buildSectionHeader('Today Debtors/Deposit', isDark: isDark),
            const SizedBox(height: 8),
            _buildCreditorDebtorSection(report.debtors, context, isCreditor: false),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required bool isDark}) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.primary : AppColors.secondary,
      ),
    );
  }

  Widget _buildReportSection(WakalaReportSection section, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final amountColor = themeProvider.isDarkMode ? Colors.white : AppColors.secondary;

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Items List
            ...section.list.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.name),
                      Text(
                        Formatters.formatCurrency(item.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: amountColor,
                        ),
                      ),
                    ],
                  ),
                )),

            if (section.list.isNotEmpty) const Divider(height: 24),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  Formatters.formatCurrency(section.total),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesSection(WakalaExpensesSection section, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final amountColor = AppColors.primary; // Expenses shown in red

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Items List
            ...section.list.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.description.isNotEmpty ? item.description : 'Expense',
                          style: TextStyle(
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                      ),
                      Text(
                        Formatters.formatCurrency(item.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: amountColor,
                        ),
                      ),
                    ],
                  ),
                )),

            if (section.list.isNotEmpty) const Divider(height: 24),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  Formatters.formatCurrency(section.total),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(WakalaReport report, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final amountColor = isDark ? Colors.white : AppColors.secondary;

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSummaryRow('Opening Balance', report.openingBalance, amountColor),
            const SizedBox(height: 12),
            _buildSummaryRow('Debit', report.totalDeposited, amountColor),
            const SizedBox(height: 12),
            _buildSummaryRow('Withdraw', report.totalWithdrawn, AppColors.primary),
            const SizedBox(height: 12),
            _buildSummaryRow('Closing Balance', report.closingBalance, amountColor),
            const Divider(height: 24),
            _buildSummaryRow('Net Total', report.netTotal, amountColor, isLarge: true),
            const Divider(height: 24),
            _buildSummaryRow('Calculated Capital', report.calculatedCapital, amountColor),
            const SizedBox(height: 12),
            _buildSummaryRow('Capital', report.capital, isDark ? Colors.cyanAccent : Colors.blue.shade700),
            const SizedBox(height: 12),
            _buildSummaryRow('Commission', report.commission, isDark ? Colors.amberAccent : Colors.orange.shade700),
            const SizedBox(height: 12),
            _buildSummaryRow('Actual Capital', report.actualCapital, amountColor, isLarge: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditorDebtorSection(CreditorDebtorSection section, BuildContext context, {required bool isCreditor}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final amountColor = isCreditor ? AppColors.primary : (isDark ? Colors.greenAccent : Colors.green.shade700);

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Items List
            ...section.list.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: amountColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCreditor ? Icons.arrow_upward : Icons.arrow_downward,
                          color: amountColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                            ),
                            if (item.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        Formatters.formatCurrency(item.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: amountColor,
                        ),
                      ),
                    ],
                  ),
                )),

            const Divider(height: 24),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  Formatters.formatCurrency(section.total),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color,
      {bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 18 : 16,
            fontWeight: isLarge ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          Formatters.formatCurrency(amount),
          style: TextStyle(
            fontSize: isLarge ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildGainLossCard(WakalaReport report, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final isGain = report.gainLoss >= 0;
    final gainColor = isDark ? Colors.greenAccent : Colors.green.shade700;
    final lossColor = AppColors.primary;
    final resultColor = isGain ? gainColor : lossColor;

    return GlassmorphicCard(
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isGain
                ? isDark
                    ? [Colors.greenAccent.withOpacity(0.15), Colors.greenAccent.withOpacity(0.05)]
                    : [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)]
                : [AppColors.primary.withOpacity(0.3), AppColors.primary.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGain ? 'PROFIT' : 'LOSS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: resultColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Period Result',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  isGain ? Icons.trending_up : Icons.trending_down,
                  color: resultColor,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.formatCurrency(report.gainLoss.abs()),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: resultColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary card skeleton
          _buildSkeletonSummaryCard(isDark),
          const SizedBox(height: 16),
          // Detail cards skeleton
          ...List.generate(4, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSkeletonDetailCard(isDark),
          )),
        ],
      ),
    );
  }

  Widget _buildSkeletonSummaryCard(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SkeletonLoader(width: 80, height: 12, isDark: isDark),
            const SizedBox(height: 8),
            SkeletonLoader(width: 120, height: 28, isDark: isDark),
            const SizedBox(height: 16),
            Row(
              children: [
                SkeletonLoader(width: 24, height: 24, isDark: isDark),
                const SizedBox(width: 8),
                SkeletonLoader(width: 100, height: 24, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonDetailCard(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SkeletonLoader(width: 36, height: 36, borderRadius: 8, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 100, height: 12, isDark: isDark),
                  const SizedBox(height: 4),
                  SkeletonLoader(width: 80, height: 16, isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
