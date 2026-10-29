import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../../utils/formatters.dart' show Formatters;
import '../../utils/constants.dart';
import 'wakala_theme.dart';

class BankBasisScreen extends StatefulWidget {
  const BankBasisScreen({super.key});

  @override
  State<BankBasisScreen> createState() => _BankBasisScreenState();
}

class _BankBasisScreenState extends State<BankBasisScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;

  List<BankBasisCategory> _categories = [];
  List<BankBasisTransaction> _transactions = [];
  double _total = 0;
  Map<int, double> _categoryTotals = {};

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadData();
  }

  void _handleTabChange() {
    setState(() {}); // Rebuild to update FAB
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categoriesResponse = await _apiService.getBankBasisCategories();

      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);
      final transactionsResponse = await _apiService.getBankBasisTransactions(
        startDate: startDateStr,
        endDate: endDateStr,
      );

      if (categoriesResponse.isSuccess && transactionsResponse.isSuccess && mounted) {
        setState(() {
          _categories = categoriesResponse.data ?? [];
          _transactions = transactionsResponse.data?.transactions ?? [];
          _total = transactionsResponse.data?.total ?? 0;

          // Calculate totals per category
          _categoryTotals.clear();
          for (var transaction in _transactions) {
            _categoryTotals[transaction.bankBasisId] =
                (_categoryTotals[transaction.bankBasisId] ?? 0) + transaction.amount;
          }

          _isLoading = false;
        });
      } else {
        setState(() {
          _error = categoriesResponse.message ?? transactionsResponse.message;
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

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bank Basis Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name (e.g., M-Pesa, Airtel Money)'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              Navigator.pop(context);

              final response = await _apiService.addBankBasisCategory(
                name: nameController.text,
                description: descriptionController.text.isEmpty
                    ? null
                    : descriptionController.text,
              );

              if (context.mounted) {
                if (response.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Category added successfully')),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(response.message)),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTransactionDialog() async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a category first')),
      );
      return;
    }

    BankBasisCategory? selectedCategory = _categories.first;
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    // Without the date grant the entry is pinned to today, matching how web
    // renders the date input readonly (views/transactions/footer.php).
    final canChangeDate = Provider.of<PermissionProvider>(context, listen: false)
        .hasPermission(PermissionIds.transactionsBankBasisDate);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Bank/Mobile Money Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<BankBasisCategory>(
                  value: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'TZS ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  trailing: canChangeDate ? const Icon(Icons.calendar_today) : null,
                  enabled: canChangeDate,
                  onTap: canChangeDate
                      ? () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                Navigator.pop(context);

                final response = await _apiService.addBankBasisTransaction(
                  bankBasisId: selectedCategory!.id,
                  amount: amount,
                  date: DateFormat('yyyy-MM-dd').format(selectedDate),
                );

                if (context.mounted) {
                  if (response.isSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaction added successfully')),
                    );
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response.message)),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditCategoryDialog(BankBasisCategory category) async {
    final nameController = TextEditingController(text: category.name);
    final descriptionController = TextEditingController(text: category.description);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bank Basis Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              Navigator.pop(context);

              final response = await _apiService.updateBankBasisCategory(
                category.id,
                name: nameController.text,
                description: descriptionController.text.isEmpty
                    ? null
                    : descriptionController.text,
              );

              if (context.mounted) {
                if (response.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Category updated successfully')),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(response.message)),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBankBasisCategory(BankBasisCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _apiService.deleteBankBasisCategory(category.id);
      if (context.mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted successfully')),
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

  Future<void> _showEditTransactionDialog(BankBasisTransaction transaction) async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No categories available')),
      );
      return;
    }

    BankBasisCategory? selectedCategory = _categories.firstWhere(
      (c) => c.id == transaction.bankBasisId,
      orElse: () => _categories.first,
    );
    final amountController = TextEditingController(text: transaction.amount.toString());
    DateTime selectedDate = DateFormat('yyyy-MM-dd').parse(transaction.date);
    final canChangeDate = Provider.of<PermissionProvider>(context, listen: false)
        .hasPermission(PermissionIds.transactionsBankBasisDate);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<BankBasisCategory>(
                  value: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'TZS ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  trailing: canChangeDate ? const Icon(Icons.calendar_today) : null,
                  enabled: canChangeDate,
                  onTap: canChangeDate
                      ? () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                Navigator.pop(context);

                final response = await _apiService.updateBankBasisTransaction(
                  transaction.id,
                  bankBasisId: selectedCategory!.id,
                  amount: amount,
                  date: DateFormat('yyyy-MM-dd').format(selectedDate),
                );

                if (context.mounted) {
                  if (response.isSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaction updated successfully')),
                    );
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response.message)),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBankBasisTransaction(BankBasisTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this transaction of ${Formatters.formatCurrency(transaction.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _apiService.deleteBankBasisTransaction(transaction.id);
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: WakalaTheme.appBar(
        isDark: isDark,
        eyebrow: 'Mobile money',
        title: 'Bank Basis',
        actions: [
          // Filtering the transaction list by an arbitrary range is a separate
          // grant from viewing it, mirroring web's $can_search_* gate.
          if (_tabController.index == 1 &&
              permissionProvider.hasPermission(PermissionIds.transactionsBankBasisDateRange))
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
                      child: WakalaSegmentedControl(
                        labels: const ['Categories', 'Transactions'],
                        selectedIndex: _tabController.index,
                        onChanged: (i) => _tabController.animateTo(i),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCategoriesList(permissionProvider, isDark),
                          _buildTransactionsList(permissionProvider, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _buildFloatingActionButton(permissionProvider),
    );
  }

  Widget? _buildFloatingActionButton(PermissionProvider permissionProvider) {
    final isOnCategoriesTab = _tabController.index == 0;

    final VoidCallback? onPressed;
    final String label;
    if (isOnCategoriesTab) {
      // Categories tab - check setting_add permission
      if (!permissionProvider.hasPermission(PermissionIds.transactionsBankBasisSettingAdd)) {
        return null;
      }
      onPressed = _showAddCategoryDialog;
      label = 'Add Category';
    } else {
      // Transactions tab - check add permission
      if (!permissionProvider.hasPermission(PermissionIds.transactionsBankBasisAdd)) {
        return null;
      }
      onPressed = _showAddTransactionDialog;
      label = 'Add Transaction';
    }
    return FloatingActionButton.extended(
      heroTag: 'bank_basis_fab',
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildCategoriesList(PermissionProvider permissionProvider, bool isDark) {
    if (_categories.isEmpty) {
      return Center(
        child: Text(
          'No categories found\n\nAdd categories like M-Pesa, Airtel Money, Bank',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
          ),
        ),
      );
    }

    final canEdit = permissionProvider.hasPermission(PermissionIds.transactionsBankBasisSettingEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.transactionsBankBasisSettingDelete);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: WakalaCard(
            child: Row(
              children: [
                const WakalaIconTile(icon: Icons.account_balance_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name,
                          style: WakalaTheme.display(size: 18, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                      if (category.description.isNotEmpty)
                        Text(category.description, style: WakalaTheme.body(size: 13, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
                    ],
                  ),
                ),
                if (canEdit)
                  _setupActionButton(Icons.edit_outlined, isEdit: true, onTap: () => _showEditCategoryDialog(category)),
                if (canEdit && canDelete) const SizedBox(width: 8),
                if (canDelete)
                  _setupActionButton(Icons.delete_outline, isEdit: false, onTap: () => _deleteBankBasisCategory(category)),
              ],
            ),
          ),
        );
      },
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

  Widget _buildTransactionsList(PermissionProvider permissionProvider, bool isDark) {
    final canEdit = permissionProvider.hasPermission(PermissionIds.transactionsBankBasisEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.transactionsBankBasisDelete);
    final hasAnyAction = canEdit || canDelete;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      children: [
        _buildBalanceCard(isDark),
        const SizedBox(height: 14),
        Text('Transactions',
            style: WakalaTheme.display(size: 13, weight: FontWeight.w700, letterSpacing: 0.9, color: const Color(0xFF6C757D))),
        const SizedBox(height: 10),
        if (_transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No transactions found',
                  style: WakalaTheme.body(size: 14, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280))),
            ),
          )
        else
          ..._transactions.map((transaction) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WakalaCard(
                child: Row(
                  children: [
                    const WakalaIconTile(icon: Icons.account_balance_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(transaction.bankBasisName,
                              style: WakalaTheme.display(size: 17, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                          Text(transaction.date, style: WakalaTheme.body(size: 13, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
                        ],
                      ),
                    ),
                    Text(Formatters.formatCurrency(transaction.amount),
                        style: WakalaTheme.display(size: 18, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                    if (hasAnyAction)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: isDark ? AppColors.darkTextLight : AppColors.text),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditTransactionDialog(transaction);
                          } else if (value == 'delete') {
                            _deleteBankBasisTransaction(transaction);
                          }
                        },
                        itemBuilder: (context) => [
                          if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          if (canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      )
                    else
                      const SizedBox(width: 4),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  /// The "balance card" pattern -- one kv row per category (when there is
  /// more than one), then a charcoal footer band with the grand total.
  /// Mirrors the handover's WCashTx/WBankTx card.
  Widget _buildBalanceCard(bool isDark) {
    final rows = _categoryTotals.length > 1
        ? _categoryTotals.entries
            .map((entry) => MapEntry(
                _categories.firstWhere((c) => c.id == entry.key,
                    orElse: () => BankBasisCategory(id: entry.key, name: 'Unknown', description: '')),
                entry.value))
            .toList()
        : <MapEntry<BankBasisCategory, double>>[];

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
      // IntrinsicHeight: this card sits as a ListView item, which hands the
      // Row unbounded height -- stretch alone needs a bounded cross-axis
      // extent (same fix as WakalaCard in wakala_theme.dart).
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: AppColors.primary),
            Expanded(
              child: Column(
                children: [
                  ...rows.map((entry) => Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(entry.key.name,
                                  style: WakalaTheme.body(size: 14, color: isDark ? AppColors.darkText : AppColors.text),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(Formatters.formatCurrency(entry.value),
                                style: WakalaTheme.display(size: 15, weight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.text)),
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
                        Text(Formatters.formatCurrency(_total),
                            style: WakalaTheme.display(size: 24, weight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    );
  }
}
