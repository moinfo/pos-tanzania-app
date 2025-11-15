import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../models/customer.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../utils/formatters.dart' show Formatters;
import '../../utils/constants.dart';

class CustomerTransactionsScreen extends StatefulWidget {
  final int? customerId;

  const CustomerTransactionsScreen({super.key, this.customerId});

  @override
  State<CustomerTransactionsScreen> createState() => _CustomerTransactionsScreenState();
}

class _CustomerTransactionsScreenState extends State<CustomerTransactionsScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;

  List<Deposit> _deposits = [];
  List<Withdrawal> _withdrawals = [];
  List<Customer> _customers = [];
  Customer? _selectedCustomer;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCustomers();
    if (widget.customerId != null) {
      _loadTransactions();
    }
  }

  void _handleTabChange() {
    setState(() {}); // Rebuild to update FAB
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final response = await _apiService.getCustomers(limit: 1000);
      if (response.isSuccess && mounted) {
        setState(() {
          _customers = response.data ?? [];
          if (widget.customerId != null) {
            _selectedCustomer = _customers.firstWhere(
              (c) => c.personId == widget.customerId,
              orElse: () => _customers.first,
            );
          }
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadTransactions() async {
    if (_selectedCustomer == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      final depositsResponse = await _apiService.getDeposits(
        customerId: _selectedCustomer!.personId,
        startDate: startDateStr,
        endDate: endDateStr,
      );

      final withdrawalsResponse = await _apiService.getWithdrawals(
        customerId: _selectedCustomer!.personId,
        startDate: startDateStr,
        endDate: endDateStr,
      );

      if (depositsResponse.isSuccess && withdrawalsResponse.isSuccess && mounted) {
        setState(() {
          _deposits = depositsResponse.data ?? [];
          _withdrawals = withdrawalsResponse.data ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = depositsResponse.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load transactions: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddTransactionDialog(bool isDeposit) async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first')),
      );
      return;
    }

    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isDeposit ? 'Add Deposit' : 'Add Withdrawal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Customer: ${_selectedCustomer!.firstName} ${_selectedCustomer!.lastName}'),
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
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
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
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
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

                Navigator.pop(context, true);

                final formData = TransactionFormData(
                  customerId: _selectedCustomer!.personId,
                  amount: amount,
                  description: descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                  date: DateFormat('yyyy-MM-dd').format(selectedDate),
                );

                final response = isDeposit
                    ? await _apiService.addDeposit(formData)
                    : await _apiService.addWithdrawal(formData);

                if (context.mounted) {
                  if (response.isSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isDeposit
                              ? 'Deposit added successfully'
                              : 'Withdrawal added successfully',
                        ),
                      ),
                    );
                    _loadTransactions();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response.message)),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDepositDialog(Deposit deposit) async {
    final amountController = TextEditingController(text: deposit.amount.toString());
    final descriptionController = TextEditingController(text: deposit.description);
    DateTime selectedDate = DateFormat('yyyy-MM-dd').parse(deposit.date);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Deposit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'TZS ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
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
                  },
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

                final formData = TransactionFormData(
                  customerId: deposit.customerId,
                  amount: amount,
                  description: descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                  date: DateFormat('yyyy-MM-dd').format(selectedDate),
                );

                final response = await _apiService.updateDeposit(deposit.id, formData);

                if (context.mounted) {
                  if (response.isSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deposit updated successfully')),
                    );
                    _loadTransactions();
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

  Future<void> _deleteDeposit(Deposit deposit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deposit'),
        content: Text(
          'Are you sure you want to delete this deposit of ${Formatters.formatCurrency(deposit.amount)}?',
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
      final response = await _apiService.deleteDeposit(deposit.id);
      if (context.mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deposit deleted successfully')),
          );
          _loadTransactions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );
        }
      }
    }
  }

  Future<void> _showEditWithdrawalDialog(Withdrawal withdrawal) async {
    final amountController = TextEditingController(text: withdrawal.amount.toString());
    final descriptionController = TextEditingController(text: withdrawal.description);
    DateTime selectedDate = DateFormat('yyyy-MM-dd').parse(withdrawal.date);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Withdrawal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'TZS ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
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
                  },
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

                final formData = TransactionFormData(
                  customerId: withdrawal.customerId,
                  amount: amount,
                  description: descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                  date: DateFormat('yyyy-MM-dd').format(selectedDate),
                );

                final response = await _apiService.updateWithdrawal(withdrawal.id, formData);

                if (context.mounted) {
                  if (response.isSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Withdrawal updated successfully')),
                    );
                    _loadTransactions();
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

  Future<void> _deleteWithdrawal(Withdrawal withdrawal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Withdrawal'),
        content: Text(
          'Are you sure you want to delete this withdrawal of ${Formatters.formatCurrency(withdrawal.amount)}?',
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
      final response = await _apiService.deleteWithdrawal(withdrawal.id);
      if (context.mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Withdrawal deleted successfully')),
          );
          _loadTransactions();
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
      appBar: AppBar(
        title: const Text('Customer Transactions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Deposits'),
            Tab(text: 'Withdrawals'),
          ],
        ),
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
                _loadTransactions();
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
                : [AppColors.lightBackground, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Customer Selector
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GlassmorphicCard(
                child: DropdownButtonFormField<Customer>(
                  value: _selectedCustomer,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Customer',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: _customers.map((customer) {
                    return DropdownMenuItem(
                      value: customer,
                      child: Text(
                        '${customer.firstName} ${customer.lastName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (customer) {
                    setState(() {
                      _selectedCustomer = customer;
                    });
                    _loadTransactions();
                  },
                ),
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDepositsList(permissionProvider),
                            _buildWithdrawalsList(permissionProvider),
                          ],
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(permissionProvider),
    );
  }

  Widget? _buildFloatingActionButton(PermissionProvider permissionProvider) {
    final isOnDepositsTab = _tabController.index == 0;

    if (isOnDepositsTab) {
      // Deposits tab - check deposits_add permission
      if (!permissionProvider.hasPermission(PermissionIds.transactionsDepositsAdd)) {
        return null;
      }
      return FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(true),
        icon: const Icon(Icons.add),
        label: const Text('Add Deposit'),
      );
    } else {
      // Withdrawals tab - check withdrawals_add permission
      if (!permissionProvider.hasPermission(PermissionIds.transactionsWithdrawalsAdd)) {
        return null;
      }
      return FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(false),
        icon: const Icon(Icons.add),
        label: const Text('Add Withdrawal'),
      );
    }
  }

  Widget _buildDepositsList(PermissionProvider permissionProvider) {
    if (_deposits.isEmpty) {
      return const Center(child: Text('No deposits found'));
    }

    final canEdit = permissionProvider.hasPermission(PermissionIds.transactionsDepositsEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.transactionsDepositsDelete);
    final hasAnyAction = canEdit || canDelete;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deposits.length,
      itemBuilder: (context, index) {
        final deposit = _deposits[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassmorphicCard(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.2),
                child: const Icon(Icons.arrow_downward, color: Colors.green),
              ),
              title: Text(
                Formatters.formatCurrency(deposit.amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deposit.date),
                  if (deposit.description.isNotEmpty) Text(deposit.description),
                ],
              ),
              trailing: hasAnyAction
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditDepositDialog(deposit);
                        } else if (value == 'delete') {
                          _deleteDeposit(deposit);
                        }
                      },
                      itemBuilder: (context) => [
                        if (canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                        if (canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: AppColors.error),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                      ],
                    )
                  : const Icon(Icons.chevron_right),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWithdrawalsList(PermissionProvider permissionProvider) {
    if (_withdrawals.isEmpty) {
      return const Center(child: Text('No withdrawals found'));
    }

    final canEdit = permissionProvider.hasPermission(PermissionIds.transactionsWithdrawalsEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.transactionsWithdrawalsDelete);
    final hasAnyAction = canEdit || canDelete;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _withdrawals.length,
      itemBuilder: (context, index) {
        final withdrawal = _withdrawals[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassmorphicCard(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.error.withOpacity(0.2),
                child: Icon(Icons.arrow_upward, color: AppColors.error),
              ),
              title: Text(
                Formatters.formatCurrency(withdrawal.amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(withdrawal.date),
                  if (withdrawal.description.isNotEmpty) Text(withdrawal.description),
                ],
              ),
              trailing: hasAnyAction
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditWithdrawalDialog(withdrawal);
                        } else if (value == 'delete') {
                          _deleteWithdrawal(withdrawal);
                        }
                      },
                      itemBuilder: (context) => [
                        if (canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                        if (canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: AppColors.error),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                      ],
                    )
                  : const Icon(Icons.chevron_right),
            ),
          ),
        );
      },
    );
  }
}
