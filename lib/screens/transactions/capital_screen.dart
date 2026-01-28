import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../providers/theme_provider.dart';

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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Capital'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter by date range',
          ),
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
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkDivider : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              boxShadow: isDark
                  ? null
                  : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
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
          // Summary cards
          if (!_isLoading) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard('Capital', _totalCapital, Icons.work, AppColors.primary, isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard('Commission', _totalCommission, Icons.percent, AppColors.success, isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard('Total', _actualCapital, Icons.account_balance_wallet, const Color(0xFF7C3AED), isDark),
                  ),
                ],
              ),
            ),
          ],
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
                                    style: TextStyle(fontSize: 16, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280))),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadCapital,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard(String label, double amount, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Text(
            Formatters.formatCurrency(amount),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1F2937)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(CapitalEntry entry, bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.work, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.formatCurrency(entry.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (entry.description.isNotEmpty)
                    Text(entry.description,
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280))),
                  Text(entry.date,
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextLight : const Color(0xFF9CA3AF))),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _showEditDialog(entry);
                if (value == 'delete') _deleteEntry(entry.id);
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