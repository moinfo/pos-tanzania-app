import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/lipa_namba.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../../utils/formatters.dart' show Formatters;
import '../../utils/constants.dart';
import 'wakala_theme.dart';

class LipaNambaScreen extends StatefulWidget {
  const LipaNambaScreen({super.key});

  @override
  State<LipaNambaScreen> createState() => _LipaNambaScreenState();
}

class _LipaNambaScreenState extends State<LipaNambaScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _error;

  List<LipaNambaAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _apiService.getLipaNambaAccounts();

    if (!mounted) return;
    if (response.isSuccess) {
      setState(() {
        _accounts = response.data ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddAccountDialog() async {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Till'),
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
              controller: numberController,
              decoration: const InputDecoration(labelText: 'Till / Lipa Namba number'),
              keyboardType: TextInputType.number,
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
              if (nameController.text.isEmpty || numberController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name and number')),
                );
                return;
              }

              Navigator.pop(context);

              final response = await _apiService.addLipaNambaAccount(
                name: nameController.text,
                number: numberController.text,
                description: descriptionController.text,
              );

              if (context.mounted) {
                if (response.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Till added successfully')),
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

  Future<void> _showEditAccountDialog(LipaNambaAccount account) async {
    final nameController = TextEditingController(text: account.name);
    final numberController = TextEditingController(text: account.number);
    final descriptionController = TextEditingController(text: account.description);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Till'),
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
              controller: numberController,
              decoration: const InputDecoration(labelText: 'Till / Lipa Namba number'),
              keyboardType: TextInputType.number,
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
              if (nameController.text.isEmpty || numberController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name and number')),
                );
                return;
              }

              Navigator.pop(context);

              final response = await _apiService.editLipaNambaAccount(
                account.id,
                name: nameController.text,
                number: numberController.text,
                description: descriptionController.text,
              );

              if (context.mounted) {
                if (response.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Till updated successfully')),
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

  Future<void> _deleteAccount(LipaNambaAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Till'),
        content: Text('Are you sure you want to delete "${account.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await _apiService.deleteLipaNambaAccount(account.id);

      if (context.mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Till deleted successfully')),
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

  Future<void> _showMoveMoneyDialog(LipaNambaAccount account, {required bool isDeposit}) async {
    final amountController = TextEditingController();
    final clientNameController = TextEditingController();
    final clientPhoneController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    double? feePreview;
    bool isCheckingFee = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isDeposit ? 'Deposit · ${account.name}' : 'Withdraw · ${account.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'TZS ',
                    helperText: isDeposit
                        ? (isCheckingFee
                            ? 'Checking fee...'
                            : feePreview != null
                                ? 'Fee: ${Formatters.formatCurrency(feePreview!)}'
                                : null)
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: isDeposit
                      ? (value) async {
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            setDialogState(() => feePreview = null);
                            return;
                          }
                          setDialogState(() => isCheckingFee = true);
                          final response = await _apiService.getLipaNambaFeeForAmount(amount);
                          setDialogState(() {
                            isCheckingFee = false;
                            feePreview = response.isSuccess ? response.data : null;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: clientNameController,
                  decoration: const InputDecoration(labelText: 'Client name (optional)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: clientPhoneController,
                  decoration: const InputDecoration(labelText: 'Client phone (optional)'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
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
                      setDialogState(() => selectedDate = picked);
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

                final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                final response = isDeposit
                    ? await _apiService.depositLipaNamba(
                        lipaNambaId: account.id,
                        amount: amount,
                        clientName: clientNameController.text,
                        clientPhone: clientPhoneController.text,
                        notes: notesController.text,
                        transactionDate: dateStr,
                      )
                    : await _apiService.withdrawLipaNamba(
                        lipaNambaId: account.id,
                        amount: amount,
                        clientName: clientNameController.text,
                        clientPhone: clientPhoneController.text,
                        notes: notesController.text,
                        transactionDate: dateStr,
                      );

                if (context.mounted) {
                  if (response.isSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isDeposit ? 'Deposit recorded' : 'Withdrawal recorded')),
                    );
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response.message)),
                    );
                  }
                }
              },
              child: Text(isDeposit ? 'Deposit' : 'Withdraw'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final permissionProvider = Provider.of<PermissionProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final canAdd = permissionProvider.hasPermission(PermissionIds.lipaNambaAdd);
    final canEdit = permissionProvider.hasPermission(PermissionIds.lipaNambaEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.lipaNambaDelete);
    final canDeposit = permissionProvider.hasPermission(PermissionIds.lipaNambaDeposit);
    final canWithdraw = permissionProvider.hasPermission(PermissionIds.lipaNambaWithdraw);
    final hasAnyAction = canEdit || canDelete;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: WakalaTheme.appBar(isDark: isDark, eyebrow: 'Lipa Namba', title: 'Tills'),
      body: _isLoading
          ? _buildSkeletonList(isDark)
          : _error != null
              ? Center(child: Text(_error!))
              : _accounts.isEmpty
                  ? Center(
                      child: Text(
                        'No tills found',
                        style: WakalaTheme.body(size: 14, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: _accounts.length,
                      itemBuilder: (context, index) {
                        final account = _accounts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: WakalaCard(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const WakalaIconTile(icon: Icons.sim_card_outlined),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(account.name,
                                              style: WakalaTheme.display(
                                                  size: 18, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                                          Text('Till ${account.number}',
                                              style: WakalaTheme.body(size: 13, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280))
                                                  .copyWith(letterSpacing: 0.4)),
                                        ],
                                      ),
                                    ),
                                    if (hasAnyAction)
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert, color: isDark ? AppColors.darkTextLight : AppColors.text),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showEditAccountDialog(account);
                                          } else if (value == 'delete') {
                                            _deleteAccount(account);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          if (canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Float',
                                              style: WakalaTheme.body(size: 12, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280))),
                                          Text(Formatters.formatCurrency(account.float),
                                              style: WakalaTheme.display(size: 28, weight: FontWeight.w700, color: AppColors.primary)),
                                        ],
                                      ),
                                    ),
                                    Text.rich(
                                      TextSpan(
                                        style: WakalaTheme.body(size: 13, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280)),
                                        children: [
                                          const TextSpan(text: 'Fees earned '),
                                          TextSpan(
                                              text: Formatters.formatCurrency(account.totalFees),
                                              style: WakalaTheme.display(size: 13, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (canDeposit || canWithdraw) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      if (canDeposit)
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _showMoveMoneyDialog(account, isDeposit: true),
                                            icon: const Icon(Icons.add, size: 18),
                                            label: const Text('Deposit'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF047857),
                                              side: const BorderSide(color: AppColors.success),
                                              minimumSize: const Size.fromHeight(44),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              textStyle: WakalaTheme.body(size: 14, weight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                      if (canDeposit && canWithdraw) const SizedBox(width: 10),
                                      if (canWithdraw)
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _showMoveMoneyDialog(account, isDeposit: false),
                                            icon: const Icon(Icons.remove, size: 18),
                                            label: const Text('Withdraw'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFB91C1C),
                                              side: const BorderSide(color: AppColors.error),
                                              minimumSize: const Size.fromHeight(44),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              textStyle: WakalaTheme.body(size: 14, weight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: _showAddAccountDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Till'),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            )
          : null,
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
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
      ),
    );
  }
}
