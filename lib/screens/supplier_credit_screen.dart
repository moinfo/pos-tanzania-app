import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/permission_model.dart';
import '../models/supplier.dart';
import '../providers/permission_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'receiving_details_screen.dart';

class SupplierCreditScreen extends StatefulWidget {
  final int supplierId;
  final String supplierName;

  const SupplierCreditScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<SupplierCreditScreen> createState() => _SupplierCreditScreenState();
}

class _SupplierCreditScreenState extends State<SupplierCreditScreen> {
  final ApiService _apiService = ApiService();

  SupplierStatement? _statement;
  bool _isLoading = false;
  String? _errorMessage;

  String _startDate = DateFormat('yyyy-MM-dd').format(
    DateTime(DateTime.now().year, DateTime.now().month, 1),
  );
  String _endDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getSupplierStatement(
      widget.supplierId,
      startDate: _startDate,
      endDate: _endDate,
    );

    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _statement = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.parse(_startDate),
        end: DateTime.parse(_endDate),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateFormat('yyyy-MM-dd').format(picked.start);
        _endDate = DateFormat('yyyy-MM-dd').format(picked.end);
      });
      _loadStatement();
    }
  }

  void _showPaymentDialog() {
    // Get list of receivings on credit
    final creditReceivings = _statement?.transactions
        .where((t) => t.credit > 0 && t.receivingId != null)
        .toList() ?? [];

    showDialog(
      context: context,
      builder: (context) => SupplierPaymentDialog(
        supplierId: widget.supplierId,
        supplierName: widget.supplierName,
        currentBalance: _statement?.currentBalance ?? 0,
        creditReceivings: creditReceivings,
        onPaymentComplete: () {
          Navigator.pop(context);
          _loadStatement();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplierName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_statement != null) _buildBalanceCard(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Period: ${DateFormat('MMM d, y').format(DateTime.parse(_startDate))} - ${DateFormat('MMM d, y').format(DateTime.parse(_endDate))}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh', style: TextStyle(fontSize: 13)),
                    onPressed: _loadStatement,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage!,
                                style: const TextStyle(color: AppColors.error)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadStatement,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _statement == null || _statement!.transactions.isEmpty
                        ? const Center(child: Text('No transactions found'))
                        : _buildTransactionsList(),
          ),
        ],
      ),
      floatingActionButton: Consumer<PermissionProvider>(
        builder: (context, permissionProvider, child) {
          final canAddPayment = permissionProvider.hasPermission(PermissionIds.suppliersCreditorsPayment);

          if (!canAddPayment) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: _showPaymentDialog,
            backgroundColor: AppColors.success,
            icon: const Icon(Icons.payment, color: Colors.white),
            label: const Text('Add Payment', style: TextStyle(color: Colors.white)),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Opening Balance:',
                    style: TextStyle(fontSize: 14)),
                Text(
                  '${NumberFormat('#,###').format(_statement!.openingBalance.abs())} TSh',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Balance:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  '${NumberFormat('#,###').format(_statement!.currentBalance.abs())} TSh',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _statement!.currentBalance.abs() > 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    // Filter out transactions where both credit and debit are 0
    final validTransactions = _statement!.transactions
        .where((t) => t.credit > 0 || t.debit > 0)
        .toList();

    return ListView.builder(
      itemCount: validTransactions.length,
      itemBuilder: (context, index) {
        final transaction = validTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  void _showReceivingDetails(int receivingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceivingDetailsScreen(receivingId: receivingId),
      ),
    );
  }

  void _editPayment(SupplierTransaction transaction) {
    if (transaction.paymentId == null) return;

    showDialog(
      context: context,
      builder: (context) => SupplierPaymentDialog(
        supplierId: widget.supplierId,
        supplierName: widget.supplierName,
        currentBalance: _statement?.currentBalance ?? 0,
        creditReceivings: [],
        onPaymentComplete: () {
          Navigator.pop(context);
          _loadStatement();
        },
        editingPayment: transaction,
      ),
    );
  }

  Future<void> _deletePayment(SupplierTransaction transaction) async {
    if (transaction.paymentId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Are you sure you want to delete this payment of ${NumberFormat('#,###').format(transaction.debit)} TSh?'),
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

    if (confirm == true && mounted) {
      final response = await _apiService.deleteSupplierPayment(transaction.paymentId!);
      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment deleted successfully')),
          );
          _loadStatement();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.message}')),
          );
        }
      }
    }
  }

  Widget _buildTransactionCard(SupplierTransaction transaction) {
    final isCredit = transaction.credit > 0;
    final amount = isCredit ? transaction.credit : transaction.debit;
    final isPayment = !isCredit && transaction.paymentId != null;

    return Consumer<PermissionProvider>(
      builder: (context, permissionProvider, child) {
        final hasEdit = permissionProvider.hasPermission(PermissionIds.suppliersCreditorsEdit);
        final hasDelete = permissionProvider.hasPermission(PermissionIds.suppliersCreditorsDelete);

        final card = Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCredit ? AppColors.error : AppColors.success,
              child: Icon(
                isCredit ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white,
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    isCredit ? 'Receiving on Credit' : 'Payment',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${NumberFormat('#,###').format(amount)} TSh',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCredit ? AppColors.error : AppColors.success,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Date: ${DateFormat('MMM d, y').format(DateTime.parse(transaction.date))}'),
                if (transaction.receivingId != null)
                  Text('Receiving ID: #${transaction.receivingId}'),
                if (transaction.description != null && transaction.description!.isNotEmpty)
                  Text('Note: ${transaction.description}'),
                Text(
                  'Balance: ${NumberFormat('#,###').format(transaction.balance)} TSh',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            trailing: isCredit && transaction.receivingId != null
                ? const Icon(Icons.arrow_forward_ios, size: 16)
                : isPayment && (hasEdit || hasDelete)
                    ? PopupMenuButton(
                        itemBuilder: (context) => [
                          if (hasEdit)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                          if (hasDelete)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 20, color: AppColors.error),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _editPayment(transaction);
                          } else if (value == 'delete') {
                            _deletePayment(transaction);
                          }
                        },
                      )
                    : null,
          ),
        );

        // Make receiving transactions tappable
        if (isCredit && transaction.receivingId != null) {
          return InkWell(
            onTap: () => _showReceivingDetails(transaction.receivingId!),
            child: card,
          );
        }

        return card;
      },
    );
  }
}

