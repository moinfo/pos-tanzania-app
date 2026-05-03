import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/borrowed_money.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class BorrowedMoneyFormScreen extends StatefulWidget {
  final BorrowedMoneyItem? record;

  const BorrowedMoneyFormScreen({super.key, this.record});

  @override
  State<BorrowedMoneyFormScreen> createState() =>
      _BorrowedMoneyFormScreenState();
}

class _BorrowedMoneyFormScreenState extends State<BorrowedMoneyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _amountController.text = widget.record!.amount.toStringAsFixed(0);
      _descriptionController.text = widget.record!.description;
      _selectedDate = DateTime.tryParse(widget.record!.date) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final record = BorrowedMoneyCreate(
      amount: double.parse(_amountController.text.replaceAll(',', '')),
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      description: _descriptionController.text.trim(),
    );

    try {
      final response = _isEditing
          ? await _apiService.updateBorrowedMoney(widget.record!.id, record)
          : await _apiService.createBorrowedMoney(record);

      if (!mounted) return;

      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Record updated' : 'Record created'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Borrowed Money' : 'Add Borrowed Money'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (TSh)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Amount is required';
                  final parsed =
                      double.tryParse(v.replaceAll(',', ''));
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Date
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 20),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: const Icon(Icons.notes),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isEditing ? 'Update' : 'Save',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}