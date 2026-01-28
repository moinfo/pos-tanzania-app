import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/api_response.dart';
import '../../models/transaction.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../providers/theme_provider.dart';

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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Commission'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: _selectDateRange, tooltip: 'Filter by date range'),
        ],
      ),
      body: Column(
        children: [
          // Date range display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? AppColors.darkDivider : const Color(0xFFE5E7EB), width: 1)),
              boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1F2937)),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.primary.withOpacity(isDark ? 0.1 : 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          // Total summary
          if (!_isLoading && _commissions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark ? [AppColors.darkCard, AppColors.darkSurface] : [Colors.white, const Color(0xFFFAFAFA)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB), width: 1),
                boxShadow: isDark
                    ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 1, offset: const Offset(0, 1)), BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.percent, color: AppColors.success, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Commission', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280))),
                          const SizedBox(height: 4),
                          Text(
                            Formatters.formatCurrency(_total),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1F2937)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('${_commissions.length} entries', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ],
              ),
            ),
          // Content
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
                                Text('No commissions found', style: TextStyle(fontSize: 16, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280))),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCommissionCard(Commission c, bool isDark) {
    final isWakala = c.sourceType == 'wakala';
    final badgeColor = isWakala ? const Color(0xFFD97706) : AppColors.primary;
    final badgeLabel = isWakala ? 'Wakala' : 'Bank';

    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(isWakala ? Icons.sim_card : Icons.account_balance, color: badgeColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Text(badgeLabel, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(c.sourceName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : const Color(0xFF374151)), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(Formatters.formatCurrency(c.amount),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  if (c.description.isNotEmpty) Text(c.description, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280))),
                  Text(c.date, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextLight : const Color(0xFF9CA3AF))),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _showEditDialog(c);
                if (value == 'delete') _deleteCommission(c.id);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
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
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
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
