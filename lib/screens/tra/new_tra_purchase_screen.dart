import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/constants.dart';
import '../../models/tra.dart';
import '../../providers/theme_provider.dart';
import '../../services/tra_service.dart';

class NewTRAPurchaseScreen extends StatefulWidget {
  final List<EFDDevice> efds;
  final TRAPurchase? purchase; // For editing
  final bool isExpense;

  const NewTRAPurchaseScreen({
    super.key,
    required this.efds,
    this.purchase,
    this.isExpense = false,
  });

  @override
  State<NewTRAPurchaseScreen> createState() => _NewTRAPurchaseScreenState();
}

class _NewTRAPurchaseScreenState extends State<NewTRAPurchaseScreen> {
  final TRAService _traService = TRAService();
  final _formKey = GlobalKey<FormState>();

  int? _selectedEfdId;
  int? _selectedSupplierId;
  int? _selectedItemId;
  String _purchaseType = TRAPurchaseTypes.types.first;
  final _taxInvoiceController = TextEditingController();
  final _amountVatExcController = TextEditingController();
  final _vatAmountController = TextEditingController();
  final _totalAmountController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  DateTime _purchaseDate = DateTime.now();
  String? _fileBase64;
  File? _selectedFile;
  bool _isLoading = false;

  List<TRASupplier> _suppliers = [];
  List<TRAItem> _items = [];
  bool _loadingDropdowns = true;

