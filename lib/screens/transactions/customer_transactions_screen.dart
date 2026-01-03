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
import '../../widgets/skeleton_loader.dart';
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

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // Search controller for customer search
  final _customerSearchController = TextEditingController();
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCustomers();
    // Always load transactions on startup (shows all if no customer selected)
    _loadTransactions();
  }

  void _handleTabChange() {
    setState(() {}); // Rebuild to update FAB
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  /// Show customer search dialog
  Future<void> _showCustomerSearchDialog(bool isDark) async {
    _filteredCustomers = List.from(_customers);
    _customerSearchController.clear();

    final selected = await showDialog<Customer>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Select Customer'),
            contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  // Search field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _customerSearchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search customer...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (query) {
                        setDialogState(() {
                          if (query.isEmpty) {
                            _filteredCustomers = List.from(_customers);
                          } else {
                            _filteredCustomers = _customers.where((customer) {
                              final fullName = '${customer.firstName} ${customer.lastName}'.toLowerCase();
                              final phone = customer.phoneNumber?.toLowerCase() ?? '';
                              final searchQuery = query.toLowerCase();
                              return fullName.contains(searchQuery) || phone.contains(searchQuery);
                            }).toList();
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Customer list
                  Expanded(
                    child: _filteredCustomers.isEmpty
                        ? Center(
                            child: Text(
                              'No customers found',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = _filteredCustomers[index];
                              final isSelected = _selectedCustomer?.personId == customer.personId;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? AppColors.primary
                                      : (isDark ? AppColors.darkCard : const Color(0xFFE5E7EB)),
                                  child: Text(
                                    customer.firstName.isNotEmpty
                                        ? customer.firstName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? AppColors.darkText : const Color(0xFF1F2937)),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${customer.firstName} ${customer.lastName}',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isDark ? AppColors.darkText : const Color(0xFF1F2937),
                                  ),
                                ),
                                subtitle: customer.phoneNumber != null && customer.phoneNumber!.isNotEmpty
                                    ? Text(
                                        customer.phoneNumber!,
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                                        ),
                                      )
                                    : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                                    : null,
                                onTap: () => Navigator.pop(context, customer),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedCustomer = selected;
      });
      _loadTransactions();
    }
  }

  Future<void> _loadCustomers() async {
    try {
      // Only load boda boda customers for Customer Transactions screen
      final response = await _apiService.getCustomers(limit: 1000, isBodaBoda: true);
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      // If no customer selected, load all transactions for date range
      // If customer selected, load only that customer's transactions
      final depositsResponse = await _apiService.getDeposits(
        customerId: _selectedCustomer?.personId,
        startDate: startDateStr,
        endDate: endDateStr,
      );

      final withdrawalsResponse = await _apiService.getWithdrawals(
        customerId: _selectedCustomer?.personId,
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

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                      context: dialogContext,
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
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                // Return the form data instead of making API call inside dialog
                Navigator.pop(dialogContext, {
                  'amount': amount,
                  'description': descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                  'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    // Handle the result after dialog closes - using parent widget's context
    if (result != null && mounted) {
      final formData = TransactionFormData(
        customerId: _selectedCustomer!.personId,
        amount: result['amount'] as double,
        description: result['description'] as String?,
        date: result['date'] as String,
      );

      final response = isDeposit
          ? await _apiService.addDeposit(formData)
          : await _apiService.addWithdrawal(formData);

      if (mounted) {
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
          await _loadTransactions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );
        }
      }
    }
  }

  Future<void> _showEditDepositDialog(Deposit deposit) async {
    final amountController = TextEditingController(text: deposit.amount.toString());
    final descriptionController = TextEditingController(text: deposit.description);
    DateTime selectedDate = DateFormat('yyyy-MM-dd').parse(deposit.date);

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                      context: dialogContext,
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
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, {
                  'amount': amount,
                  'description': descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                  'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                });
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final formData = TransactionFormData(
        customerId: deposit.customerId,
        amount: result['amount'] as double,
        description: result['description'] as String?,
        date: result['date'] as String,
      );

      final response = await _apiService.updateDeposit(deposit.id, formData);

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deposit updated successfully')),
          );
          await _loadTransactions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );
        }
      }
    }
  }

  Future<void> _deleteDeposit(Deposit deposit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Deposit'),
        content: Text(
          'Are you sure you want to delete this deposit of ${Formatters.formatCurrency(deposit.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final response = await _apiService.deleteDeposit(deposit.id);
      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deposit deleted successfully')),
          );
          await _loadTransactions();
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

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                      context: dialogContext,
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
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, {
                  'amount': amount,
                  'description': descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                  'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                });
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final formData = TransactionFormData(
        customerId: withdrawal.customerId,
        amount: result['amount'] as double,
        description: result['description'] as String?,
        date: result['date'] as String,
      );

      final response = await _apiService.updateWithdrawal(withdrawal.id, formData);

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Withdrawal updated successfully')),
          );
          await _loadTransactions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );
        }
      }
    }
  }

  Future<void> _deleteWithdrawal(Withdrawal withdrawal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Withdrawal'),
        content: Text(
          'Are you sure you want to delete this withdrawal of ${Formatters.formatCurrency(withdrawal.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final response = await _apiService.deleteWithdrawal(withdrawal.id);
      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Withdrawal deleted successfully')),
          );
          await _loadTransactions();
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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
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
                : [const Color(0xFFF9FAFB), const Color(0xFFF3F4F6)],
          ),
        ),
        child: Column(
          children: [
            // Customer Selector (Searchable)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GlassmorphicCard(
                isDark: isDark,
                child: InkWell(
                  onTap: () => _showCustomerSearchDialog(isDark),
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Select Customer',
                      labelStyle: TextStyle(
                        color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: Icon(
                        Icons.search,
                        color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                      ),
                    ),
                    child: Text(
                      _selectedCustomer != null
                          ? '${_selectedCustomer!.firstName} ${_selectedCustomer!.lastName}'
                          : 'Tap to search...',
                      style: TextStyle(
                        color: _selectedCustomer != null
                            ? (isDark ? AppColors.darkText : const Color(0xFF1F2937))
                            : (isDark ? AppColors.darkTextLight : const Color(0xFF9CA3AF)),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildSkeletonList(isDark)
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                            ),
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDepositsList(permissionProvider, isDark),
                            _buildWithdrawalsList(permissionProvider, isDark),
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
      // Deposits tab - check deposit_add permission
      if (!permissionProvider.hasPermission(PermissionIds.transactionsDepositAdd)) {
        return null;
      }
      return FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(true),
        icon: const Icon(Icons.add),
        label: const Text('Add Deposit'),
      );
    } else {
      // Withdrawals tab - check withdraw_add permission
      if (!permissionProvider.hasPermission(PermissionIds.transactionsWithdrawAdd)) {
        return null;
      }
      return FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(false),
        icon: const Icon(Icons.add),
        label: const Text('Add Withdrawal'),
      );
    }
  }

  Widget _buildDepositsList(PermissionProvider permissionProvider, bool isDark) {
    if (_deposits.isEmpty) {
      return Center(
        child: Text(
          'No deposits found',
          style: TextStyle(
            color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
          ),
        ),
      );
    }

    final canEdit = permissionProvider.hasPermission(PermissionIds.transactionsDepositEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.transactionsDepositDelete);
    final hasAnyAction = canEdit || canDelete;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deposits.length,
      itemBuilder: (context, index) {
        final deposit = _deposits[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassmorphicCard(
            isDark: isDark,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.success.withOpacity(0.15),
                child: Icon(Icons.arrow_downward, color: AppColors.success),
              ),
              title: Text(
                Formatters.formatCurrency(deposit.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : const Color(0xFF1F2937),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deposit.customerName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkText : const Color(0xFF374151),
                    ),
                  ),
                  Text(
                    deposit.date,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                    ),
                  ),
                  if (deposit.description.isNotEmpty)
                    Text(
                      deposit.description,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              trailing: hasAnyAction
                  ? PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                      ),
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
                  : Icon(
                      Icons.chevron_right,
                      color: isDark ? AppColors.darkTextLight : const Color(0xFF9CA3AF),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWithdrawalsList(PermissionProvider permissionProvider, bool isDark) {
    if (_withdrawals.isEmpty) {
      return Center(
        child: Text(
          'No withdrawals found',
          style: TextStyle(
            color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
          ),
        ),
      );
    }

    final canEdit = permissionProvider.hasPermission(PermissionIds.transactionsWithdrawEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.transactionsWithdrawDelete);
    final hasAnyAction = canEdit || canDelete;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _withdrawals.length,
      itemBuilder: (context, index) {
        final withdrawal = _withdrawals[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassmorphicCard(
            isDark: isDark,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.error.withOpacity(0.15),
                child: Icon(Icons.arrow_upward, color: AppColors.error),
              ),
              title: Text(
                Formatters.formatCurrency(withdrawal.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : const Color(0xFF1F2937),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    withdrawal.customerName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkText : const Color(0xFF374151),
                    ),
                  ),
                  Text(
                    withdrawal.date,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                    ),
                  ),
                  if (withdrawal.description.isNotEmpty)
                    Text(
                      withdrawal.description,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              trailing: hasAnyAction
                  ? PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                      ),
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
                  : Icon(
                      Icons.chevron_right,
                      color: isDark ? AppColors.darkTextLight : const Color(0xFF9CA3AF),
                    ),
            ),
          ),
        );
      },
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
              SkeletonLoader(width: 48, height: 48, borderRadius: 24, isDark: isDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: 140, height: 16, isDark: isDark),
                    const SizedBox(height: 6),
                    SkeletonLoader(width: 100, height: 12, isDark: isDark),
                    const SizedBox(height: 4),
                    SkeletonLoader(width: 80, height: 12, isDark: isDark),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SkeletonLoader(width: 80, height: 16, isDark: isDark),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: 60, height: 20, borderRadius: 4, isDark: isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
