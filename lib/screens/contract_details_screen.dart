import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/permission_provider.dart';
import '../services/api_service.dart';
import '../models/contract.dart';
import '../models/permission_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/skeleton_loader.dart';
import 'contract_form_screen.dart';

class ContractDetailsScreen extends StatefulWidget {
  final Contract contract;

  const ContractDetailsScreen({super.key, required this.contract});

  @override
  State<ContractDetailsScreen> createState() => _ContractDetailsScreenState();
}

class _ContractDetailsScreenState extends State<ContractDetailsScreen> {
  final ApiService _apiService = ApiService();
  List<StatementEntry>? _statement;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // Mutable copy of widget.contract -- refreshed after a payment so the
  // summary card reflects the new balance/status without leaving the
  // screen (widget.contract itself is a snapshot from the list screen).
  late Contract _contract;
  bool _isAddingPayment = false;

  @override
  void initState() {
    super.initState();
    _contract = widget.contract;
    // Default to current month
    _startDate = DateTime(_startDate.year, _startDate.month, 1);
    _endDate = DateTime(_endDate.year, _endDate.month + 1, 0);
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getContractStatement(
      _contract.id,
      startDate: Formatters.formatDateForApi(_startDate),
      endDate: Formatters.formatDateForApi(_endDate),
    );

    setState(() {
      if (result.isSuccess && result.data != null) {
        final statementData = result.data!['statement'] as List;
        _statement =
            statementData.map((item) => StatementEntry.fromJson(item)).toList();
        _errorMessage = null;
      } else {
        _statement = null;
        _errorMessage = result.message ?? 'Failed to load statement';
      }
      _isLoading = false;
    });
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _startDate = date);
      _loadStatement();
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _endDate = date);
      _loadStatement();
    }
  }

  Future<void> _addPayment() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime paymentDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Daily rate: ${Formatters.formatCurrency(_contract.returnAmount)}'),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: paymentDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null)
                    setDialogState(() => paymentDate = picked);
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(Formatters.formatDate(
                    Formatters.formatDateForApi(paymentDate))),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      amountController.dispose();
      descriptionController.dispose();
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    final description = descriptionController.text.trim();
    amountController.dispose();
    descriptionController.dispose();

    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a valid amount'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isAddingPayment = true);
    final response = await _apiService.addContractPayment(
      _contract.id,
      amount: amount,
      date: Formatters.formatDateForApi(paymentDate),
      description: description,
    );
    if (!mounted) return;
    setState(() => _isAddingPayment = false);

    if (response.isSuccess && response.data != null) {
      final updated = response.data!['contract'] as Map<String, dynamic>?;
      if (updated != null) {
        setState(() =>
            _contract = Contract.fromJson({..._contract.toJson(), ...updated}));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.message ?? 'Payment recorded'),
            backgroundColor: AppColors.success),
      );
      _loadStatement();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.message ?? 'Failed to record payment'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final canAddPayment = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.contractsPaymentsAdd);
    final canAdd = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.contractsAdd);

    return Scaffold(
      appBar: AppBar(
        title: Text(_contract.name),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (canAdd)
            IconButton(
              icon: const Icon(Icons.autorenew),
              tooltip: 'Renew',
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContractFormScreen(renewFrom: _contract),
                  ),
                );
                if (saved == true && mounted) Navigator.pop(context, true);
              },
            ),
        ],
      ),
      floatingActionButton: canAddPayment
          ? FloatingActionButton.extended(
              onPressed: _isAddingPayment ? null : _addPayment,
              icon: _isAddingPayment
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add),
              label: const Text('Add Payment'),
              backgroundColor: AppColors.success,
            )
          : null,
      body: Column(
        children: [
          // Contract summary card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _contract.contractDescription,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      ),
                      _buildStatusBadge(_contract),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Balance',
                          Formatters.formatCurrency(_contract.balance), isDark),
                      _buildSummaryItem('Profit',
                          Formatters.formatCurrency(_contract.profit), isDark),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Days Paid',
                          _contract.daysPaid.toStringAsFixed(0), isDark),
                      _buildSummaryItem('Days Unpaid',
                          _contract.daysUnpaid.toStringAsFixed(0), isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Date range selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectStartDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      Formatters.formatDate(
                          Formatters.formatDateForApi(_startDate)),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to',
                      style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight)),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectEndDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      Formatters.formatDate(
                          Formatters.formatDateForApi(_endDate)),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Statement list
          Expanded(
            child: _isLoading
                ? _buildSkeletonList(isDark)
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _loadStatement,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _statement == null || _statement!.isEmpty
                        ? const Center(
                            child: Text('No statement data available'))
                        : RefreshIndicator(
                            onRefresh: _loadStatement,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _statement!.length,
                              itemBuilder: (context, index) {
                                final entry = _statement![index];
                                return _buildStatementEntry(entry, isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 4),
    );
  }

  /// Same status scheme as ContractsScreen's card -- see its doc comment.
  Widget _buildStatusBadge(Contract contract) {
    final Color color;
    final String label;
    switch (contract.status) {
      case 'completed':
        color = AppColors.success;
        label = 'Completed';
        break;
      case 'on_track':
        color = AppColors.success;
        label = 'On Track';
        break;
      case 'behind':
        color = AppColors.warning;
        label = 'Behind ${contract.daysUnpaid.toStringAsFixed(0)}d';
        break;
      default:
        color = AppColors.error;
        label = 'Behind ${contract.daysUnpaid.toStringAsFixed(0)}d';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildStatementEntry(StatementEntry entry, bool isDark) {
    final isOpening = entry.type == 'opening';
    final isClosing = entry.type == 'closing';
    final isSpecial = isOpening || isClosing;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSpecial ? 2 : 1,
      color: isSpecial
          ? (isDark
              ? AppColors.darkSurface
              : AppColors.primary.withOpacity(0.05))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and description
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.description,
                  style: TextStyle(
                    fontSize: isSpecial ? 14 : 13,
                    fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
                Text(
                  Formatters.formatDate(entry.date),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? AppColors.darkTextLight : AppColors.textLight,
                    fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Financial details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Credit
                Expanded(
                  child: _buildAmountColumn(
                    'Credit',
                    entry.credit,
                    AppColors.success,
                    isDark: isDark,
                  ),
                ),
                // Debit
                Expanded(
                  child: _buildAmountColumn(
                    'Debit',
                    entry.debit,
                    AppColors.error,
                    isDark: isDark,
                  ),
                ),
                // Balance
                Expanded(
                  child: _buildAmountColumn(
                    'Balance',
                    entry.balance,
                    entry.balance >= 0 ? AppColors.success : AppColors.error,
                    isBold: true,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountColumn(String label, double amount, Color color,
      {bool isBold = false, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Formatters.formatCurrency(amount),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: amount == 0
                ? (isDark ? AppColors.darkTextLight : AppColors.textLight)
                : color,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) => _buildSkeletonCard(isDark),
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SkeletonLoader(
                width: 40, height: 40, borderRadius: 8, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 100, height: 14, isDark: isDark),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: 80, height: 12, isDark: isDark),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SkeletonLoader(width: 70, height: 14, isDark: isDark),
                const SizedBox(height: 4),
                SkeletonLoader(width: 50, height: 14, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
