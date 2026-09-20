import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../models/contract.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Create a contract, optionally pre-filled from an existing one.
///
/// There's no separate "renew" concept on the backend -- a renewal is just
/// a new contract for a customer who already has (or had) one, so this one
/// screen covers both: opened bare for "New Contract", or with
/// [renewFrom] set to carry over the customer's identity (name, phone,
/// guarantors) and a starting point for the terms (rate, cost, duration),
/// while resetting the dates to start fresh from whatever day the user
/// picks -- including a future date, for someone who wants to line up
/// their next contract before the current one closes out.
class ContractFormScreen extends StatefulWidget {
  final Contract? renewFrom;

  const ContractFormScreen({super.key, this.renewFrom});

  @override
  State<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends State<ContractFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _guarantor1Controller;
  late final TextEditingController _phoneGuarantor1Controller;
  late final TextEditingController _guarantor2Controller;
  late final TextEditingController _phoneGuarantor2Controller;
  late final TextEditingController _descriptionController;
  late final TextEditingController _contractTimeController;
  late final TextEditingController _returnAmountController;
  late final TextEditingController _contractCostController;
  late final TextEditingController _contractAmountController;
  late final TextEditingController _assetPlateController;
  late final TextEditingController _assetChassisController;
  late final TextEditingController _assetInsuranceProviderController;

  DateTime _startDate = DateTime.now();
  // Asset info is per-vehicle, so a renewal never inherits it -- the old
  // contract's bike/insurance almost never carries over to the new one.
  DateTime? _assetInsuranceExpiry;
  bool _isSaving = false;

  bool get _isRenewal => widget.renewFrom != null;

  @override
  void initState() {
    super.initState();
    final from = widget.renewFrom;
    _nameController = TextEditingController(text: from?.name ?? '');
    _phoneController = TextEditingController(text: from?.phone ?? '');
    _guarantor1Controller = TextEditingController(text: from?.guarantor1 ?? '');
    _phoneGuarantor1Controller =
        TextEditingController(text: from?.phoneGuarantor1 ?? '');
    _guarantor2Controller = TextEditingController(text: from?.guarantor2 ?? '');
    _phoneGuarantor2Controller =
        TextEditingController(text: from?.phoneGuarantor2 ?? '');
    _descriptionController =
        TextEditingController(text: from?.contractDescription ?? '');
    _contractTimeController =
        TextEditingController(text: (from?.contractTime ?? 30).toString());
    _returnAmountController = TextEditingController(
        text: from == null ? '' : _formatNum(from.returnAmount));
    _contractCostController = TextEditingController(
        text: from == null ? '' : _formatNum(from.contractCost));
    _contractAmountController = TextEditingController(
        text: from == null ? '' : _formatNum(from.contractAmount));
    _assetPlateController = TextEditingController();
    _assetChassisController = TextEditingController();
    _assetInsuranceProviderController = TextEditingController();
  }

  String _formatNum(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _guarantor1Controller.dispose();
    _phoneGuarantor1Controller.dispose();
    _guarantor2Controller.dispose();
    _phoneGuarantor2Controller.dispose();
    _descriptionController.dispose();
    _contractTimeController.dispose();
    _returnAmountController.dispose();
    _contractCostController.dispose();
    _contractAmountController.dispose();
    _assetPlateController.dispose();
    _assetChassisController.dispose();
    _assetInsuranceProviderController.dispose();
    super.dispose();
  }

  int get _contractTimeDays =>
      int.tryParse(_contractTimeController.text.trim()) ?? 0;

