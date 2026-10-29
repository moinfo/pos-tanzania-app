import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../models/permission_model.dart';
import 'wakala_theme.dart';

class CapitalScreen extends StatefulWidget {
  const CapitalScreen({super.key});

  @override
  State<CapitalScreen> createState() => _CapitalScreenState();
}

class _CapitalScreenState extends State<CapitalScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<CapitalEntry> _entries = [];
  double _totalCapital = 0;
  double _totalCommission = 0;
  double _actualCapital = 0;

  DateTime _startDate = DateTime(2024, 1, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCapital();
  }

  Future<void> _loadCapital() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    try {
      final response = await _apiService.getCapitalEntries(
        startDate: startDateStr,
        endDate: endDateStr,
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _entries = response.data!.entries;
          _totalCapital = response.data!.totalCapital;
          _totalCommission = response.data!.totalCommission;
          _actualCapital = response.data!.actualCapital;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load capital entries';
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
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
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
      _loadCapital();
    }
  }

  Future<void> _deleteEntry(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Capital Entry'),
        content: const Text('Are you sure you want to delete this capital entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _apiService.deleteCapital(id);

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Capital entry deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadCapital();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to delete entry'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _CapitalFormDialog(
        onSaved: () {
          Navigator.pop(context);
          _loadCapital();
        },
      ),
    );
  }

  void _showEditDialog(CapitalEntry entry) {
    showDialog(
      context: context,
      builder: (context) => _CapitalFormDialog(
        entry: entry,
        onSaved: () {
          Navigator.pop(context);
          _loadCapital();
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
        .hasPermission(PermissionIds.transactionsCapitalDateRange);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: WakalaTheme.appBar(
        isDark: isDark,
        eyebrow: 'Investment',
        title: 'Capital',
        actions: [
          if (canChangeDateRange)
            IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: _selectDateRange,
              tooltip: 'Filter by date range',
            ),
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
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(child: _buildSummaryCard('Capital', _totalCapital, Icons.work_outline, WakalaTint.blue, isDark)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSummaryCard('Commission', _totalCommission, Icons.percent, WakalaTint.green, isDark)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSummaryCard('Total', _actualCapital, Icons.account_balance_wallet_outlined, WakalaTint.amber, isDark)),
                ],
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
                            ElevatedButton(onPressed: _loadCapital, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.work_outline, size: 64, color: isDark ? AppColors.darkTextLight : const Color(0xFF9CA3AF)),
                                const SizedBox(height: 16),
                                Text('No capital entries found',
                                    style: WakalaTheme.body(size: 16, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280))),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadCapital,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                              itemCount: _entries.length,
                              itemBuilder: (context, index) {
                                final entry = _entries[index];
                                return _buildEntryCard(entry, isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Capital'),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSummaryCard(String label, double amount, IconData icon, WakalaTint tint, bool isDark) {
    return WakalaPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WakalaIconTile(icon: icon, tint: tint, size: 32),
          const SizedBox(height: 6),
          Text(label, style: WakalaTheme.body(size: 12, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
          Text(
            Formatters.formatCurrency(amount),
            style: WakalaTheme.display(size: 17, weight: FontWeight.w700, letterSpacing: -0.2, color: isDark ? AppColors.darkText : AppColors.text),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(CapitalEntry entry, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WakalaCard(
        child: Row(
          children: [
            const WakalaIconTile(icon: Icons.work_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Formatters.formatCurrency(entry.amount),
                      style: WakalaTheme.display(size: 20, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                  if (entry.description.isNotEmpty)
                    Text(entry.description, style: WakalaTheme.body(size: 13, color: isDark ? AppColors.darkText : AppColors.text)),
                  Text(entry.date, style: WakalaTheme.body(size: 12.5, color: isDark ? AppColors.darkTextLight : const Color(0xFF6C757D))),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: isDark ? AppColors.darkTextLight : AppColors.text),
              onSelected: (value) {
                if (value == 'edit') _showEditDialog(entry);
                if (value == 'delete') _deleteEntry(entry.id);
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

class _CapitalFormDialog extends StatefulWidget {
  final CapitalEntry? entry;
  final VoidCallback onSaved;

  const _CapitalFormDialog({this.entry, required this.onSaved});

  @override
  State<_CapitalFormDialog> createState() => _CapitalFormDialogState();
}

class _CapitalFormDialogState extends State<_CapitalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _amountController.text = widget.entry!.amount.toStringAsFixed(0);
      _descriptionController.text = widget.entry!.description;
      _selectedDate = DateTime.tryParse(widget.entry!.date) ?? DateTime.now();
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

    setState(() => _isSaving = true);

    final formData = CapitalFormData(
      amount: double.parse(_amountController.text),
      description: _descriptionController.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
    );

    final response = _isEditing
        ? await _apiService.updateCapital(widget.entry!.id, formData)
        : await _apiService.addCapital(formData);

    setState(() => _isSaving = false);

    if (mounted) {
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Capital updated successfully' : 'Capital added successfully'),
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
        .hasPermission(PermissionIds.transactionsCapitalDate);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Capital' : 'Add Capital'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}