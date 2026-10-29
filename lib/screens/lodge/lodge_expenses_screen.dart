import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// `GET/POST lodge/expenses` -- README 3.13.
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
    final response = await _apiService.getLodgeExpenses();
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

  Future<void> _showAddExpenseSheet() async {
    final categoriesResponse = await _apiService.getLodgeExpenseCategories();
    if (!mounted) return;
    if (!categoriesResponse.isSuccess || categoriesResponse.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(categoriesResponse.message), backgroundColor: AppColors.error),
      );
      return;
    }

    final categories = ((categoriesResponse.data!['categories'] as List<dynamic>?) ?? [])
        .map((c) => LodgeExpenseCategory.fromJson(Map<String, dynamic>.from(c)))
        .toList();
    final defaultCategoryId = categoriesResponse.data!['default_category_id'];

    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final paymentTypes = const ['Cash', 'Bank', 'Lipa Namba'];
    String paymentType = paymentTypes.first;
    int? categoryId = categories.isNotEmpty
        ? (categories.any((c) => c.id == defaultCategoryId) ? defaultCategoryId : categories.first.id)
        : null;

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
                  DropdownButtonFormField<String>(
                    value: paymentType,
                    decoration: const InputDecoration(labelText: 'Payment type', border: OutlineInputBorder()),
                    items: paymentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setSheetState(() => paymentType = v ?? paymentType),
                  ),
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
      ),
      floatingActionButton: permissions.hasPermission(PermissionIds.lodgeExpensesAdd)
          ? FloatingActionButton(
              onPressed: _showAddExpenseSheet,
              backgroundColor: AppColors.brandPrimary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Try again')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
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
                              trailing: Text(Formatters.formatCurrency(e.amount)),
                            ),
                          )),
                    ],
                  ),
                ),
    );
  }
}
