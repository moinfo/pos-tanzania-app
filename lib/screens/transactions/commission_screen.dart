import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/api_response.dart';
import '../../models/transaction.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../models/permission_model.dart';
import 'wakala_theme.dart';

class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<Commission> _commissions = [];
  double _total = 0;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Source options for the form
  List<Map<String, dynamic>> _sims = [];
  List<Map<String, dynamic>> _bankBasis = [];

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

    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    try {
      // Load commissions and source options in parallel
      final commissionsFuture = _apiService.getCommissions(startDate: startDateStr, endDate: endDateStr);
      final simsFuture = _apiService.getSims();
      final bankFuture = _apiService.getBankBasisCategories();

      final results = await Future.wait([commissionsFuture, simsFuture, bankFuture]);

      final commissionsResp = results[0] as ApiResponse<CommissionResponse>;
      final simsResp = results[1] as ApiResponse<List<Sim>>;
      final bankResp = results[2] as ApiResponse<List<BankBasisCategory>>;

      if (commissionsResp.isSuccess && commissionsResp.data != null) {
        setState(() {
          _commissions = commissionsResp.data!.commissions;
          _total = commissionsResp.data!.total;

          if (simsResp.isSuccess && simsResp.data != null) {
            _sims = simsResp.data!.map((s) => {'id': s.id, 'name': s.name}).toList();
          }
          if (bankResp.isSuccess && bankResp.data != null) {
            _bankBasis = bankResp.data!.map((b) => {'id': b.id, 'name': b.name}).toList();
          }

          _isLoading = false;
        });
      } else {
        setState(() {
          _error = commissionsResp.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load commissions';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  Future<void> _deleteCommission(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Commission'),
        content: const Text('Are you sure you want to delete this commission?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _apiService.deleteCommission(id);
      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commission deleted successfully'), backgroundColor: AppColors.success),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? 'Failed to delete'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _CommissionFormDialog(
        sims: _sims,
        bankBasis: _bankBasis,
        onSaved: () {
          Navigator.pop(context);
          _loadData();
        },
      ),
    );
  }

  void _showEditDialog(Commission commission) {
    showDialog(
      context: context,
      builder: (context) => _CommissionFormDialog(
        commission: commission,
        sims: _sims,
        bankBasis: _bankBasis,
        onSaved: () {
          Navigator.pop(context);
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    // Watched, not read, so the screen re-gates itself when permissions refresh.
    final canChangeDateRange = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.transactionsCommissionDateRange);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: WakalaTheme.appBar(
        isDark: isDark,
        eyebrow: 'Earnings',
        title: 'Commission',
        actions: [
          if (canChangeDateRange)
            IconButton(icon: const Icon(Icons.date_range), onPressed: _selectDateRange, tooltip: 'Filter by date range'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.date_range, size: 18, color: Color(0xFF1E40AF)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${DateFormat('MMM d, yyyy').format(_startDate)} – ${DateFormat('MMM d, yyyy').format(_endDate)}',
                      style: WakalaTheme.display(size: 15, weight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.text),
                    ),
                  ),
                  // Second entry point to the same range picker as the app bar
                  // button, so it needs the same gate.
                  TextButton.icon(
                    onPressed: canChangeDateRange ? _selectDateRange : null,
                    icon: const Icon(Icons.edit_calendar, size: 16),
                    label: const Text('Change'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1E40AF),
                      backgroundColor: const Color(0xFFDBEAFE),
                      textStyle: WakalaTheme.body(size: 14, weight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_isLoading && _commissions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: WakalaCard(
                railColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const WakalaIconTile(icon: Icons.percent, tint: WakalaTint.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total commission', style: WakalaTheme.body(size: 12, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
                          Text(Formatters.formatCurrency(_total),
                              style: WakalaTheme.display(size: 28, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(999)),
                      child: Text('${_commissions.length} ${_commissions.length == 1 ? 'entry' : 'entries'}',
                          style: WakalaTheme.body(size: 12, weight: FontWeight.w600, color: const Color(0xFF047857))),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(_error!, style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _commissions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.percent, size: 64, color: isDark ? AppColors.darkTextLight : const Color(0xFF9CA3AF)),
                                const SizedBox(height: 16),
                                Text('No commissions found',
                                    style: WakalaTheme.body(size: 16, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280))),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                              itemCount: _commissions.length,
                              itemBuilder: (context, index) {
                                final c = _commissions[index];
                                return _buildCommissionCard(c, isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Commission'),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildCommissionCard(Commission c, bool isDark) {
    final isWakala = c.sourceType == 'wakala';
    final tint = isWakala ? WakalaTint.amber : WakalaTint.blue;
    final railColor = isWakala ? AppColors.warning : AppColors.primary;
    final badgeLabel = isWakala ? 'Wakala' : 'Bank';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WakalaCard(
        railColor: railColor,
        child: Row(
          children: [
            WakalaIconTile(icon: isWakala ? Icons.sim_card_outlined : Icons.account_balance_outlined, tint: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: tint.background, borderRadius: BorderRadius.circular(999)),
                    child: Text(badgeLabel.toUpperCase(),
                        style: WakalaTheme.body(size: 11, weight: FontWeight.w700, color: tint.foreground).copyWith(letterSpacing: 0.6)),
                  ),
                  Text(Formatters.formatCurrency(c.amount),
                      style: WakalaTheme.display(size: 20, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                  if (c.description.isNotEmpty)
                    Text(c.description, style: WakalaTheme.body(size: 13, color: isDark ? AppColors.darkText : AppColors.text)),
                  Text(c.date, style: WakalaTheme.body(size: 12.5, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: isDark ? AppColors.darkTextLight : AppColors.text),
              onSelected: (value) {
                if (value == 'edit') _showEditDialog(c);
                if (value == 'delete') _deleteCommission(c.id);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommissionFormDialog extends StatefulWidget {
  final Commission? commission;
  final List<Map<String, dynamic>> sims;
  final List<Map<String, dynamic>> bankBasis;
  final VoidCallback onSaved;

  const _CommissionFormDialog({this.commission, required this.sims, required this.bankBasis, required this.onSaved});

  @override
  State<_CommissionFormDialog> createState() => _CommissionFormDialogState();
}

class _CommissionFormDialogState extends State<_CommissionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _sourceType = 'wakala';
  int? _sourceId;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.commission != null;

  List<Map<String, dynamic>> get _sourceOptions => _sourceType == 'wakala' ? widget.sims : widget.bankBasis;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _amountController.text = widget.commission!.amount.toStringAsFixed(0);
      _descriptionController.text = widget.commission!.description;
      _sourceType = widget.commission!.sourceType;
      _sourceId = widget.commission!.sourceId;
      _selectedDate = DateTime.tryParse(widget.commission!.date) ?? DateTime.now();
    } else {
      if (widget.sims.isNotEmpty) _sourceId = widget.sims.first['id'];
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a source account'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);

    final formData = CommissionFormData(
      sourceType: _sourceType,
      sourceId: _sourceId!,
      amount: double.parse(_amountController.text),
      description: _descriptionController.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
    );

    final response = _isEditing
        ? await _apiService.updateCommission(widget.commission!.id, formData)
        : await _apiService.addCommission(formData);

    setState(() => _isSaving = false);

    if (mounted) {
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Commission updated successfully' : 'Commission added successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? 'Failed to save'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Without this grant the entry is pinned to today, matching how web renders
    // the date input readonly (views/transactions/footer.php).
    final canChangeDate = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.transactionsCommissionDate);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Commission' : 'Add Commission'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Source Type
              DropdownButtonFormField<String>(
                value: _sourceType,
                decoration: const InputDecoration(labelText: 'Source Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'wakala', child: Text('Wakala')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                ],
                onChanged: (value) {
                  setState(() {
                    _sourceType = value!;
                    final options = _sourceType == 'wakala' ? widget.sims : widget.bankBasis;
                    _sourceId = options.isNotEmpty ? options.first['id'] : null;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Source Account
              DropdownButtonFormField<int>(
                value: _sourceOptions.any((o) => o['id'] == _sourceId) ? _sourceId : null,
                decoration: const InputDecoration(labelText: 'Account', border: OutlineInputBorder()),
                items: _sourceOptions.map((o) => DropdownMenuItem<int>(value: o['id'], child: Text(o['name'].toString()))).toList(),
                onChanged: (value) => setState(() => _sourceId = value),
                validator: (v) => v == null ? 'Please select an account' : null,
              ),
              const SizedBox(height: 16),
              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount', prefixText: 'TZS ', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Amount is required';
                  if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Date
              InkWell(
                onTap: canChangeDate
                    ? () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      }
                    : null,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                  child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
