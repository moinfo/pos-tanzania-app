import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glassmorphic_card.dart';
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
            ? const Center(child: CircularProgressIndicator())
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
                  const Text(
                    'Report Period:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${report.startDate} - ${report.endDate}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // SIMs Section
          _buildSectionHeader('SIM Cards Float'),
          const SizedBox(height: 8),
          _buildReportSection(report.sims, context),
          const SizedBox(height: 24),

          // Bank Basis Section
          _buildSectionHeader('Bank / Mobile Money'),
          const SizedBox(height: 8),
          _buildReportSection(report.bankBasis, context),
          const SizedBox(height: 24),

          // Cash Basis Section
          _buildSectionHeader('Cash Transactions'),
          const SizedBox(height: 8),
          _buildReportSection(report.cashBasis, context),
          const SizedBox(height: 24),

          // Summary Section
          _buildSectionHeader('Financial Summary'),
          const SizedBox(height: 8),
          _buildSummaryCard(report, context),
          const SizedBox(height: 24),

          // Gain/Loss Card
          _buildGainLossCard(report, context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.secondary,
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

  Widget _buildSummaryCard(WakalaReport report, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final amountColor = themeProvider.isDarkMode ? Colors.white : AppColors.secondary;

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSummaryRow('Float (SIMs + Bank)', report.float, amountColor),
            const SizedBox(height: 12),
            _buildSummaryRow('Total Deposited', report.totalDeposited, amountColor),
            const SizedBox(height: 12),
            _buildSummaryRow('Total Withdrawn', report.totalWithdrawn, AppColors.primary),
            const SizedBox(height: 12),
            _buildSummaryRow('Opening Balance', report.openingBalance, amountColor),
            const Divider(height: 24),
            _buildSummaryRow('Net Total', report.netTotal, amountColor, isLarge: true),
            const SizedBox(height: 12),
            _buildSummaryRow('Capital', report.capital, amountColor),
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
    final isGain = report.gainLoss >= 0;
    final gainColor = themeProvider.isDarkMode ? Colors.white : AppColors.secondary;

    return GlassmorphicCard(
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isGain
                ? themeProvider.isDarkMode
                    ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]
                    : [AppColors.secondary.withOpacity(0.1), AppColors.secondary.withOpacity(0.05)]
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
                    color: isGain ? gainColor : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Period Result',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  isGain ? Icons.trending_up : Icons.trending_down,
                  color: isGain ? gainColor : AppColors.primary,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.formatCurrency(report.gainLoss.abs()),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isGain ? gainColor : AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
