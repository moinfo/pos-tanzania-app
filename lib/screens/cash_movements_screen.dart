import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/cash_movement.dart';
import '../models/supervisor.dart';
import '../models/permission_model.dart';
import '../providers/permission_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

/// Direct Deposit / Direct Withdraw.
///
/// Both types live in one screen behind a segmented toggle: they share a
/// table, a form and a permission shape, and an approver comparing the two
/// would otherwise be bouncing between menu entries.
class CashMovementsScreen extends StatefulWidget {
  /// 'deposit' or 'withdraw' -- which tab to land on.
  final String initialType;

  const CashMovementsScreen({super.key, this.initialType = 'deposit'});

  @override
  State<CashMovementsScreen> createState() => _CashMovementsScreenState();
}

class _CashMovementsScreenState extends State<CashMovementsScreen> {
  final ApiService _apiService = ApiService();
  final _currency = NumberFormat('#,##0.##');

  late String _type;
  List<CashMovement> _movements = [];
  List<Supervisor> _supervisors = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Supervisors are needed by the form, not the list -- fetch alongside so
    // opening the form never shows an empty dropdown while it loads.
    final results = await Future.wait([
      _apiService.getCashMovements(_type),
      _apiService.getSupervisors(),
    ]);

    if (!mounted) return;

    final listResponse = results[0] as dynamic;
    final supervisorResponse = results[1] as dynamic;

    setState(() {
      _isLoading = false;
      if (listResponse.isSuccess && listResponse.data != null) {
        _movements = listResponse.data!.movements;
      } else {
        _errorMessage = listResponse.message;
      }
      if (supervisorResponse.isSuccess && supervisorResponse.data != null) {
        _supervisors = supervisorResponse.data!;
      }
    });
  }

  void _switchType(String type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _movements = [];
    });
    _load();
  }

  String get _typeLabel => _type == 'deposit' ? 'Deposit' : 'Withdraw';

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _supervisorName(int? id) {
    if (id == null) return 'Unassigned';
    for (final s in _supervisors) {
      if (s.id == id.toString()) return s.displayName;
    }
    return 'Supervisor #$id';
  }

  Future<void> _openForm({CashMovement? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CashMovementForm(
        type: _type,
        supervisors: _supervisors,
        existing: existing,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(CashMovement m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $_typeLabel'),
        content: Text(
          'Remove ${_currency.format(m.amount)} dated ${_formatDate(m.date)}? '
          'It stops counting toward the Cash Amount on Cash Submit.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final response = await _apiService.deleteCashMovement(_type, m.id);
    if (!mounted) return;

    messenger.showSnackBar(SnackBar(
      content: Text(response.message),
      backgroundColor: response.isSuccess ? AppColors.success : AppColors.error,
    ));
    if (response.isSuccess) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();
    final canAdd = permissions.hasPermission(PermissionIds.cashMovementAdd(_type));
    final canEdit = permissions.hasPermission(PermissionIds.cashMovementEdit(_type));
    final canDelete = permissions.hasPermission(PermissionIds.cashMovementDelete(_type));

    final total = _movements.fold<double>(0, (sum, m) => sum + m.amount);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Cash Movements'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('New $_typeLabel',
                  style: const TextStyle(color: Colors.white)),
            )
          : null,
      body: Column(
        children: [
          _buildTypeToggle(isDark),
          if (!_isLoading && _movements.isNotEmpty) _buildTotal(total, isDark),
          Expanded(child: _buildList(isDark, canEdit, canDelete)),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurface : Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(child: _typeChip('deposit', 'Deposits', Icons.south_west, isDark)),
          const SizedBox(width: 8),
          Expanded(child: _typeChip('withdraw', 'Withdrawals', Icons.north_east, isDark)),
        ],
      ),
    );
  }

  Widget _typeChip(String value, String label, IconData icon, bool isDark) {
    final selected = _type == value;
    final color = value == 'deposit' ? AppColors.success : AppColors.warning;

    return InkWell(
      onTap: () => _switchType(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
          border: Border.all(
            color: selected
                ? color
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 17,
                color: selected
                    ? color
                    : (isDark ? AppColors.darkTextLight : Colors.grey[600])),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? color
                    : (isDark ? AppColors.darkTextLight : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotal(double total, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? AppColors.darkAccent : AppColors.lightBackground,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_movements.length} entr${_movements.length == 1 ? 'y' : 'ies'}',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextLight : Colors.grey[600])),
          Text(
            'TSh ${_currency.format(total)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _type == 'deposit' ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(bool isDark, bool canEdit, bool canDelete) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark ? AppColors.darkTextLight : Colors.grey[600])),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_movements.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Icon(Icons.account_balance_wallet_outlined,
                size: 52, color: isDark ? Colors.grey[700] : Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No ${_typeLabel.toLowerCase()}s recorded',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? AppColors.darkTextLight : Colors.grey[500],
                    fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _movements.length,
        itemBuilder: (_, i) => _buildCard(_movements[i], isDark, canEdit, canDelete),
      ),
    );
  }

  Widget _buildCard(CashMovement m, bool isDark, bool canEdit, bool canDelete) {
    final color = m.isDeposit ? AppColors.success : AppColors.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TSh ${_currency.format(m.amount)}',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatDate(m.date)} · ${_supervisorName(m.supervisorId)}',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
                  ),
                  if (m.comment != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      m.comment!,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: isDark ? AppColors.darkTextLight : Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.info),
                onPressed: () => _openForm(existing: m),
                tooltip: 'Edit',
              ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                onPressed: () => _confirmDelete(m),
                tooltip: 'Delete',
              ),
          ],
        ),
      ),
    );
  }
}

