import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/api_response.dart';
import '../../utils/constants.dart';
import 'industry_report_section_view.dart';

/// Describes one field on a [DateScopedEntryScreen]'s form.
class EntryField {
  final String jsonKey; // key read from the GET response's entry map
  final String formKey; // key sent in the POST body
  final String label;
  final TextInputType keyboardType;

  const EntryField({
    required this.jsonKey,
    required this.formKey,
    required this.label,
    this.keyboardType = TextInputType.number,
  });
}

/// Generic screen for the "GET entry-for-date (+ stock card) / POST
/// save-for-date" shape shared by Roller (bag opening/usage/trimming),
/// Mattress (cutting), and Production (production/welding/dozens/packing).
/// Configured per use rather than duplicated per tab.
class DateScopedEntryScreen extends StatefulWidget {
  final String title;
  final List<EntryField> fields;
  final Future<ApiResponse<Map<String, dynamic>>> Function(String date) onLoad;
  final Future<ApiResponse<Map<String, dynamic>>> Function(
    String date,
    Map<String, String> values,
  ) onSave;
  final VoidCallback onSessionExpired;

  const DateScopedEntryScreen({
    super.key,
    required this.title,
    required this.fields,
    required this.onLoad,
    required this.onSave,
    required this.onSessionExpired,
  });

  @override
  State<DateScopedEntryScreen> createState() => _DateScopedEntryScreenState();
}

class _DateScopedEntryScreenState extends State<DateScopedEntryScreen> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, TextEditingController> _controllers = {};
  Map<String, dynamic>? _entry;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      _controllers[field.formKey] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await widget.onLoad(_dateStr);

    if (!mounted) return;

    if (response.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    if (!response.isSuccess) {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _entry = response.data;
      for (final field in widget.fields) {
        _controllers[field.formKey]?.text = response.data?[field.jsonKey]?.toString() ?? '0';
      }
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final values = {
      for (final field in widget.fields) field.formKey: _controllers[field.formKey]?.text ?? '0',
    };

    final response = await widget.onSave(_dateStr, values);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message),
        backgroundColor: response.isSuccess ? Colors.green : Colors.red,
      ),
    );

    if (response.isSuccess) {
      _load();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: AppColors.brandPrimary),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: industryScrollPadding(context),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEE, d MMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      TextButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: const Text('Change date'),
                      ),
                    ],
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 16),
                  ...widget.fields.map((field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: _controllers[field.formKey],
                          keyboardType: field.keyboardType,
                          decoration: InputDecoration(
                            labelText: field.label,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      )),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save'),
                    ),
                  ),
                  if (_entry != null) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('Stock detail',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandPrimary)),
                    const SizedBox(height: 8),
                    IndustryReportSectionView(
                      data: Map.fromEntries(
                        _entry!.entries.where((e) => !widget.fields.any((f) => f.jsonKey == e.key)),
                      ),
                      accentColor: AppColors.brandPrimary,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
