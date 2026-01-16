import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../models/tra.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../services/tra_service.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';
import 'new_tra_purchase_screen.dart';

class TRAExpensesScreen extends StatefulWidget {
  final List<EFDDevice> efds;
  final int? initialEfdId;
  final bool showAppBar;

  const TRAExpensesScreen({
    super.key,
    required this.efds,
    this.initialEfdId,
    this.showAppBar = true,
  });

  @override
  State<TRAExpensesScreen> createState() => _TRAExpensesScreenState();
}

class _TRAExpensesScreenState extends State<TRAExpensesScreen> {
  final TRAService _traService = TRAService();
  final _currencyFormat = NumberFormat('#,##0', 'en_US');

  List<TRAPurchase> _expenses = [];
  TRAPurchasesSummary? _summary;
  int? _selectedEfdId;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedEfdId = widget.initialEfdId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExpenses();
    });
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      final result = await _traService.getExpenses(
        fromDate: startDateStr,
        toDate: endDateStr,
        efdId: _selectedEfdId,
      );

      if (mounted) {
        setState(() {
          _expenses = result.items;
          _summary = result.summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final permissionProvider = context.read<PermissionProvider>();
    final hasDateRangePermission = permissionProvider.hasPermission(PermissionIds.traDateFilter);

    if (!hasDateRangePermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to change the date range'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

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

  Future<void> _deleteExpense(TRAPurchase expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete expense "${expense.itemName}"?'),
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

    if (confirm == true) {
      final result = await _traService.deleteExpense(expense.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? AppColors.success : AppColors.error,
          ),
        );
        if (result.success) {
          _loadExpenses();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final permissionProvider = context.watch<PermissionProvider>();

    final hasAddPermission = permissionProvider.hasPermission(PermissionIds.traAddExpenses);
    final hasEditPermission = permissionProvider.hasPermission(PermissionIds.traEditExpenses);
    final hasDeletePermission = permissionProvider.hasPermission(PermissionIds.traDeleteExpenses);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: widget.showAppBar ? AppBar(
        title: const Text('TRADE Expenses'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (hasAddPermission)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewTRAPurchaseScreen(
                      efds: widget.efds,
                      isExpense: true,
                    ),
                  ),
                );
                if (result == true) {
                  _loadExpenses();
                }
              },
            ),
        ],
      ) : null,
      floatingActionButton: !widget.showAppBar && hasAddPermission ? FloatingActionButton(
        heroTag: 'tra_expenses_fab',
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewTRAPurchaseScreen(
                efds: widget.efds,
                isExpense: true,
              ),
            ),
          );
          if (result == true) {
            _loadExpenses();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      body: RefreshIndicator(
        onRefresh: _loadExpenses,
        child: Column(
          children: [
            // Filters
            _buildFilterSection(isDark, permissionProvider),

            // Summary
            if (_summary != null && !_isLoading)
              _buildSummarySection(isDark),

            // List
            Expanded(
              child: _isLoading
                  ? _buildLoadingSkeleton()
                  : _errorMessage != null
                      ? _buildErrorWidget()
                      : _expenses.isEmpty
                          ? _buildEmptyWidget(isDark)
                          : _buildExpensesList(isDark, hasEditPermission, hasDeletePermission),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isDark, PermissionProvider permissionProvider) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final hasDatePermission = permissionProvider.hasPermission(PermissionIds.traDateFilter);
    final hasAllEfdPermission = permissionProvider.hasPermission(PermissionIds.traFilterAllEfd);

    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Column(
        children: [
          // Date Range
          InkWell(
            onTap: hasDatePermission ? _selectDateRange : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                    ),
                  ),
                  if (hasDatePermission)
                    Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // EFD Filter
          if (widget.efds.isNotEmpty && hasAllEfdPermission)
            DropdownButtonFormField<int?>(
              value: _selectedEfdId,
              decoration: InputDecoration(
                labelText: 'EFD Device',
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              dropdownColor: isDark ? AppColors.darkCard : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All EFDs')),
                ...widget.efds.map((efd) => DropdownMenuItem<int?>(
                      value: efd.id,
                      child: Text(efd.name),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedEfdId = value);
                _loadExpenses();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? AppColors.darkCard.withOpacity(0.5) : Colors.red.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Expenses', _summary!.totalPurchases, isDark),
          _buildSummaryItem('Turnover', _summary!.totalTurnover, isDark),
          _buildSummaryItem('Taxes', _summary!.totalTaxes, isDark),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'TZS ${_currencyFormat.format(value)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.lightText,
          ),
        ),
      ],
    );
  }

  Widget _buildExpensesList(bool isDark, bool hasEdit, bool hasDelete) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return _buildExpenseCard(expense, isDark, hasEdit, hasDelete);
      },
    );
  }

  Widget _buildExpenseCard(TRAPurchase expense, bool isDark, bool hasEdit, bool hasDelete) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.itemName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expense.supplierName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (hasEdit)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: AppColors.primary,
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NewTRAPurchaseScreen(
                                efds: widget.efds,
                                purchase: expense,
                                isExpense: true,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadExpenses();
                          }
                        },
                      ),
                    if (hasDelete)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        color: AppColors.error,
                        onPressed: () => _deleteExpense(expense),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice: ${expense.taxInvoice}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(DateTime.parse(expense.date)),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        expense.purchaseType,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'TZS ${_currencyFormat.format(expense.totalAmount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSmallInfo('Excl. VAT', expense.amountVatExc, isDark),
                _buildSmallInfo('VAT', expense.vatAmount, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallInfo(String label, double value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        Text(
          'TZS ${_currencyFormat.format(value)}',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : AppColors.lightTextLight,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SkeletonLoader(width: double.infinity, height: 150, isDark: isDark),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadExpenses,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.money_off,
            size: 64,
            color: isDark ? Colors.white54 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No expenses found',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
