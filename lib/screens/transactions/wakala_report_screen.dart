import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../models/permission_model.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../../utils/formatters.dart' show Formatters;
import '../../utils/constants.dart';
import 'wakala_theme.dart';

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
    // Reading the report and re-scoping its period are separate grants: without
    // this the report stays on its default period.
    final canChangeDateRange = Provider.of<PermissionProvider>(context)
        .hasPermission(PermissionIds.transactionsWakalaReportDateRange);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: WakalaTheme.appBar(
        isDark: isDark,
        eyebrow: 'Summary',
        title: 'Wakala Report',
        actions: [
          if (canChangeDateRange)
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
      body: _isLoading
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
    );
  }

  Widget _buildReportContent() {
    final report = _report!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final subColor = isDark ? AppColors.darkTextLight : const Color(0xFF6C757D);

    final moneyOnHand = report.sims.total + report.bankBasis.total + report.cashBasis.total;
    final simPct = moneyOnHand > 0 ? (report.sims.total / moneyOnHand * 100) : 0.0;
    final bankPct = moneyOnHand > 0 ? (report.bankBasis.total / moneyOnHand * 100) : 0.0;
    final cashPct = moneyOnHand > 0 ? (report.cashBasis.total / moneyOnHand * 100) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text('Report period', style: WakalaTheme.body(size: 13, weight: FontWeight.w600, color: subColor)),
                const Spacer(),
                Text('${report.startDate} – ${report.endDate}',
                    style: WakalaTheme.display(size: 14, weight: FontWeight.w600, color: textColor)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          WakalaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Money on hand', style: WakalaTheme.body(size: 12, color: subColor)),
                Text(Formatters.formatCurrency(moneyOnHand),
                    style: WakalaTheme.display(size: 36, weight: FontWeight.w700, letterSpacing: -0.5, color: textColor)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        if (simPct > 0) Expanded(flex: (simPct * 10).round().clamp(1, 1000), child: Container(color: AppColors.primary)),
                        if (bankPct > 0) Expanded(flex: (bankPct * 10).round().clamp(1, 1000), child: Container(color: AppColors.primaryLight)),
                        if (cashPct > 0) Expanded(flex: (cashPct * 10).round().clamp(1, 1000), child: Container(color: AppColors.warning)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _legendDot(AppColors.primary, 'SIM float', subColor),
                    _legendDot(AppColors.primaryLight, 'Bank', subColor),
                    _legendDot(AppColors.warning, 'Cash', subColor),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionHeader('SIM cards float'),
          const SizedBox(height: 8),
          _buildReportSection(report.sims, AppColors.primary),
          const SizedBox(height: 20),

          _buildSectionHeader('Bank / Mobile money'),
          const SizedBox(height: 8),
          _buildReportSection(report.bankBasis, AppColors.primaryLight),
          const SizedBox(height: 20),

          _buildSectionHeader('Cash transactions'),
          const SizedBox(height: 8),
          _buildReportSection(report.cashBasis, AppColors.warning),
          const SizedBox(height: 20),

          _buildSectionHeader('Wakala expenses'),
          const SizedBox(height: 8),
          _buildExpensesSection(report.wakalaExpenses),
          const SizedBox(height: 20),

          _buildSectionHeader('Financial summary'),
          const SizedBox(height: 8),
          _buildSummaryCard(report, context),
          const SizedBox(height: 20),

          _buildGainLossCard(report, context),

          if (report.creditors.list.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionHeader('Today creditors/withdraw'),
            const SizedBox(height: 8),
            _buildCreditorDebtorSection(report.creditors, context, isCreditor: true),
          ],

          if (report.debtors.list.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionHeader('Today debtors/deposit'),
            const SizedBox(height: 8),
            _buildCreditorDebtorSection(report.debtors, context, isCreditor: false),
          ],
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: WakalaTheme.body(size: 12, color: textColor)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(title, style: WakalaTheme.display(size: 13, weight: FontWeight.w700, letterSpacing: 0.9, color: const Color(0xFF6C757D))),
    );
  }

  /// The "balance card" pattern -- one kv row per item, then a charcoal
  /// footer band with the section total. Mirrors the WReport handover.
  Widget _buildBalanceCard(List<MapEntry<String, double>> rows, double total, Color railColor, bool isDark) {
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: railColor),
          Expanded(
            child: Column(
              children: [
                ...rows.map((row) => Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(row.key, style: WakalaTheme.body(size: 14, color: textColor), overflow: TextOverflow.ellipsis)),
                          Text(Formatters.formatCurrency(row.value), style: WakalaTheme.display(size: 15, weight: FontWeight.w600, color: textColor)),
                        ],
                      ),
                    )),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                  color: AppColors.secondary,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL',
                          style: WakalaTheme.body(size: 13, weight: FontWeight.w600, color: const Color(0xFFE9ECEF)).copyWith(letterSpacing: 1.2)),
                      Text(Formatters.formatCurrency(total), style: WakalaTheme.display(size: 22, weight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection(WakalaReportSection section, Color railColor) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return _buildBalanceCard(
      section.list.map((item) => MapEntry(item.name, item.amount)).toList(),
      section.total,
      railColor,
      isDark,
    );
  }

  Widget _buildExpensesSection(WakalaExpensesSection section) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return _buildBalanceCard(
      section.list.map((item) => MapEntry(item.description.isNotEmpty ? item.description : 'Expense', item.amount)).toList(),
      section.total,
      AppColors.error,
      isDark,
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
            _buildSummaryRow(
                'Capital', report.capital, isDark ? Colors.cyanAccent : Colors.blue.shade700),
            const SizedBox(height: 12),
            _buildSummaryRow('Commission', report.commission,
                isDark ? Colors.amberAccent : Colors.orange.shade700),
            const SizedBox(height: 12),
            _buildSummaryRow('Actual Capital', report.actualCapital, amountColor, isLarge: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditorDebtorSection(CreditorDebtorSection section, BuildContext context,
      {required bool isCreditor}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final amountColor =
        isCreditor ? AppColors.primary : (isDark ? Colors.greenAccent : Colors.green.shade700);

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
                                  color:
                                      isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
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

  Widget _buildSummaryRow(String label, double amount, Color color, {bool isLarge = false}) {
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
          ...List.generate(
              4,
              (index) => Padding(
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
