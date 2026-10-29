import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
import 'contracts/contract_theme.dart';

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
    File? receiptFile;
    String? receiptDataUri;

    Future<void> pickReceipt(
        StateSetter setDialogState, ImageSource source) async {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await File(image.path).readAsBytes();
      final ext = image.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      setDialogState(() {
        receiptFile = File(image.path);
        receiptDataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
      });
    }

    void showReceiptSourceSheet(
        BuildContext dialogContext, StateSetter setDialogState) {
      showModalBottomSheet(
        context: dialogContext,
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  pickReceipt(setDialogState, ImageSource.camera);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  pickReceipt(setDialogState, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Payment'),
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 12),
                // Optional -- the customer can attach a receipt to this
                // payment afterwards from the portal if staff skip it here.
                OutlinedButton.icon(
                  onPressed: () => showReceiptSourceSheet(ctx, setDialogState),
                  icon: Icon(
                      receiptFile == null
                          ? Icons.add_a_photo
                          : Icons.check_circle,
                      size: 16,
                      color: receiptFile == null ? null : AppColors.success),
                  label: Text(receiptFile == null
                      ? 'Attach Receipt (optional)'
                      : 'Receipt Attached'),
                ),
                if (receiptFile != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(receiptFile!,
                        height: 100, fit: BoxFit.cover),
                  ),
                ],
              ],
            ),
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
      receiptDataUri: receiptDataUri,
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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: ContractTheme.appBar(
        isDark: isDark,
        eyebrow: 'Contract',
        title: _contract.name,
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
                  : const Icon(Icons.add, color: Colors.white),
              label: Text('Add payment', style: ContractTheme.body(size: 14, weight: FontWeight.w700, color: Colors.white)),
              backgroundColor: const Color(0xFF047857),
            )
          : null,
      body: Column(
        children: [
          // Contract summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _contract.contractDescription,
                        style: ContractTheme.display(
                            size: 22, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(_contract),
                  ],
                ),
                if (_contract.isTerminated &&
                    (_contract.terminationReason?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Reason: ${_contract.terminationReason}',
                    style: ContractTheme.body(
                      size: 12.5,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
                if (!_contract.isTerminated &&
                    _contract.collectionStage != null) ...[
                  const SizedBox(height: 8),
                  _buildCollectionStageChip(_contract.collectionStage!),
                ],
                const SizedBox(height: 14),
                ContractDayStrip(
                  daysPaid: _contract.daysPaid.round(),
                  daysUnpaid: _contract.daysUnpaid.round(),
                  totalDays: _contract.days,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem('Balance',
                          Formatters.formatCurrency(_contract.balance),
                          _contract.balance > 0 ? const Color(0xFFB91C1C) : const Color(0xFF047857)),
                    ),
                    Expanded(
                      child: _buildSummaryItem('Profit',
                          Formatters.formatCurrency(_contract.profit),
                          _contract.profit >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem('Days paid',
                          _contract.daysPaid.toStringAsFixed(0), const Color(0xFF047857)),
                    ),
                    Expanded(
                      child: _buildSummaryItem('Days unpaid',
                          _contract.daysUnpaid.toStringAsFixed(0),
                          _contract.daysUnpaid > 0 ? const Color(0xFFB91C1C) : (isDark ? AppColors.darkText : AppColors.text)),
                    ),
                  ],
                ),
                if (_contract.penalty > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Includes ${Formatters.formatCurrency(_contract.penalty)} late fee',
                    style: ContractTheme.body(size: 12.5, weight: FontWeight.w600, color: AppColors.error),
                  ),
                ],
                if (_contract.repossessionFeeCharged > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Includes ${Formatters.formatCurrency(_contract.repossessionFeeCharged)} repossession fee',
                    style: ContractTheme.body(size: 12.5, weight: FontWeight.w600, color: AppColors.error),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                ),
                _buildAssetInfo(isDark, canAdd),
              ],
            ),
          ),

          // Date range selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _rangeButton(
                    Formatters.formatDate(Formatters.formatDateForApi(_startDate)), _selectStartDate, isDark)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to',
                      style: ContractTheme.body(
                          size: 13.5, color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                ),
                Expanded(child: _rangeButton(
                    Formatters.formatDate(Formatters.formatDateForApi(_endDate)), _selectEndDate, isDark)),
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

  Widget _rangeButton(String label, VoidCallback onTap, bool isDark) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(label, style: ContractTheme.body(size: 13, weight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightTextLight),
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  /// Same status scheme as ContractsScreen's card -- see its doc comment.
  Widget _buildStatusBadge(Contract contract) {
    switch (contract.status) {
      case 'terminated':
        return const ContractStatusBadge(
            label: 'Terminated', dot: Colors.grey, background: Color(0xFFE9ECEF), foreground: Color(0xFF6C757D));
      case 'completed':
        return const ContractStatusBadge(
            label: 'Completed', dot: AppColors.success, background: Color(0xFFD1FAE5), foreground: Color(0xFF047857));
      case 'on_track':
        return const ContractStatusBadge(
            label: 'On track', dot: AppColors.success, background: Color(0xFFD1FAE5), foreground: Color(0xFF047857));
      default:
        return ContractStatusBadge(label: 'Behind ${contract.daysUnpaid.toStringAsFixed(0)}d');
    }
  }

  /// Which collection-escalation tier this contract is in -- see
  /// Contract::compute_metrics()'s collection_stage on the backend. Purely
  /// informational for staff; only shown while the contract is still active.
  Widget _buildCollectionStageChip(String stage) {
    switch (stage) {
      case 'final_notice':
        return const ContractStatusBadge(
            label: 'Final notice', dot: AppColors.error, background: Color(0xFFFEE2E2), foreground: Color(0xFFB91C1C));
      case 'warning':
        return const ContractStatusBadge(
            label: 'Warning', dot: AppColors.warning, background: Color(0xFFFEF3C7), foreground: Color(0xFF92400E));
      default:
        return const ContractStatusBadge(
            label: 'Reminder sent', dot: AppColors.primary, background: Color(0xFFDBEAFE), foreground: Color(0xFF1E40AF));
    }
  }

  Widget _buildAssetInfo(bool isDark, bool canEdit) {
    final hasPlate = _contract.assetPlateNumber?.isNotEmpty ?? false;
    final hasChassis = _contract.assetChassisNumber?.isNotEmpty ?? false;
    final hasInsurance = _contract.assetInsuranceProvider?.isNotEmpty ?? false;
    final expiry = _contract.assetInsuranceExpiry;
    final insuranceExpired = expiry != null &&
        expiry.compareTo(Formatters.formatDateForApi(DateTime.now())) < 0;
    final subColor = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final textColor = isDark ? AppColors.darkText : AppColors.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Plate', style: ContractTheme.body(size: 14, color: subColor)),
            const SizedBox(width: 8),
            if (hasPlate)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightTextLight, width: 1.5),
                ),
                child: Text(_contract.assetPlateNumber!.toUpperCase(),
                    style: ContractTheme.display(size: 15, weight: FontWeight.w700, color: textColor)
                        .copyWith(letterSpacing: 1.2)),
              )
            else
              Text('Not recorded', style: ContractTheme.body(size: 13.5, color: subColor)),
            const Spacer(),
            if (canEdit)
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _editAssetInfo,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined, size: 20, color: textColor),
                ),
              ),
          ],
        ),
        if (hasChassis || hasInsurance) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (hasChassis)
                Text('Chassis: ${_contract.assetChassisNumber}',
                    style: ContractTheme.body(size: 12.5, color: subColor)),
              if (hasInsurance)
                Text(
                  'Insurance: ${_contract.assetInsuranceProvider}'
                  '${expiry != null ? ' (expires $expiry${insuranceExpired ? ' -- EXPIRED' : ''})' : ''}',
                  style: ContractTheme.body(
                    size: 12.5,
                    weight: insuranceExpired ? FontWeight.w700 : FontWeight.w400,
                    color: insuranceExpired ? AppColors.error : subColor,
                  ),
                ),
            ],
          ),
        ],
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

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ContractTheme.body(size: 13, color: AppColors.textLight)),
        const SizedBox(height: 2),
        Text(value, style: ContractTheme.display(size: 26, weight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _buildStatementEntry(StatementEntry entry, bool isDark) {
    final isOpening = entry.type == 'opening';
    final isClosing = entry.type == 'closing';
    final isSpecial = isOpening || isClosing;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final subColor = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSpecial
            ? (isDark ? AppColors.darkDivider : const Color(0xFFE9ECEF))
            : (isDark ? AppColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: isSpecial ? null : Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(entry.description, style: ContractTheme.display(size: 17, weight: FontWeight.w700, color: textColor)),
              Text(Formatters.formatDate(entry.date), style: ContractTheme.body(size: 13, color: subColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildAmountColumn('Credit', entry.credit, const Color(0xFF047857), subColor: subColor)),
              Expanded(child: _buildAmountColumn('Debit', entry.debit, AppColors.error, subColor: subColor)),
              Expanded(
                child: _buildAmountColumn(
                  'Balance',
                  entry.balance,
                  entry.balance >= 0 ? const Color(0xFF047857) : AppColors.error,
                  isBold: true,
                  subColor: subColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountColumn(String label, double amount, Color color,
      {bool isBold = false, required Color subColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ContractTheme.body(size: 11, color: subColor)),
        const SizedBox(height: 2),
        Text(
          Formatters.formatCurrency(amount),
          style: ContractTheme.body(
            size: 13,
            weight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: amount == 0 ? subColor : color,
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
