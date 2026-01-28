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

class CustomerStatementScreen extends StatefulWidget {
  final int customerId;
  final String customerName;

  const CustomerStatementScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerStatementScreen> createState() =>
      _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  TransactionStatement? _statement;

  String _startDate = DateFormat('yyyy-MM-dd').format(
    DateTime(DateTime.now().year, DateTime.now().month, 1),
  );
  String _endDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getCustomerStatement(
        widget.customerId,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (response.isSuccess && mounted) {
        setState(() {
          _statement = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.message ?? 'Failed to load statement';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load statement: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.parse(_startDate),
        end: DateTime.parse(_endDate),
      ),
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
        _startDate = DateFormat('yyyy-MM-dd').format(picked.start);
        _endDate = DateFormat('yyyy-MM-dd').format(picked.end);
      });
      _loadStatement();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatement,
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
                ? _buildError(isDark)
                : _buildContent(isDark),
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
            size: 64,
            color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
              color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadStatement,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final stmt = _statement;
    if (stmt == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadStatement,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date Range Chip
          _buildDateChip(isDark),
          const SizedBox(height: 12),

          // Opening Balance
          _buildBalanceCard(
            label: 'Opening Balance',
            date: stmt.startDate,
            amount: stmt.openingBalance,
            color: Colors.blue,
            icon: Icons.arrow_forward,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Transaction List
          if (stmt.transactions.isEmpty)
            _buildEmptyState(isDark)
          else
            ...stmt.transactions.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildTransactionCard(t, isDark),
                )),

          const SizedBox(height: 12),

          // Closing Balance
          _buildBalanceCard(
            label: 'Closing Balance',
            date: stmt.endDate,
            amount: stmt.closingBalance,
            color: Colors.green.shade700,
            icon: Icons.flag,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Totals
          _buildTotalsCard(stmt, isDark),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDateChip(bool isDark) {
    return GestureDetector(
      onTap: _selectDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              '${Formatters.formatDate(_startDate)}  —  ${Formatters.formatDate(_endDate)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit, size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard({
    required String label,
    required String date,
    required double amount,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextLight
                          : AppColors.lightTextLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.formatDate(date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextLight
                          : AppColors.lightTextLight,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              Formatters.formatCurrency(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: amount >= 0
                    ? (isDark ? Colors.greenAccent : Colors.green.shade700)
                    : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(StatementTransaction txn, bool isDark) {
    final isDeposit = txn.type == 'deposit';
    final txnColor = isDeposit
        ? (isDark ? Colors.greenAccent : Colors.green.shade700)
        : AppColors.primary;
    final txnIcon = isDeposit ? Icons.arrow_downward : Icons.arrow_upward;
    final txnAmount = isDeposit ? txn.deposit : txn.withdrawal;

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: txnColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(txnIcon, color: txnColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn.description.isNotEmpty
                            ? txn.description
                            : (isDeposit ? 'Deposit' : 'Withdrawal'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatDate(txn.date),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.lightTextLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isDeposit ? '+' : '-'}${Formatters.formatCurrency(txnAmount)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: txnColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bal: ${Formatters.formatCurrency(txn.balance)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextLight
                            : AppColors.lightTextLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsCard(TransactionStatement stmt, bool isDark) {
    double totalDeposits = 0;
    double totalWithdrawals = 0;
    for (var t in stmt.transactions) {
      totalDeposits += t.deposit;
      totalWithdrawals += t.withdrawal;
    }

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 14),
            _buildTotalRow(
              'Total Deposits',
              totalDeposits,
              isDark ? Colors.greenAccent : Colors.green.shade700,
              isDark,
            ),
            const Divider(height: 20),
            _buildTotalRow(
              'Total Withdrawals',
              totalWithdrawals,
              AppColors.primary,
              isDark,
            ),
            const Divider(height: 20),
            _buildTotalRow(
              'Net Movement',
              totalDeposits - totalWithdrawals,
              isDark ? Colors.white : AppColors.secondary,
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
      String label, double amount, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
          ),
        ),
        Text(
          Formatters.formatCurrency(amount),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
            ),
            const SizedBox(height: 12),
            Text(
              'No transactions in this period',
              style: TextStyle(
                color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Date chip skeleton
        SkeletonLoader(width: double.infinity, height: 40, isDark: isDark),
        const SizedBox(height: 12),
        // Balance card skeleton
        _buildSkeletonCard(isDark),
        const SizedBox(height: 10),
        // Transaction skeletons
        for (int i = 0; i < 5; i++) ...[
          _buildSkeletonCard(isDark),
          const SizedBox(height: 10),
        ],
        // Balance card skeleton
        _buildSkeletonCard(isDark),
      ],
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SkeletonLoader(
                width: 40, height: 40, borderRadius: 10, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 120, height: 14, isDark: isDark),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: 80, height: 10, isDark: isDark),
                ],
              ),
            ),
            SkeletonLoader(width: 80, height: 18, isDark: isDark),
          ],
        ),
      ),
    );
  }
}