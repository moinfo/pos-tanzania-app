import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/api_response.dart';
import '../../models/contract.dart';
import '../../models/contract_extras.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// Tenant-wide Payments tab -- every payment across all contracts in a
/// date range, with Add/Edit/Delete. Distinct from the per-contract
/// statement on ContractDetailsScreen. Mirrors web Contracts::payments().
class ContractPaymentsScreen extends StatefulWidget {
  const ContractPaymentsScreen({super.key});

  @override
  State<ContractPaymentsScreen> createState() => _ContractPaymentsScreenState();
}

class _ContractPaymentsScreenState extends State<ContractPaymentsScreen> {
  final ApiService _apiService = ApiService();
  List<ContractPaymentEntry>? _payments;
  List<Contract> _activeContracts = [];
  bool _isLoading = true;
  String? _errorMessage;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final results = await Future.wait([
      _apiService.getContractPayments(startDate: _fmt(_startDate), endDate: _fmt(_endDate)),
      _apiService.getContracts(),
    ]);
    final paymentsResponse = results[0] as ApiResponse<List<ContractPaymentEntry>>;
    final contractsResponse = results[1] as ApiResponse<List<Contract>>;

    setState(() {
      _isLoading = false;
      if (paymentsResponse.isSuccess && paymentsResponse.data != null) {
        _payments = paymentsResponse.data;
      } else {
        _errorMessage = paymentsResponse.message;
      }
      if (contractsResponse.isSuccess && contractsResponse.data != null) {
        _activeContracts =
            contractsResponse.data!.where((c) => !c.isCompleted && !c.isTerminated).toList();
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

  Future<void> _showPaymentForm({ContractPaymentEntry? existing}) async {
    int? contractId = existing?.contractId;
    final amountController =
        TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    final dateController = TextEditingController(text: existing?.date ?? _fmt(DateTime.now()));
    final descriptionController = TextEditingController(text: existing?.description ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
              Text(existing == null ? 'Add Payment' : 'Edit Payment',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: contractId,
                decoration: const InputDecoration(labelText: 'Contract *', border: OutlineInputBorder()),
                items: _activeContracts
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setSheetState(() => contractId = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Date *', border: OutlineInputBorder()),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
                    firstDate: DateTime(DateTime.now().year - 3),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheetState(() => dateController.text = _fmt(picked));
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (contractId == null || amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pick a contract and a valid amount'), backgroundColor: AppColors.error),
                      );
                      return;
                    }
                    Navigator.pop(sheetContext);
                    final response = existing == null
                        ? await _apiService.addContractPayment(
                            contractId!,
                            amount: amount,
                            date: dateController.text,
                            description: descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                          )
                        : await _apiService.editContractPayment(
                            existing.id,
                            contractId: contractId!,
                            amount: amount,
                            date: dateController.text,
                            description: descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                          );
                    if (!mounted) return;
                    if (response.isSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment saved.'), backgroundColor: AppColors.success),
                      );
                      _load();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePayment(ContractPaymentEntry p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payment'),
        content: Text('Delete this ${Formatters.formatCurrency(p.amount)} payment from ${p.contractName}?'),
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

    final response = await _apiService.deleteContractPayment(p.id);
    if (!mounted) return;
    if (response.isSuccess) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();
    final canAdd = permissions.hasPermission(PermissionIds.contractsPaymentsAdd);
    final canEdit = permissions.hasPermission(PermissionIds.contractsPaymentsEdit);
    final canDelete = permissions.hasPermission(PermissionIds.contractsPaymentsDelete);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: _pickRange, tooltip: 'Date range'),
        ],
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              heroTag: 'contract_payments_fab',
              onPressed: () => _showPaymentForm(),
              icon: const Icon(Icons.add),
              label: const Text('Payment'),
              backgroundColor: AppColors.primary,
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
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '${_fmt(_startDate)} to ${_fmt(_endDate)}',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.darkTextLight : AppColors.textLight),
                      ),
                      const SizedBox(height: 8),
                      if (_payments == null || _payments!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text('No payments in this range',
                                style: TextStyle(
                                    color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                          ),
                        )
                      else
                        ..._payments!.map((p) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isDark ? AppColors.darkCard : Colors.white,
                              child: ListTile(
                                title: Text(p.contractName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${Formatters.formatDate(p.date)}${p.description != null && p.description!.isNotEmpty ? ' · ${p.description}' : ''}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(Formatters.formatCurrency(p.amount),
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (canEdit || canDelete)
                                      PopupMenuButton<String>(
                                        onSelected: (action) {
                                          if (action == 'edit') _showPaymentForm(existing: p);
                                          if (action == 'delete') _deletePayment(p);
                                        },
                                        itemBuilder: (_) => [
                                          if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          if (canDelete)
                                            const PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete', style: TextStyle(color: AppColors.error))),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }
}