  DateTime get _endDate => _startDate
      .add(Duration(days: _contractTimeDays > 0 ? _contractTimeDays - 1 : 0));

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Contract start date',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickInsuranceExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _assetInsuranceExpiry ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: 'Insurance expiry date',
    );
    if (picked != null) setState(() => _assetInsuranceExpiry = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contractTimeDays <= 0) {
      _showSnack('Contract time must be at least 1 day', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final response = await _apiService.createContract(
      name: _nameController.text.trim(),
      date: Formatters.formatDateForApi(_startDate),
      endDate: Formatters.formatDateForApi(_endDate),
      contractTime: _contractTimeDays,
      returnAmount: double.parse(_returnAmountController.text.trim()),
      contractCost: double.parse(_contractCostController.text.trim()),
      contractAmount: double.parse(_contractAmountController.text.trim()),
      phone: _phoneController.text.trim(),
      guarantor1: _guarantor1Controller.text.trim(),
      phoneGuarantor1: _phoneGuarantor1Controller.text.trim(),
      guarantor2: _guarantor2Controller.text.trim(),
      phoneGuarantor2: _phoneGuarantor2Controller.text.trim(),
      contractDescription: _descriptionController.text.trim(),
      assetPlateNumber: _assetPlateController.text.trim(),
      assetChassisNumber: _assetChassisController.text.trim(),
      assetInsuranceProvider: _assetInsuranceProviderController.text.trim(),
      assetInsuranceExpiry: _assetInsuranceExpiry == null
          ? null
          : Formatters.formatDateForApi(_assetInsuranceExpiry!),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (response.isSuccess) {
      Navigator.pop(context, true);
      _showSnack(_isRenewal ? 'Contract renewed' : 'Contract created');
    } else {
      _showSnack(response.message ?? 'Failed to save contract', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(_isRenewal ? 'Renew Contract' : 'New Contract'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_isRenewal)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pre-filled from ${widget.renewFrom!.name}\'s previous contract. '
                        'This creates a new, independent contract -- the old one is untouched.',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            _sectionLabel('Customer', isDark),
            _textField(_nameController, 'Full Name', required: true),
            _textField(_phoneController, 'Phone',
                keyboardType: TextInputType.phone),
            _textField(_guarantor1Controller, 'Guarantor 1 Name'),
            _textField(_phoneGuarantor1Controller, 'Guarantor 1 Phone',
                keyboardType: TextInputType.phone),
            _textField(_guarantor2Controller, 'Guarantor 2 Name'),
            _textField(_phoneGuarantor2Controller, 'Guarantor 2 Phone',
                keyboardType: TextInputType.phone),
            _textField(_descriptionController, 'Description', maxLines: 2),
            const SizedBox(height: 8),
            _sectionLabel('Terms', isDark),
            OutlinedButton.icon(
              onPressed: _pickStartDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                  'Start: ${Formatters.formatDate(Formatters.formatDateForApi(_startDate))}'),
            ),
            const SizedBox(height: 12),
            _textField(
              _contractTimeController,
              'Contract Time (days)',
              required: true,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Ends: ${Formatters.formatDate(Formatters.formatDateForApi(_endDate))}',
                style: TextStyle(
                    fontSize: 12.5,
                    color:
                        isDark ? AppColors.darkTextLight : AppColors.textLight),
              ),
            ),
            _textField(_returnAmountController, 'Daily Rate',
                required: true, isNumeric: true),
            _textField(_contractCostController, 'Contract Cost (asset cost)',
                required: true, isNumeric: true),
            _textField(
                _contractAmountController, 'Contract Amount (total owed)',
                required: true, isNumeric: true),
            const SizedBox(height: 8),
            _sectionLabel('Vehicle / Asset Info (optional)', isDark),
            _textField(_assetPlateController, 'Plate Number'),
            _textField(_assetChassisController, 'Chassis Number'),
            _textField(_assetInsuranceProviderController, 'Insurance Provider'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _pickInsuranceExpiry,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_assetInsuranceExpiry == null
                    ? 'Insurance Expiry'
                    : 'Insurance Expiry: ${Formatters.formatDate(Formatters.formatDateForApi(_assetInsuranceExpiry!))}'),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isRenewal
                      ? 'Create Renewed Contract'
                      : 'Create Contract'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkTextLight : AppColors.textLight,
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool isNumeric = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : keyboardType,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: (value) {
          final v = value?.trim() ?? '';
          if (required && v.isEmpty) return 'Required';
          if (isNumeric && v.isNotEmpty && double.tryParse(v) == null) {
            return 'Enter a valid number';
          }
          return null;
        },
        onChanged: onChanged,
      ),
    );
  }
}