/// Add / edit form. Mirrors the server's validation so the user is told about
/// a bad amount or date before a round trip, not after a 400.
class _CashMovementForm extends StatefulWidget {
  final String type;
  final List<Supervisor> supervisors;
  final CashMovement? existing;

  const _CashMovementForm({
    required this.type,
    required this.supervisors,
    this.existing,
  });

  @override
  State<_CashMovementForm> createState() => _CashMovementFormState();
}

class _CashMovementFormState extends State<_CashMovementForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  final ApiService _apiService = ApiService();

  late DateTime _date;
  int? _supervisorId;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController.text = existing?.amount.toString() ?? '';
    _commentController.text = existing?.comment ?? '';
    _supervisorId = existing?.supervisorId;
    _date = DateTime.tryParse(existing?.date ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supervisorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a supervisor'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final amount = double.parse(_amountController.text.trim());
    final date = DateFormat('yyyy-MM-dd').format(_date);
    final comment = _commentController.text.trim();

    final response = _isEdit
        ? await _apiService.updateCashMovement(
            type: widget.type,
            id: widget.existing!.id,
            amount: amount,
            date: date,
            supervisorId: _supervisorId!,
            comment: comment,
          )
        : await _apiService.createCashMovement(
            type: widget.type,
            amount: amount,
            date: date,
            supervisorId: _supervisorId!,
            comment: comment,
          );

    if (!mounted) return;
    setState(() => _isSaving = false);

    final messenger = ScaffoldMessenger.of(context);
    if (response.isSuccess) {
      Navigator.pop(context, true);
    }
    messenger.showSnackBar(SnackBar(
      content: Text(response.message),
      backgroundColor: response.isSuccess ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.type == 'deposit' ? 'Deposit' : 'Withdraw';

    return AlertDialog(
      title: Text('${_isEdit ? 'Edit' : 'New'} $label'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: !_isEdit,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  prefixText: 'TSh ',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  // Matches the server: is_numeric && > 0.
                  if (parsed == null) return 'Enter a number';
                  if (parsed <= 0) return 'Must be greater than zero';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_date)),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _supervisorId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Supervisor *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.supervisors
                    .map((s) => DropdownMenuItem(
                          value: int.tryParse(s.id),
                          child: Text(s.displayName, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _supervisorId = value),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _commentController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
