import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// `GET/POST lodge/expenses` -- README 3.13: period total + by-category
/// breakdown, date range (gated on lodge_expenses_date_range_filter), list
/// with delete.
class LodgeExpensesScreen extends StatefulWidget {
  const LodgeExpensesScreen({super.key});

  @override
  State<LodgeExpensesScreen> createState() => _LodgeExpensesScreenState();
}

class _LodgeExpensesScreenState extends State<LodgeExpensesScreen> {
  final ApiService _apiService = ApiService();
  LodgeExpensesList? _data;
  bool _isLoading = true;
  String? _errorMessage;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response = await _apiService.getLodgeExpenses(
      startDate: Formatters.formatDateForApi(_startDate),
      endDate: Formatters.formatDateForApi(_endDate),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _data = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
    _load();
  }

  Map<String, double> _byCategory() {
    final totals = <String, double>{};
    for (final e in _data!.expenses) {
      final key = e.categoryName ?? 'Uncategorised';
      totals[key] = (totals[key] ?? 0) + e.amount;
    }
    return totals;
  }

  Future<void> _deleteExpense(LodgeExpense e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense'),
        content: Text('Delete "${e.description}" (${Formatters.formatCurrency(e.amount)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final response = await _apiService.deleteLodgeExpense(e.expenseId);
    if (!mounted) return;
    if (response.isSuccess) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showAddExpenseSheet() async {
    final results = await Future.wait([
      _apiService.getLodgeExpenseCategories(),
      _apiService.getLodgeRooms(purpose: null),
    ]);
    if (!mounted) return;
    final categoriesResponse = results[0];
    final roomsResponse = results[1];
    if (!categoriesResponse.isSuccess || categoriesResponse.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(categoriesResponse.message), backgroundColor: AppColors.error),
      );
      return;
    }

    final categoriesData = categoriesResponse.data as Map<String, dynamic>;
    final categories = ((categoriesData['categories'] as List<dynamic>?) ?? [])
        .map((c) => LodgeExpenseCategory.fromJson(Map<String, dynamic>.from(c)))
        .toList();
    final defaultCategoryId = categoriesData['default_category_id'];
    final rooms = roomsResponse.isSuccess ? (roomsResponse.data as List<LodgeRoom>? ?? []) : <LodgeRoom>[];

    final canBackdate = context.read<PermissionProvider>().hasPermission(PermissionIds.lodgeExpensesDate);
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final paymentTypes = const ['Cash', 'Bank', 'Lipa Namba'];
    String paymentType = paymentTypes.first;
    int? categoryId = categories.isNotEmpty
        ? (categories.any((c) => c.id == defaultCategoryId) ? defaultCategoryId : categories.first.id)
        : null;
    LodgeRoom? selectedRoom; // null = whole lodge
    DateTime expenseDate = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  if (categories.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: categoryId,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: categories
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setSheetState(() => categoryId = v),
                    ),
                  const SizedBox(height: 10),
                  if (rooms.isNotEmpty)
                    DropdownButtonFormField<int?>(
                      value: selectedRoom?.roomId,
                      decoration: const InputDecoration(labelText: 'Room (optional)', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Whole lodge')),
                        ...rooms.map((r) => DropdownMenuItem(value: r.roomId, child: Text(r.roomNumber))),
                      ],
                      onChanged: (v) => setSheetState(
                          () => selectedRoom = v == null ? null : rooms.firstWhere((r) => r.roomId == v)),
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: paymentType,
                    decoration: const InputDecoration(labelText: 'Payment type', border: OutlineInputBorder()),
                    items: paymentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setSheetState(() => paymentType = v ?? paymentType),
                  ),
                  if (canBackdate) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: expenseDate,
                          firstDate: DateTime(DateTime.now().year - 2),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setSheetState(() => expenseDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                        child: Text(Formatters.formatDateForApi(expenseDate)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text);
                        if (amount == null || amount <= 0 || descriptionController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Fill in the amount and description'), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        Navigator.pop(sheetContext);
                        final response = await _apiService.createLodgeExpense(
                          amount: amount,
                          description: descriptionController.text.trim(),
                          paymentType: paymentType,
                          expenseCategoryId: categoryId,
                          roomId: selectedRoom?.roomId,
                          date: canBackdate ? Formatters.formatDateForApi(expenseDate) : null,
                        );
                        if (!mounted) return;
                        if (response.isSuccess) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Expense saved.'), backgroundColor: AppColors.success),
                          );
                          _load();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();
    final headerColor = isDark ? AppColors.darkSurface : AppColors.brandPrimary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        title: const Text('Expenses'),
        actions: [
          if (permissions.hasPermission(PermissionIds.lodgeExpensesDateRangeFilter))
            IconButton(icon: const Icon(Icons.date_range, size: 20), onPressed: _pickRange),
        ],
      ),
      floatingActionButton: permissions.hasPermission(PermissionIds.lodgeExpensesAdd)
          ? FloatingActionButton(
              heroTag: 'lodge_expenses_fab',
              onPressed: _showAddExpenseSheet,
              backgroundColor: AppColors.brandPrimary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _buildBody(isDark, permissions),
    );
  }

  Widget _buildBody(bool isDark, PermissionProvider permissions) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final canDelete = permissions.hasPermission(PermissionIds.lodgeExpensesDelete);
    final byCategory = _byCategory();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            '${Formatters.formatDateForApi(_startDate)} to ${Formatters.formatDateForApi(_endDate)}',
            style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight),
          ),
          const SizedBox(height: 4),
          Text('Total: ${Formatters.formatCurrency(_data!.total)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ..._data!.expenses.map((e) => Card(
                color: isDark ? AppColors.darkCard : Colors.white,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  title: Text(e.description),
                  subtitle: Text(
                      '${e.categoryName ?? ''}${e.roomNumber != null ? ' · Room ${e.roomNumber}' : ''} · ${Formatters.formatDate(e.date)}'),
                  trailing: canDelete
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Formatters.formatCurrency(e.amount)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => _deleteExpense(e),
                            ),
                          ],
                        )
                      : Text(Formatters.formatCurrency(e.amount)),
                ),
              )),
          if (byCategory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('By category', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.darkText : AppColors.lightText)),
            const SizedBox(height: 8),
            ...byCategory.entries.map((entry) {
              final pct = _data!.total > 0 ? entry.value / _data!.total : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 90, child: Text(entry.key, style: const TextStyle(fontSize: 12.5))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(Formatters.formatCompactCurrency(entry.value), style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
