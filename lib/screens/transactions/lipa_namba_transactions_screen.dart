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
      appBar: AppBar(
        title: const Text('Lipa Namba Transactions'),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [const Color(0xFFF9FAFB), const Color(0xFFF3F4F6)],
          ),
        ),
        child: _isLoading
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
                      if (_summary != null) _buildSummaryCard(isDark),
                      Expanded(child: _buildTransactionsList(isDark, canDelete)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final s = _summary!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassmorphicCard(
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryItem(
                    'Deposits',
                    '${Formatters.formatCurrency(s.totalDeposits)} (${s.depositCount})',
                    AppColors.success,
                    isDark,
                  ),
                  _summaryItem(
                    'Withdrawals',
                    '${Formatters.formatCurrency(s.totalWithdraws)} (${s.withdrawCount})',
                    AppColors.error,
                    isDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryItem('Fees', Formatters.formatCurrency(s.totalFees), AppColors.primary, isDark),
                  _summaryItem('Net', Formatters.formatCurrency(s.net), AppColors.primary, isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color valueColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280)),
        ),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildTransactionsList(bool isDark, bool canDelete) {
    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          'No transactions found',
          style: TextStyle(color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final t = _transactions[index];
        final typeColor = t.isDeposit ? AppColors.success : AppColors.error;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassmorphicCard(
            isDark: isDark,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: typeColor,
                child: Icon(t.isDeposit ? Icons.arrow_downward : Icons.arrow_upward, color: Colors.white),
              ),
              title: Text(
                t.clientName.isNotEmpty ? t.clientName : t.lipaNambaName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : const Color(0xFF1F2937),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t.lipaNambaName} · ${t.transactionDate}',
                    style: TextStyle(color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280)),
                  ),
                  if (t.clientPhone.isNotEmpty)
                    Text(
                      t.clientPhone,
                      style: TextStyle(color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280)),
                    ),
                  Text(
                    t.isDeposit && t.fee > 0
                        ? '${Formatters.formatCurrency(t.amount)} + fee ${Formatters.formatCurrency(t.fee)}'
                        : Formatters.formatCurrency(t.amount),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: typeColor),
                  ),
                ],
              ),
              trailing: canDelete
                  ? IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () => _deleteTransaction(t),
                      tooltip: 'Delete',
                    )
                  : null,
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