  bool get isEditing => widget.purchase != null;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (isEditing) {
      _populateForm();
    } else if (widget.efds.isNotEmpty) {
      _selectedEfdId = widget.efds.first.id;
    }
  }

  Future<void> _loadDropdowns() async {
    final suppliers = await _traService.getSuppliers();
    final items = await _traService.getItems();

    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        _items = items;
        _loadingDropdowns = false;
      });
    }
  }

  void _populateForm() {
    final purchase = widget.purchase!;
    _selectedEfdId = purchase.efdId;
    _selectedSupplierId = purchase.supplierId;
    _selectedItemId = purchase.itemId;
    _purchaseType = purchase.purchaseType;
    _taxInvoiceController.text = purchase.taxInvoice;
    _amountVatExcController.text = purchase.amountVatExc.toString();
    _vatAmountController.text = purchase.vatAmount.toString();
    _totalAmountController.text = purchase.totalAmount.toString();
    _purchaseDate = DateTime.parse(purchase.date);
    if (purchase.invoiceDate != null && purchase.invoiceDate!.isNotEmpty) {
      _invoiceDate = DateTime.parse(purchase.invoiceDate!);
    }
  }

  void _calculateTotal() {
    final amountExc = double.tryParse(_amountVatExcController.text) ?? 0;
    final vatAmount = double.tryParse(_vatAmountController.text) ?? 0;
    final total = amountExc + vatAmount;
    _totalAmountController.text = total.toStringAsFixed(2);
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      setState(() {
        _selectedFile = File(image.path);
        _fileBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    }
  }

  Future<void> _selectDate({required bool isInvoiceDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isInvoiceDate ? _invoiceDate : _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
        if (isInvoiceDate) {
          _invoiceDate = picked;
        } else {
          _purchaseDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEfdId == null || _selectedSupplierId == null || _selectedItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final purchaseData = TRAPurchaseCreate(
      efdId: _selectedEfdId!,
      supplierId: _selectedSupplierId!,
      itemId: _selectedItemId!,
      purchaseType: _purchaseType,
      amountVatExc: double.parse(_amountVatExcController.text),
      vatAmount: double.tryParse(_vatAmountController.text) ?? 0,
      totalAmount: double.parse(_totalAmountController.text),
      taxInvoice: _taxInvoiceController.text,
      invoiceDate: DateFormat('yyyy-MM-dd').format(_invoiceDate),
      date: DateFormat('yyyy-MM-dd').format(_purchaseDate),
      isExpense: widget.isExpense ? 'YES' : 'NO',
      file: _fileBase64,
    );

    final result = widget.isExpense
        ? (isEditing
            ? await _traService.updateExpense(widget.purchase!.id, purchaseData)
            : await _traService.createExpense(purchaseData))
        : (isEditing
            ? await _traService.updatePurchase(widget.purchase!.id, purchaseData)
            : await _traService.createPurchase(purchaseData));

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppColors.success : AppColors.error,
        ),
      );

      if (result.success) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  void dispose() {
    _taxInvoiceController.dispose();
    _amountVatExcController.dispose();
    _vatAmountController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final title = widget.isExpense
        ? (isEditing ? 'Edit Expense' : 'New Expense')
        : (isEditing ? 'Edit Purchase' : 'New Purchase');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loadingDropdowns
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // EFD Device
                    _buildLabel('EFD Device *', isDark),
                    DropdownButtonFormField<int>(
                      value: _selectedEfdId,
                      decoration: _inputDecoration('Select EFD', isDark),
                      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                      items: widget.efds.map((efd) => DropdownMenuItem<int>(
                            value: efd.id,
                            child: Text(efd.name),
                          )).toList(),
                      onChanged: (value) => setState(() => _selectedEfdId = value),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Supplier
                    _buildLabel('Supplier *', isDark),
                    DropdownButtonFormField<int>(
                      value: _selectedSupplierId,
                      decoration: _inputDecoration('Select Supplier', isDark),
                      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                      isExpanded: true,
                      items: _suppliers.map((s) => DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(s.name, overflow: TextOverflow.ellipsis),
                          )).toList(),
                      onChanged: (value) => setState(() => _selectedSupplierId = value),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Item
                    _buildLabel('Item *', isDark),
                    DropdownButtonFormField<int>(
                      value: _selectedItemId,
                      decoration: _inputDecoration('Select Item', isDark),
                      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                      isExpanded: true,
                      items: _items.map((i) => DropdownMenuItem<int>(
                            value: i.id,
                            child: Text(i.name, overflow: TextOverflow.ellipsis),
                          )).toList(),
                      onChanged: (value) => setState(() => _selectedItemId = value),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Purchase Type
                    _buildLabel('Purchase Type *', isDark),
                    DropdownButtonFormField<String>(
                      value: _purchaseType,
                      decoration: _inputDecoration('Select Type', isDark),
                      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                      items: TRAPurchaseTypes.types.map((t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(t),
                          )).toList(),
                      onChanged: (value) => setState(() => _purchaseType = value!),
                    ),
                    const SizedBox(height: 16),

                    // Tax Invoice
                    _buildLabel('Tax Invoice Number *', isDark),
                    TextFormField(
                      controller: _taxInvoiceController,
                      decoration: _inputDecoration('Enter tax invoice number', isDark),
                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Dates
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Invoice Date', isDark),
                              _buildDatePicker(_invoiceDate, isDark, () => _selectDate(isInvoiceDate: true)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Purchase Date', isDark),
                              _buildDatePicker(_purchaseDate, isDark, () => _selectDate(isInvoiceDate: false)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amount Excluding VAT
                    _buildLabel('Amount (Excl. VAT) *', isDark),
                    TextFormField(
                      controller: _amountVatExcController,
                      decoration: _inputDecoration('Enter amount excluding VAT', isDark),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                      onChanged: (_) => _calculateTotal(),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (double.tryParse(value) == null) return 'Invalid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // VAT Amount
                    _buildLabel('VAT Amount', isDark),
                    TextFormField(
                      controller: _vatAmountController,
                      decoration: _inputDecoration('Enter VAT amount', isDark),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                      onChanged: (_) => _calculateTotal(),
                    ),
                    const SizedBox(height: 16),

                    // Total Amount
                    _buildLabel('Total Amount *', isDark),
                    TextFormField(
                      controller: _totalAmountController,
                      decoration: _inputDecoration('Total amount', isDark),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (double.tryParse(value) == null) return 'Invalid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // File Upload
                    _buildLabel('Document (Optional)', isDark),
                    InkWell(
                      onTap: _pickFile,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedFile != null ? Icons.check_circle : Icons.upload_file,
                              color: _selectedFile != null ? AppColors.success : AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedFile != null
                                    ? 'File selected: ${_selectedFile!.path.split('/').last}'
                                    : 'Tap to upload document',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isExpense ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(isEditing
                                ? (widget.isExpense ? 'Update Expense' : 'Update Purchase')
                                : (widget.isExpense ? 'Create Expense' : 'Create Purchase')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white70 : AppColors.lightTextLight,
        ),
      ),
    );
  }

  Widget _buildDatePicker(DateTime date, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMM dd, yyyy').format(date),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
