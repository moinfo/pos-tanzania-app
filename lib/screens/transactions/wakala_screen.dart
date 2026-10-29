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
    // Without the date grant the entry is pinned to today, matching how web
    // renders the date input readonly (views/transactions/footer.php).
    final canChangeDate = Provider.of<PermissionProvider>(context, listen: false)
        .hasPermission(PermissionIds.transactionsWakalaDate);

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
    final canChangeDate = Provider.of<PermissionProvider>(context, listen: false)
        .hasPermission(PermissionIds.transactionsWakalaDate);

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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: WakalaTheme.appBar(
        isDark: isDark,
        eyebrow: 'Wakala',
        title: 'SIMs',
        actions: [
          // Filtering the float-transaction list by an arbitrary range is a
          // separate grant from viewing it, mirroring web's $can_search_wk gate.
          if (_tabController.index == 1 &&
              permissionProvider.hasPermission(PermissionIds.transactionsWakalaDateRange))
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
              ? Center(
                  child: Text(
                    _error!,
                    style: WakalaTheme.body(size: 14, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280)),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: WakalaSegmentedControl(
                        labels: const ['SIM Cards', 'Float Transactions'],
                        selectedIndex: _tabController.index,
                        onChanged: (i) => _tabController.animateTo(i),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSimsList(permissionProvider, isDark),
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
    final isOnSimsTab = _tabController.index == 0;

    final VoidCallback? onPressed;
    final String label;
    if (isOnSimsTab) {
      // SIM cards tab - check setting_add permission
      if (!permissionProvider.hasPermission(PermissionIds.transactionsWakalaSettingAdd)) {
        return null;
      }
      onPressed = _showAddSimDialog;
      label = 'Add SIM';
    } else {
      // Float transactions tab - check add permission
      if (!permissionProvider.hasPermission(PermissionIds.transactionsWakalaAdd)) {
        return null;
      }
      onPressed = _showAddTransactionDialog;
      label = 'Add Float';
    }
    return FloatingActionButton.extended(
      heroTag: 'wakala_sims_fab',
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildSimsList(PermissionProvider permissionProvider, bool isDark) {
    if (_sims.isEmpty) {
      return Center(
        child: Text(
          'No SIM cards found\n\nAdd SIM cards for wakala float tracking',
          textAlign: TextAlign.center,
          style: WakalaTheme.body(size: 14, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280)),
        ),
      );
    }

    final canEdit = permissionProvider.hasPermission(PermissionIds.transactionsWakalaSettingEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.transactionsWakalaSettingDelete);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      itemCount: _sims.length,
      itemBuilder: (context, index) {
        final sim = _sims[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: WakalaCard(
            child: Row(
              children: [
                const WakalaIconTile(icon: Icons.sim_card_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sim.name,
                          style: WakalaTheme.display(size: 18, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                      if (sim.description.isNotEmpty)
                        Text(sim.description, style: WakalaTheme.body(size: 13, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
                    ],
                  ),
                ),
                if (canEdit)
                  _setupActionButton(Icons.edit_outlined, isEdit: true, onTap: () => _showEditSimDialog(sim)),
                if (canEdit && canDelete) const SizedBox(width: 8),
                if (canDelete)
                  _setupActionButton(Icons.delete_outline, isEdit: false, onTap: () => _deleteSim(sim)),
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
    final canEdit = permissionProvider.hasPermission(PermissionIds.transactionsWakalaEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.transactionsWakalaDelete);
    final hasAnyAction = canEdit || canDelete;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            border: const Border(left: BorderSide(color: Color(0xFF10B981), width: 4)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL FLOAT',
                  style: WakalaTheme.body(size: 13, weight: FontWeight.w600, color: const Color(0xFFE9ECEF)).copyWith(letterSpacing: 1.2)),
              Text(Formatters.formatCurrency(_total), style: WakalaTheme.display(size: 28, weight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Transactions',
            style: WakalaTheme.display(size: 13, weight: FontWeight.w700, letterSpacing: 0.9, color: const Color(0xFF6C757D))),
        const SizedBox(height: 10),
        if (_transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No float transactions found',
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
                    const WakalaIconTile(icon: Icons.sim_card_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(transaction.simName,
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
                            _deleteWakalaTransaction(transaction);
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
