import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/lipa_namba.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../../utils/formatters.dart' show Formatters;
import '../../utils/constants.dart';
import 'wakala_theme.dart';

class LipaNambaTransactionsScreen extends StatefulWidget {
  const LipaNambaTransactionsScreen({super.key});

  @override
  State<LipaNambaTransactionsScreen> createState() => _LipaNambaTransactionsScreenState();
}

class _LipaNambaTransactionsScreenState extends State<LipaNambaTransactionsScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _error;

  List<LipaNambaAccount> _accounts = [];
  List<LipaNambaTransaction> _transactions = [];
  LipaNambaTransactionsSummary? _summary;
  int? _selectedAccountId;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final accountsResponse = await _apiService.getLipaNambaAccounts();

      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);
      final transactionsResponse = await _apiService.getLipaNambaTransactions(
        startDate: startDateStr,
        endDate: endDateStr,
        lipaNambaId: _selectedAccountId,
      );

      if (!mounted) return;
      if (accountsResponse.isSuccess && transactionsResponse.isSuccess) {
        setState(() {
          _accounts = accountsResponse.data ?? [];
          _transactions = transactionsResponse.data?.transactions ?? [];
          _summary = transactionsResponse.data?.summary;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = accountsResponse.message ?? transactionsResponse.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteTransaction(LipaNambaTransaction transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this ${transaction.isDeposit ? 'deposit' : 'withdrawal'} of '
          '${Formatters.formatCurrency(transaction.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await _apiService.deleteLipaNambaTransaction(transaction.id);

      if (context.mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted successfully')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final permissionProvider = Provider.of<PermissionProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final canDelete = permissionProvider.hasPermission(PermissionIds.lipaNambaDeleteTransaction);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: WakalaTheme.appBar(
        isDark: isDark,
        eyebrow: 'Tills',
        title: 'Lipa Namba Transactions',
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
                _loadData();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeletonList(isDark)
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: DropdownButtonFormField<int?>(
                        value: _selectedAccountId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Till', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('All tills')),
                          ..._accounts.map((a) => DropdownMenuItem<int?>(
                                value: a.id,
                                child: Text('${a.name} (${a.number})', overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedAccountId = value);
                          _loadData();
                        },
                      ),
                    ),
                    if (_summary != null) _buildSummaryGrid(isDark),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: Text('Transactions',
                          style: WakalaTheme.display(size: 13, weight: FontWeight.w700, letterSpacing: 0.9, color: const Color(0xFF6C757D))),
                    ),
                    Expanded(child: _buildTransactionsList(isDark, canDelete)),
                  ],
                ),
    );
  }

  Widget _buildSummaryGrid(bool isDark) {
    final s = _summary!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.4,
        children: [
          _summaryTile(Icons.arrow_downward, 'Deposits', '${Formatters.formatCurrency(s.totalDeposits)} (${s.depositCount})',
              const Color(0xFF047857), isDark),
          _summaryTile(Icons.arrow_upward, 'Withdrawals', '${Formatters.formatCurrency(s.totalWithdraws)} (${s.withdrawCount})',
              const Color(0xFFB91C1C), isDark),
          _summaryTile(Icons.percent, 'Fees', Formatters.formatCurrency(s.totalFees), AppColors.primary, isDark),
          _summaryTile(Icons.receipt_long, 'Net', Formatters.formatCurrency(s.net), isDark ? AppColors.darkText : AppColors.text, isDark),
        ],
      ),
    );
  }

  Widget _summaryTile(IconData icon, String label, String value, Color valueColor, bool isDark) {
    return WakalaPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D)),
              const SizedBox(width: 6),
              Text(label, style: WakalaTheme.body(size: 12, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
            ],
          ),
          Text(value, style: WakalaTheme.display(size: 18, weight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(bool isDark, bool canDelete) {
    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          'No transactions found',
          style: WakalaTheme.body(size: 14, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final t = _transactions[index];
        final tint = t.isDeposit ? WakalaTint.green : WakalaTint.red;
        final railColor = t.isDeposit ? const Color(0xFF10B981) : const Color(0xFFEF4444);
        final amountColor = t.isDeposit ? const Color(0xFF047857) : const Color(0xFFB91C1C);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: WakalaCard(
            railColor: railColor,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                WakalaIconTile(icon: t.isDeposit ? Icons.arrow_downward : Icons.arrow_upward, tint: tint),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.clientName.isNotEmpty ? t.clientName : t.lipaNambaName,
                          style: WakalaTheme.display(size: 17, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                      Text(t.lipaNambaName, style: WakalaTheme.body(size: 12.5, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
                      Text(
                        t.clientPhone.isNotEmpty ? '${t.transactionDate} · ${t.clientPhone}' : t.transactionDate,
                        style: WakalaTheme.body(size: 12.5, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Formatters.formatCurrency(t.amount), style: WakalaTheme.display(size: 18, weight: FontWeight.w700, color: amountColor)),
                    if (t.isDeposit && t.fee > 0)
                      Text('+ fee ${Formatters.formatCurrency(t.fee)}',
                          style: WakalaTheme.body(size: 12, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
                  ],
                ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
                    onPressed: () => _deleteTransaction(t),
                    tooltip: 'Delete',
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SkeletonLoader(width: 40, height: 40, borderRadius: 20, isDark: isDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 120, height: 14, isDark: isDark),
                      const SizedBox(height: 8),
                      SkeletonLoader(width: 80, height: 12, isDark: isDark),
                    ],
                  ),
                ),
                SkeletonLoader(width: 70, height: 16, isDark: isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
