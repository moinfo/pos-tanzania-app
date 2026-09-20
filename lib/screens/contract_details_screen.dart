import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/permission_provider.dart';
import '../services/api_service.dart';
import '../models/contract.dart';
import '../models/permission_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/skeleton_loader.dart';
import 'contract_form_screen.dart';

class ContractDetailsScreen extends StatefulWidget {
  final Contract contract;

  const ContractDetailsScreen({super.key, required this.contract});

  @override
  State<ContractDetailsScreen> createState() => _ContractDetailsScreenState();
}

class _ContractDetailsScreenState extends State<ContractDetailsScreen> {
  final ApiService _apiService = ApiService();
  List<StatementEntry>? _statement;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // Mutable copy of widget.contract -- refreshed after a payment so the
  // summary card reflects the new balance/status without leaving the
  // screen (widget.contract itself is a snapshot from the list screen).
  late Contract _contract;
  bool _isAddingPayment = false;
  bool _isTerminating = false;

  @override
  void initState() {
    super.initState();
    _contract = widget.contract;
    // Default to current month
    _startDate = DateTime(_startDate.year, _startDate.month, 1);
    _endDate = DateTime(_endDate.year, _endDate.month + 1, 0);
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getContractStatement(
      _contract.id,
      startDate: Formatters.formatDateForApi(_startDate),
      endDate: Formatters.formatDateForApi(_endDate),
    );

    setState(() {
      if (result.isSuccess && result.data != null) {
        final statementData = result.data!['statement'] as List;
        _statement =
            statementData.map((item) => StatementEntry.fromJson(item)).toList();
        _errorMessage = null;
      } else {
        _statement = null;
        _errorMessage = result.message ?? 'Failed to load statement';
      }
      _isLoading = false;
    });
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _startDate = date);
      _loadStatement();
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _endDate = date);
      _loadStatement();
    }
  }

  Future<void> _addPayment() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime paymentDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Daily rate: ${Formatters.formatCurrency(_contract.returnAmount)}'),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: paymentDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null)
                    setDialogState(() => paymentDate = picked);
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(Formatters.formatDate(
                    Formatters.formatDateForApi(paymentDate))),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      amountController.dispose();
      descriptionController.dispose();
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    final description = descriptionController.text.trim();
    amountController.dispose();
    descriptionController.dispose();

    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a valid amount'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isAddingPayment = true);
    final response = await _apiService.addContractPayment(
      _contract.id,
      amount: amount,
      date: Formatters.formatDateForApi(paymentDate),
      description: description,
    );
    if (!mounted) return;
    setState(() => _isAddingPayment = false);

    if (response.isSuccess && response.data != null) {
      final updated = response.data!['contract'] as Map<String, dynamic>?;
      if (updated != null) {
        setState(() =>
            _contract = Contract.fromJson({..._contract.toJson(), ...updated}));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.message ?? 'Payment recorded'),
            backgroundColor: AppColors.success),
      );
      _loadStatement();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.message ?? 'Failed to record payment'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _terminateContract() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Terminate ${_contract.name}\'s contract?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Marks this contract defaulted/repossessed. This cannot be undone from here.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child:
                const Text('Terminate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }
    final reason = reasonController.text.trim();
    reasonController.dispose();

    setState(() => _isTerminating = true);
    final response =
        await _apiService.terminateContract(_contract.id, reason: reason);
    if (!mounted) return;
    setState(() => _isTerminating = false);

    if (response.isSuccess && response.data != null) {
      setState(() => _contract =
          Contract.fromJson({..._contract.toJson(), ...response.data!}));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Contract terminated'),
            backgroundColor: AppColors.success),
      );
      _offerTransfer();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.message ?? 'Failed to terminate contract'),
            backgroundColor: AppColors.error),
      );
    }
  }

  /// After repossessing the asset, the natural next step in this business
  /// is handing it to someone else -- offers starting a new contract right
  /// away, either for a brand new customer or an existing one (picked from
  /// past contracts, same identity-carryover as Renew).
  Future<void> _offerTransfer() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer to someone?'),
        content: const Text(
            'Start a new contract for this asset -- for a new customer, or one already in the system.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'skip'),
              child: const Text('Not now')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'existing'),
              child: const Text('Existing Customer')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'new'),
            child: const Text('New Customer'),
          ),
        ],
      ),
    );

    if (choice == 'new') {
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const ContractFormScreen()),
      );
      if (saved == true && mounted) Navigator.pop(context, true);
    } else if (choice == 'existing') {
      await _pickExistingCustomerAndTransfer();
    }
  }

  Future<void> _pickExistingCustomerAndTransfer() async {
    final response = await _apiService.getContracts();
    if (!mounted) return;
    if (!response.isSuccess || response.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.message ?? 'Failed to load customers'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final contracts = response.data!;
    final searchController = TextEditingController();

    final picked = await showModalBottomSheet<Contract>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? contracts
              : contracts
                  .where((c) =>
                      c.name.toLowerCase().contains(query) ||
                      c.phone.toLowerCase().contains(query))
                  .toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select existing customer',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or phone',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No customers found'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              return ListTile(
                                title: Text(c.name),
                                subtitle: Text(c.phone),
                                onTap: () => Navigator.pop(ctx, c),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();

    if (picked == null || !mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ContractFormScreen(renewFrom: picked)),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final canAddPayment = context
            .watch<PermissionProvider>()
            .hasPermission(PermissionIds.contractsPaymentsAdd) &&
        !_contract.isTerminated;
    final canAdd = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.contractsAdd);
    final canTerminate = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.contractsTerminate);

    return Scaffold(
      appBar: AppBar(
        title: Text(_contract.name),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (canTerminate && !_contract.isTerminated)
            IconButton(
              icon: const Icon(Icons.block),
              tooltip: 'Terminate',
              onPressed: _isTerminating ? null : _terminateContract,
            ),
          if (canAdd)
            IconButton(
              icon: const Icon(Icons.autorenew),
              tooltip: 'Renew',
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContractFormScreen(renewFrom: _contract),
                  ),
                );
                if (saved == true && mounted) Navigator.pop(context, true);
              },
            ),
        ],
      ),
      floatingActionButton: canAddPayment
          ? FloatingActionButton.extended(
              onPressed: _isAddingPayment ? null : _addPayment,
              icon: _isAddingPayment
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add),
              label: const Text('Add Payment'),
              backgroundColor: AppColors.success,
            )
          : null,
      body: Column(
        children: [
          // Contract summary card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _contract.contractDescription,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      ),
                      _buildStatusBadge(_contract),
                    ],
                  ),
                  if (_contract.isTerminated &&
                      (_contract.terminationReason?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Reason: ${_contract.terminationReason}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: isDark
                            ? AppColors.darkTextLight
                            : AppColors.textLight,
                      ),
                    ),
                  ],
                  if (!_contract.isTerminated &&
                      _contract.collectionStage != null) ...[
                    const SizedBox(height: 6),
                    _buildCollectionStageChip(_contract.collectionStage!),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Balance',
                          Formatters.formatCurrency(_contract.balance), isDark),
                      _buildSummaryItem('Profit',
                          Formatters.formatCurrency(_contract.profit), isDark),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Days Paid',
                          _contract.daysPaid.toStringAsFixed(0), isDark),
                      _buildSummaryItem('Days Unpaid',
                          _contract.daysUnpaid.toStringAsFixed(0), isDark),
                    ],
                  ),
                  if (_contract.penalty > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Includes ${Formatters.formatCurrency(_contract.penalty)} late fee',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error),
                    ),
                  ],
                  if (_contract.repossessionFeeCharged > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Includes ${Formatters.formatCurrency(_contract.repossessionFeeCharged)} repossession fee',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error),
                    ),
                  ],
                  const Divider(height: 24),
                  _buildAssetInfo(isDark, canAdd),
                ],
              ),
            ),
          ),

          // Date range selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectStartDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      Formatters.formatDate(
                          Formatters.formatDateForApi(_startDate)),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to',
                      style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight)),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectEndDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      Formatters.formatDate(
                          Formatters.formatDateForApi(_endDate)),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Statement list
          Expanded(
            child: _isLoading
                ? _buildSkeletonList(isDark)
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _loadStatement,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _statement == null || _statement!.isEmpty
                        ? const Center(
                            child: Text('No statement data available'))
                        : RefreshIndicator(
                            onRefresh: _loadStatement,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _statement!.length,
                              itemBuilder: (context, index) {
                                final entry = _statement![index];
                                return _buildStatementEntry(entry, isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 4),
    );
  }

  /// Same status scheme as ContractsScreen's card -- see its doc comment.
  Widget _buildStatusBadge(Contract contract) {
    final Color color;
    final String label;
    switch (contract.status) {
      case 'terminated':
        color = Colors.grey;
        label = 'Terminated';
        break;
      case 'completed':
        color = AppColors.success;
        label = 'Completed';
        break;
      case 'on_track':
        color = AppColors.success;
        label = 'On Track';
        break;
      case 'behind':
        color = AppColors.warning;
        label = 'Behind ${contract.daysUnpaid.toStringAsFixed(0)}d';
        break;
      default:
        color = AppColors.error;
        label = 'Behind ${contract.daysUnpaid.toStringAsFixed(0)}d';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  /// Which collection-escalation tier this contract is in -- see
  /// Contract::compute_metrics()'s collection_stage on the backend. Purely
  /// informational for staff; only shown while the contract is still active.
  Widget _buildCollectionStageChip(String stage) {
    final Color color;
    final String label;
    switch (stage) {
      case 'final_notice':
        color = AppColors.error;
        label = 'Final Notice';
        break;
      case 'warning':
        color = AppColors.warning;
        label = 'Warning';
        break;
      default:
        color = AppColors.primary;
        label = 'Reminder Sent';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildAssetInfo(bool isDark, bool canEdit) {
    final hasInfo = (_contract.assetPlateNumber?.isNotEmpty ?? false) ||
        (_contract.assetChassisNumber?.isNotEmpty ?? false) ||
        (_contract.assetInsuranceProvider?.isNotEmpty ?? false);
    final expiry = _contract.assetInsuranceExpiry;
    final insuranceExpired = expiry != null &&
        expiry.compareTo(Formatters.formatDateForApi(DateTime.now())) < 0;
    final textColor = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: hasInfo
              ? Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (_contract.assetPlateNumber?.isNotEmpty ?? false)
                      Text('Plate: ${_contract.assetPlateNumber}',
                          style: TextStyle(fontSize: 12, color: textColor)),
                    if (_contract.assetChassisNumber?.isNotEmpty ?? false)
                      Text('Chassis: ${_contract.assetChassisNumber}',
                          style: TextStyle(fontSize: 12, color: textColor)),
                    if (_contract.assetInsuranceProvider?.isNotEmpty ?? false)
                      Text(
                        'Insurance: ${_contract.assetInsuranceProvider}'
                        '${expiry != null ? ' (expires $expiry${insuranceExpired ? ' -- EXPIRED' : ''})' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: insuranceExpired ? AppColors.error : textColor,
                          fontWeight: insuranceExpired
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                  ],
                )
              : Text('No asset info recorded.',
                  style: TextStyle(fontSize: 12, color: textColor)),
        ),
        if (canEdit)
          InkWell(
            onTap: _editAssetInfo,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.edit, size: 16, color: textColor),
            ),
          ),
      ],
    );
  }

  Future<void> _editAssetInfo() async {
    final plateController =
        TextEditingController(text: _contract.assetPlateNumber ?? '');
    final chassisController =
        TextEditingController(text: _contract.assetChassisNumber ?? '');
    final insuranceController =
        TextEditingController(text: _contract.assetInsuranceProvider ?? '');
    DateTime? expiry = _contract.assetInsuranceExpiry != null
        ? DateTime.tryParse(_contract.assetInsuranceExpiry!)
        : null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Asset Info'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: plateController,
                  decoration: const InputDecoration(labelText: 'Plate Number'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: chassisController,
                  decoration:
                      const InputDecoration(labelText: 'Chassis Number'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: insuranceController,
                  decoration:
                      const InputDecoration(labelText: 'Insurance Provider'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: expiry ?? DateTime.now(),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 3)),
                      helpText: 'Insurance expiry date',
                    );
                    if (picked != null) {
                      setDialogState(() => expiry = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(expiry == null
                      ? 'Insurance Expiry'
                      : 'Expiry: ${Formatters.formatDate(Formatters.formatDateForApi(expiry!))}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final response = await _apiService.updateContractAsset(
      _contract.id,
      assetPlateNumber: plateController.text.trim(),
      assetChassisNumber: chassisController.text.trim(),
      assetInsuranceProvider: insuranceController.text.trim(),
      assetInsuranceExpiry:
          expiry == null ? null : Formatters.formatDateForApi(expiry!),
    );

    if (!mounted) return;

    if (response.isSuccess) {
      final updated = response.data ??
          {
            'asset_plate_number': plateController.text.trim().isEmpty
                ? null
                : plateController.text.trim(),
            'asset_chassis_number': chassisController.text.trim().isEmpty
                ? null
                : chassisController.text.trim(),
            'asset_insurance_provider': insuranceController.text.trim().isEmpty
                ? null
                : insuranceController.text.trim(),
            'asset_insurance_expiry':
                expiry == null ? null : Formatters.formatDateForApi(expiry!),
          };
      setState(() =>
          _contract = Contract.fromJson({..._contract.toJson(), ...updated}));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Asset info updated'),
            backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Failed to update asset info'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildSummaryItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildStatementEntry(StatementEntry entry, bool isDark) {
    final isOpening = entry.type == 'opening';
    final isClosing = entry.type == 'closing';
    final isSpecial = isOpening || isClosing;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSpecial ? 2 : 1,
      color: isSpecial
          ? (isDark
              ? AppColors.darkSurface
              : AppColors.primary.withOpacity(0.05))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and description
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.description,
                  style: TextStyle(
                    fontSize: isSpecial ? 14 : 13,
                    fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
                Text(
                  Formatters.formatDate(entry.date),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? AppColors.darkTextLight : AppColors.textLight,
                    fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Financial details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Credit
                Expanded(
                  child: _buildAmountColumn(
                    'Credit',
                    entry.credit,
                    AppColors.success,
                    isDark: isDark,
                  ),
                ),
                // Debit
                Expanded(
                  child: _buildAmountColumn(
                    'Debit',
                    entry.debit,
                    AppColors.error,
                    isDark: isDark,
                  ),
                ),
                // Balance
                Expanded(
                  child: _buildAmountColumn(
                    'Balance',
                    entry.balance,
                    entry.balance >= 0 ? AppColors.success : AppColors.error,
                    isBold: true,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountColumn(String label, double amount, Color color,
      {bool isBold = false, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Formatters.formatCurrency(amount),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: amount == 0
                ? (isDark ? AppColors.darkTextLight : AppColors.textLight)
                : color,
          ),
        ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SkeletonLoader(
                width: 40, height: 40, borderRadius: 8, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 100, height: 14, isDark: isDark),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: 80, height: 12, isDark: isDark),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SkeletonLoader(width: 70, height: 14, isDark: isDark),
                const SizedBox(height: 4),
                SkeletonLoader(width: 50, height: 14, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