class SupplierPaymentDialog extends StatefulWidget {
  final int supplierId;
  final String supplierName;
  final double currentBalance;
  final List<SupplierTransaction> creditReceivings;
  final VoidCallback onPaymentComplete;
  final SupplierTransaction? editingPayment;

  const SupplierPaymentDialog({
    super.key,
    required this.supplierId,
    required this.supplierName,
    required this.currentBalance,
    required this.creditReceivings,
    required this.onPaymentComplete,
    this.editingPayment,
  });

  @override
  State<SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends State<SupplierPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isSubmitting = false;
  int? _selectedReceivingId;
  int _stockLocationId = 1; // KIWANGWA
  int _paymentMode = 1; // 1=Sales, 2=Office
  int _paidPaymentType = 2; // 1=CASH, 2=BANK (default BANK)
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.editingPayment != null) {
      _amountController.text = widget.editingPayment!.debit.toString();
      _descriptionController.text = widget.editingPayment!.description ?? '';
      _selectedDate = DateTime.parse(widget.editingPayment!.date);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final description = _descriptionController.text.trim();
    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);

    dynamic response;

    if (widget.editingPayment != null) {
      // Edit mode
      final paymentData = {
        'amount': double.parse(_amountController.text),
        'description': description.isEmpty ? null : description,
        'date': dateString,
        'stock_location_id': _stockLocationId,
        'payment_mode': _paymentMode,
        'paid_payment_type': _paidPaymentType,
      };

      response = await _apiService.updateSupplierPayment(
        widget.editingPayment!.paymentId!,
        paymentData,
      );
    } else {
      // Add mode
      String finalDescription = description;
      if (_selectedReceivingId != null) {
        final receivingNote = 'Payment for Receiving #$_selectedReceivingId';
        finalDescription = description.isEmpty
            ? receivingNote
            : '$description - $receivingNote';
      }

      final formData = SupplierPaymentFormData(
        supplierId: widget.supplierId,
        amount: double.parse(_amountController.text),
        receivingId: _selectedReceivingId,
        stockLocationId: _stockLocationId,
        paymentMode: _paymentMode,
        paidPaymentType: _paidPaymentType,
        description: finalDescription.isEmpty ? null : finalDescription,
        date: dateString,
      );

      response = await _apiService.addSupplierPayment(formData);
    }

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editingPayment != null
                ? 'Payment updated successfully'
                : 'Payment added successfully'),
          ),
        );
        widget.onPaymentComplete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final permissionProvider = context.watch<PermissionProvider>();
    final hasDatePermission = permissionProvider.hasPermission(PermissionIds.suppliersCreditorsDate);

    return AlertDialog(
      title: Text(widget.editingPayment != null ? 'Edit Payment' : 'Add Payment'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supplier: ${widget.supplierName}'),
              const SizedBox(height: 8),
              Text(
                'Current Balance: ${NumberFormat('#,###').format(widget.currentBalance.abs())} TSh',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.currentBalance.abs() > 0
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.creditReceivings.isNotEmpty && widget.editingPayment == null) ...[
                DropdownButtonFormField<int>(
                  value: _selectedReceivingId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Receiving (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Choose a receiving to pay against',
                  ),
                  items: widget.creditReceivings.map((receiving) {
                    return DropdownMenuItem<int>(
                      value: receiving.receivingId,
                      child: Text(
                        'Receiving #${receiving.receivingId} - ${NumberFormat('#,###').format(receiving.credit)} TSh',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedReceivingId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount *',
                  border: OutlineInputBorder(),
                  prefixText: 'TSh ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter payment amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: hasDatePermission ? _selectDate : null,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Payment Date',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
                    enabled: hasDatePermission,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMM d, y').format(_selectedDate),
                        style: TextStyle(
                          color: hasDatePermission
                            ? (isDark ? AppColors.darkText : AppColors.text)
                            : Colors.grey,
                        ),
                      ),
                      Icon(
                        Icons.calendar_today,
                        color: hasDatePermission ? null : Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _paymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Sales')),
                  DropdownMenuItem(value: 2, child: Text('Office')),
                ],
                onChanged: (value) {
                  setState(() {
                    _paymentMode = value ?? 1;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _paidPaymentType,
                decoration: const InputDecoration(
                  labelText: 'Payment Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('CASH')),
                  DropdownMenuItem(value: 2, child: Text('BANK')),
                ],
                onChanged: (value) {
                  setState(() {
                    _paidPaymentType = value ?? 2;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Submit Payment'),
        ),
      ],
    );
  }
}

