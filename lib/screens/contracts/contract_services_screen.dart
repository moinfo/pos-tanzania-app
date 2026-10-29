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
import 'contract_theme.dart';

/// Tenant-wide Services tab -- maintenance costs against a contract (these
/// reduce profit, distinct from Payments which reduce balance). Mirrors
/// web Contracts::services().
class ContractServicesScreen extends StatefulWidget {
  const ContractServicesScreen({super.key});

  @override
  State<ContractServicesScreen> createState() => _ContractServicesScreenState();
}

class _ContractServicesScreenState extends State<ContractServicesScreen> {
  final ApiService _apiService = ApiService();
  List<ContractServiceEntry>? _services;
  List<Contract> _allContracts = [];
  bool _isLoading = true;
  String? _errorMessage;

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
      _apiService.getContractServices(),
      _apiService.getContracts(),
    ]);
    final servicesResponse = results[0] as ApiResponse<List<ContractServiceEntry>>;
    final contractsResponse = results[1] as ApiResponse<List<Contract>>;

    setState(() {
      _isLoading = false;
      if (servicesResponse.isSuccess && servicesResponse.data != null) {
        _services = servicesResponse.data;
      } else {
        _errorMessage = servicesResponse.message;
      }
      // Services can be edited even for a completed/terminated contract
      // (mirrors web, which passes getContracts(TRUE) here), so no filter.
      if (contractsResponse.isSuccess && contractsResponse.data != null) {
        _allContracts = contractsResponse.data!;
      }
    });
  }

  Future<void> _showServiceForm({ContractServiceEntry? existing}) async {
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
              Text(existing == null ? 'Add Service' : 'Edit Service',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: contractId,
                decoration: const InputDecoration(labelText: 'Contract *', border: OutlineInputBorder()),
                items: _allContracts
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
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
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
                        ? await _apiService.addContractService(
                            contractId: contractId!,
                            amount: amount,
                            date: dateController.text,
                            description: descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                          )
                        : await _apiService.editContractService(
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
                        const SnackBar(content: Text('Service saved.'), backgroundColor: AppColors.success),
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

  Future<void> _deleteService(ContractServiceEntry s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete service'),
        content: Text('Delete this ${Formatters.formatCurrency(s.amount)} service cost from ${s.contractName}?'),
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

    final response = await _apiService.deleteContractService(s.id);
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
    final canAdd = permissions.hasPermission(PermissionIds.contractsServicesAdd);
    final canEdit = permissions.hasPermission(PermissionIds.contractsServicesEdit);
    final canDelete = permissions.hasPermission(PermissionIds.contractsServicesDelete);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: ContractTheme.appBar(isDark: isDark, eyebrow: 'Repairs', title: 'Services'),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              heroTag: 'contract_services_fab',
              onPressed: () => _showServiceForm(),
              icon: const Icon(Icons.add, color: AppColors.secondary),
              label: Text('Service',
                  style: ContractTheme.body(size: 14, weight: FontWeight.w700, color: AppColors.secondary)),
              backgroundColor: AppColors.warning,
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
              : (_services == null || _services!.isEmpty)
                  ? Center(
                      child: Text('No service costs recorded yet',
                          style: ContractTheme.body(size: 14, color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ContractHeroPanel(
                            caption: 'Service cost · ${_services!.length} job(s)',
                            value: 'TZS ${Formatters.formatCurrency(_services!.fold<double>(0, (sum, s) => sum + s.amount))}',
                          ),
                          const SizedBox(height: 16),
                          ..._services!.map((s) => _serviceRow(s, isDark, canEdit, canDelete)),
                        ],
                      ),
                    ),
    );
  }

  Widget _serviceRow(ContractServiceEntry s, bool isDark, bool canEdit, bool canDelete) {
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final subColor = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Row(
        children: [
          ContractCircleBadge(
            icon: Icons.build_outlined,
            background: isDark ? AppColors.darkDivider : const Color(0xFFE9ECEF),
            foreground: AppColors.primary,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.contractName, style: ContractTheme.display(size: 16, weight: FontWeight.w700, color: textColor)),
                Text(
                    '${Formatters.formatDate(s.date)}${s.description != null && s.description!.isNotEmpty ? ' · ${s.description}' : ''}',
                    style: ContractTheme.body(size: 12.5, color: subColor)),
              ],
            ),
          ),
          Text(Formatters.formatCurrency(s.amount),
              style: ContractTheme.display(size: 15, weight: FontWeight.w700, color: textColor)),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: subColor),
              onSelected: (action) {
                if (action == 'edit') _showServiceForm(existing: s);
                if (action == 'delete') _deleteService(s);
              },
              itemBuilder: (_) => [
                if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (canDelete)
                  const PopupMenuItem(
                      value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
              ],
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}
