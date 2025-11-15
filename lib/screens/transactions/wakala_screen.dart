import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../utils/formatters.dart' show Formatters;
import '../../utils/constants.dart';

class WakalaScreen extends StatefulWidget {
  const WakalaScreen({super.key});

  @override
  State<WakalaScreen> createState() => _WakalaScreenState();
}

class _WakalaScreenState extends State<WakalaScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;

  List<Sim> _sims = [];
  List<WakalaTransaction> _transactions = [];
  double _total = 0;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
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
      final simsResponse = await _apiService.getSims();

      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);
      final transactionsResponse = await _apiService.getWakalaTransactions(
        startDate: startDateStr,
        endDate: endDateStr,
      );

      if (simsResponse.isSuccess && transactionsResponse.isSuccess && mounted) {
        setState(() {
          _sims = simsResponse.data ?? [];
          _transactions = transactionsResponse.data?.transactions ?? [];
          _total = transactionsResponse.data?.total ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = simsResponse.message ?? transactionsResponse.message;
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

  Future<void> _showAddSimDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add SIM Card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'SIM Card Name'),
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
                  const SnackBar(content: Text('Please enter a SIM card name')),
                );
                return;
              }

              Navigator.pop(context);

              final response = await _apiService.addSim(
                name: nameController.text,
                description: descriptionController.text.isEmpty
                    ? null
                    : descriptionController.text,
              );

              if (context.mounted) {
                if (response.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SIM card added successfully')),
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
    if (_sims.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a SIM card first')),
      );
      return;
    }

    Sim? selectedSim = _sims.first;
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Wakala Float Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Sim>(
                  value: selectedSim,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'SIM Card'),
                  items: _sims.map((sim) {
                    return DropdownMenuItem(
                      value: sim,
                      child: Text(
                        sim.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedSim = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Float Amount',
                    prefixText: 'TZS ',
                  ),
                  keyboardType: TextInputType.number,
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

                final response = await _apiService.addWakalaTransaction(
                  simId: selectedSim!.id,
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

  Future<void> _showEditSimDialog(Sim sim) async {
    final nameController = TextEditingController(text: sim.name);
    final descriptionController = TextEditingController(text: sim.description);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit SIM Card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'SIM Card Name'),
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
                  const SnackBar(content: Text('Please enter a SIM card name')),
                );
                return;
              }

              Navigator.pop(context);

              final response = await _apiService.updateSim(
                sim.id,
                name: nameController.text,
                description: descriptionController.text.isEmpty
                    ? null
                    : descriptionController.text,
              );

              if (context.mounted) {
                if (response.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SIM card updated successfully')),
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

  Future<void> _deleteSim(Sim sim) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete SIM Card'),
        content: Text('Are you sure you want to delete "${sim.name}"?'),
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
      final response = await _apiService.deleteSim(sim.id);
      if (context.mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SIM card deleted successfully')),
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

  Future<void> _showEditTransactionDialog(WakalaTransaction transaction) async {
    if (_sims.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No SIM cards available')),
      );
      return;
    }

    Sim? selectedSim = _sims.firstWhere(
      (s) => s.name == transaction.simName,
      orElse: () => _sims.first,
    );
    final amountController = TextEditingController(text: transaction.amount.toString());
    DateTime selectedDate = DateFormat('yyyy-MM-dd').parse(transaction.date);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Wakala Float Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Sim>(
                  value: selectedSim,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'SIM Card'),
                  items: _sims.map((sim) {
                    return DropdownMenuItem(
                      value: sim,
                      child: Text(
                        sim.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedSim = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Float Amount',
                    prefixText: 'TZS ',
                  ),
                  keyboardType: TextInputType.number,
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

                final response = await _apiService.updateWakalaTransaction(
                  transaction.id,
                  simId: selectedSim!.id,
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

  Future<void> _deleteWakalaTransaction(WakalaTransaction transaction) async {
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
      final response = await _apiService.deleteWakalaTransaction(transaction.id);
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
      appBar: AppBar(
        title: const Text('Wakala Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'SIM Cards'),
            Tab(text: 'Float Transactions'),
          ],
        ),
        actions: [
          if (_tabController.index == 1)
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
                : [AppColors.lightBackground, Colors.white],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSimsList(permissionProvider),
                      _buildTransactionsList(permissionProvider),
                    ],
                  ),
      ),
      floatingActionButton: _buildFloatingActionButton(permissionProvider),
    );
  }

  Widget? _buildFloatingActionButton(PermissionProvider permissionProvider) {
    final isOnSimsTab = _tabController.index == 0;

    if (isOnSimsTab) {
      // SIM cards tab - check setting_add permission
      if (!permissionProvider.hasPermission(PermissionIds.transactionsWakalaSettingAdd)) {
        return null;
      }
      return FloatingActionButton.extended(
        onPressed: _showAddSimDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add SIM'),
      );
    } else {
      // Float transactions tab - check add permission
      if (!permissionProvider.hasPermission(PermissionIds.transactionsWakalaAdd)) {
        return null;
      }
      return FloatingActionButton.extended(
        onPressed: _showAddTransactionDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Float'),
      );
    }
  }

  Widget _buildSimsList(PermissionProvider permissionProvider) {
    if (_sims.isEmpty) {
      return const Center(
        child: Text(
          'No SIM cards found\n\nAdd SIM cards for wakala float tracking',
          textAlign: TextAlign.center,
        ),
      );
    }

    final canEdit = permissionProvider.hasPermission(PermissionIds.transactionsWakalaSettingEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.transactionsWakalaSettingDelete);
    final hasAnyAction = canEdit || canDelete;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sims.length,
      itemBuilder: (context, index) {
        final sim = _sims[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassmorphicCard(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.sim_card, color: Colors.white),
              ),
              title: Text(sim.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(sim.description),
              trailing: hasAnyAction
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppColors.primary),
                            onPressed: () => _showEditSimDialog(sim),
                            tooltip: 'Edit',
                          ),
                        if (canDelete)
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.error),
                            onPressed: () => _deleteSim(sim),
                            tooltip: 'Delete',
                          ),
                      ],
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionsList(PermissionProvider permissionProvider) {
    final canEdit = permissionProvider.hasPermission(PermissionIds.transactionsWakalaEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.transactionsWakalaDelete);
    final hasAnyAction = canEdit || canDelete;

    return Column(
      children: [
        // Total Float Card
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: GlassmorphicCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Float:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    Formatters.formatCurrency(_total),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Transactions List
        Expanded(
          child: _transactions.isEmpty
              ? const Center(child: Text('No float transactions found'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassmorphicCard(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.sim_card, color: Colors.white),
                          ),
                          title: Text(
                            transaction.simName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(transaction.date),
                          trailing: hasAnyAction
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      Formatters.formatCurrency(transaction.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showEditTransactionDialog(transaction);
                                        } else if (value == 'delete') {
                                          _deleteWakalaTransaction(transaction);
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
                                    ),
                                  ],
                                )
                              : Text(
                                  Formatters.formatCurrency(transaction.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
