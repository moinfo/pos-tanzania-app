import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../models/permission_model.dart';
import 'wakala_theme.dart';

class WakalaExpensesScreen extends StatefulWidget {
  const WakalaExpensesScreen({super.key});

  @override
  State<WakalaExpensesScreen> createState() => _WakalaExpensesScreenState();
}

class _WakalaExpensesScreenState extends State<WakalaExpensesScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<WakalaExpense> _expenses = [];
  double _total = 0;

  // Date range state - default to today
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    try {
      final response = await _apiService.getWakalaExpenses(
        startDate: startDateStr,
        endDate: endDateStr,
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _expenses = response.data!.expenses;
          _total = response.data!.total;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load wakala expenses';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      _loadExpenses();
    }
  }

  Future<void> _deleteExpense(int expenseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this wakala expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _apiService.deleteWakalaExpense(expenseId);

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wakala expense deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadExpenses();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to delete expense'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (context) => WakalaExpenseFormDialog(
        onSaved: () {
          Navigator.pop(context);
          _loadExpenses();
        },
      ),
    );
  }

  void _showEditExpenseDialog(WakalaExpense expense) {
    showDialog(
      context: context,
      builder: (context) => WakalaExpenseFormDialog(
        expense: expense,
        onSaved: () {
          Navigator.pop(context);
          _loadExpenses();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    // Watched, not read, so the screen re-gates itself when permissions refresh.
    final canChangeDateRange = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.transactionsWakalaExpensesDateRange);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: WakalaTheme.appBar(
        isDark: isDark,
        eyebrow: 'Money out',
        title: 'Wakala Expenses',
        actions: [
          if (canChangeDateRange)
            IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: _selectDateRange,
              tooltip: 'Filter by date range',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.date_range, size: 18, color: Color(0xFF1E40AF)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _startDate == _endDate
                          ? DateFormat('MMMM d, yyyy').format(_startDate)
                          : '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                      style: WakalaTheme.display(size: 15, weight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.text),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: canChangeDateRange ? _selectDateRange : null,
                    icon: const Icon(Icons.edit_calendar, size: 16),
                    label: const Text('Change'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1E40AF),
                      backgroundColor: const Color(0xFFDBEAFE),
                      textStyle: WakalaTheme.body(size: 14, weight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_isLoading && _expenses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: WakalaCard(
                railColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const WakalaIconTile(icon: Icons.account_balance_wallet_outlined, tint: WakalaTint.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total expenses', style: WakalaTheme.body(size: 12, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                    text: 'TZS ',
                                    style: WakalaTheme.body(size: 14, weight: FontWeight.w600, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
                                TextSpan(
                                    text: Formatters.formatCurrency(_total),
                                    style: WakalaTheme.display(size: 28, weight: FontWeight.w700, color: const Color(0xFFB91C1C))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadExpenses,
              child: _isLoading
                  ? _buildSkeletonList(isDark)
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                const SizedBox(height: 16),
                                Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton(onPressed: _loadExpenses, child: const Text('Retry')),
                              ],
                            ),
                          ),
                        )
                      : _expenses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long, size: 64, color: isDark ? AppColors.darkTextLight : AppColors.textLight),
                                  const SizedBox(height: 16),
                                  Text('No wakala expenses found',
                                      style: WakalaTheme.body(size: 16, color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _showAddExpenseDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Expense'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                              itemCount: _expenses.length,
                              itemBuilder: (context, index) {
                                final expense = _expenses[index];
                                return _buildExpenseCard(expense, isDark);
                              },
                            ),
            ),
          ),
        ],
      ),
      floatingActionButton: _expenses.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddExpenseDialog,
              icon: const Icon(Icons.add),
              label: const Text('Expense'),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            )
          : null,
    );
  }

  Widget _buildExpenseCard(WakalaExpense expense, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WakalaCard(
        railColor: AppColors.error,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const WakalaIconTile(icon: Icons.receipt_long_outlined, tint: WakalaTint.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(expense.description.isNotEmpty ? expense.description : 'Wakala Expense',
                          style: WakalaTheme.display(size: 18, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                      Text(Formatters.formatDate(expense.date),
                          style: WakalaTheme.body(size: 13, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
                    ],
                  ),
                ),
                Text(Formatters.formatCurrency(expense.amount),
                    style: WakalaTheme.display(size: 18, weight: FontWeight.w700, color: const Color(0xFFB91C1C))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _setupActionButton(Icons.edit_outlined, isEdit: true, onTap: () => _showEditExpenseDialog(expense)),
                const SizedBox(width: 8),
                _setupActionButton(Icons.delete_outline, isEdit: false, onTap: () => _deleteExpense(expense.id)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _setupActionButton(IconData icon, {required bool isEdit, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isEdit ? const Color(0xFFE9ECEF) : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: isEdit ? AppColors.primary : const Color(0xFFB91C1C)),
      ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonLoader(width: 36, height: 36, borderRadius: 8, isDark: isDark),
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
              const SizedBox(height: 8),
              SkeletonLoader(width: double.infinity, height: 12, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

// Wakala Expense Form Dialog
class WakalaExpenseFormDialog extends StatefulWidget {
  final WakalaExpense? expense;
  final VoidCallback onSaved;

  const WakalaExpenseFormDialog({
    super.key,
    this.expense,
    required this.onSaved,
  });

  @override
  State<WakalaExpenseFormDialog> createState() => _WakalaExpenseFormDialogState();
}

class _WakalaExpenseFormDialogState extends State<WakalaExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    if (widget.expense != null) {
      _amountController.text = widget.expense!.amount.toString();
      _descriptionController.text = widget.expense!.description;
      _selectedDate = DateTime.parse(widget.expense!.date);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final formData = WakalaExpenseFormData(
        date: Formatters.formatDateForApi(_selectedDate),
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
      );

      final response = widget.expense == null
          ? await _apiService.addWakalaExpense(formData)
          : await _apiService.updateWakalaExpense(widget.expense!.id, formData);

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.expense == null
                  ? 'Wakala expense added successfully'
                  : 'Wakala expense updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          widget.onSaved();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to save expense'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    // Without this grant the expense is pinned to today, matching how web
    // renders the date input readonly (views/transactions/footer.php).
    final canChangeDate = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.transactionsWakalaExpensesDate);

    // Light mode input decoration
    final lightInputDecoration = InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      labelStyle: TextStyle(
        color: const Color(0xFF6B7280),
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: const Color(0xFF9CA3AF),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.error,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.error,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );

    // Dark mode input decoration
    final darkInputDecoration = InputDecoration(
      filled: true,
      fillColor: AppColors.darkSurface,
      labelStyle: TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w500,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white24,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.error,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.error,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );

    final inputDecoration = isDark ? darkInputDecoration : lightInputDecoration;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: isDark ? 0 : 8,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: isDark
              ? Border.all(color: Colors.white.withOpacity(0.08))
              : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.error.withOpacity(0.8),
                                AppColors.error,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            widget.expense == null ? Icons.add_circle : Icons.edit,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.expense == null
                              ? 'Add Wakala Expense'
                              : 'Edit Wakala Expense',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Date
                  InkWell(
                    onTap: canChangeDate ? _selectDate : null,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: inputDecoration.copyWith(
                        labelText: 'Date',
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                        ),
                      ),
                      child: Text(
                        Formatters.formatDate(_selectedDate.toString()),
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  TextFormField(
                    controller: _amountController,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                      fontSize: 16,
                    ),
                    decoration: inputDecoration.copyWith(
                      labelText: 'Amount (TZS)',
                      prefixIcon: Icon(
                        Icons.payments,
                        color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter amount';
                      }
                      if (double.tryParse(value) == null ||
                          double.parse(value) <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                      fontSize: 16,
                    ),
                    decoration: inputDecoration.copyWith(
                      labelText: 'Description (Optional)',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 48),
                        child: Icon(
                          Icons.description,
                          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                        ),
                      ),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 28),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : const Color(0xFFD1D5DB),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveExpense,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  widget.expense == null ? 'Add Expense' : 'Save Changes',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}