import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/credit.dart';
import '../models/permission_model.dart';
import '../models/stock_location.dart';
import '../providers/permission_provider.dart';
import '../providers/location_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/permission_wrapper.dart';
import 'sale_details_screen.dart';

class CustomerCreditScreen extends StatefulWidget {
  final int customerId;
  final String customerName;

  const CustomerCreditScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerCreditScreen> createState() => _CustomerCreditScreenState();
}

class _CustomerCreditScreenState extends State<CustomerCreditScreen> {
  final ApiService _apiService = ApiService();

  CreditStatement? _statement;
  bool _isLoading = false;
  String? _errorMessage;
  int? _selectedLocationId;

  String _startDate = DateFormat('yyyy-MM-dd').format(
    DateTime(DateTime.now().year, DateTime.now().month, 1),
  );
  String _endDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();

    // Initialize location provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      locationProvider.initialize(moduleId: 'sales').then((_) {
        if (mounted && locationProvider.selectedLocation != null) {
          setState(() {
            _selectedLocationId = locationProvider.selectedLocation!.locationId;
          });
        }
      });
    });

    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print('🔴 DEBUG: Loading statement for customer ${widget.customerId}');
    print('🔴 DEBUG: Date range: $_startDate to $_endDate');

    final response = await _apiService.getCreditStatement(
      widget.customerId,
      startDate: _startDate,
      endDate: _endDate,
    );

    print('🔴 DEBUG: Statement response success: ${response.isSuccess}');
    if (response.isSuccess && response.data != null) {
      print('🔴 DEBUG: Statement has ${response.data!.transactions.length} transactions');
      for (var t in response.data!.transactions) {
        print('🔴 DEBUG: Transaction from API - Date: ${t.date}, Credit: ${t.credit}, Debit: ${t.debit}, StockLocationId: ${t.stockLocationId}');
      }
    }

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
    // Get list of unpaid credit sales
    final creditSales = _statement?.transactions
        .where((t) => t.credit > 0 && t.saleId != null)
        .toList() ?? [];

    showDialog(
      context: context,
      builder: (context) => PaymentDialog(
        customerId: widget.customerId,
        customerName: widget.customerName,
        currentBalance: _statement?.currentBalance ?? 0,
        creditSales: creditSales,
        onPaymentComplete: () {
          Navigator.pop(context);
          _loadStatement();
        },
      ),
    );
  }

  void _showEditPaymentDialog(CreditTransaction transaction) {
    print('Edit button clicked - Transaction ID: ${transaction.id}');

    if (transaction.id == null) {
      print('ERROR: Transaction ID is null, cannot edit');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit: Transaction ID is missing')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => EditPaymentDialog(
        paymentId: transaction.id!,
        customerName: widget.customerName,
        currentAmount: transaction.debit,
        currentDescription: transaction.description ?? '',
        currentDate: transaction.date,
        currentLocationId: transaction.stockLocationId,
        onPaymentUpdated: () {
          Navigator.pop(context);
          _loadStatement();
        },
      ),
    );
  }

  Future<void> _deletePayment(CreditTransaction transaction) async {
    print('Delete button clicked - Transaction ID: ${transaction.id}');

    if (transaction.id == null) {
      print('ERROR: Transaction ID is null, cannot delete');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: Transaction ID is missing')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete this payment of ${NumberFormat('#,###').format(transaction.debit)} TSh?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final response = await _apiService.deleteCreditPayment(transaction.id!);

    setState(() => _isLoading = false);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Location selector
          Consumer<LocationProvider>(
            builder: (context, locationProvider, child) {
              if (locationProvider.allowedLocations.length > 1) {
                final selectedLocation = locationProvider.allowedLocations.firstWhere(
                  (loc) => loc.locationId == _selectedLocationId,
                  orElse: () => locationProvider.allowedLocations.first,
                );
                return PopupMenuButton<int>(
                  icon: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        selectedLocation.locationName,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  onSelected: (locationId) {
                    setState(() {
                      _selectedLocationId = locationId;
                      // List will be filtered automatically when rebuilt
                    });
                  },
                  itemBuilder: (context) {
                    return locationProvider.allowedLocations.map((location) {
                      return PopupMenuItem<int>(
                        value: location.locationId,
                        child: Row(
                          children: [
                            if (_selectedLocationId == location.locationId)
                              const Icon(Icons.check, size: 20),
                            if (_selectedLocationId == location.locationId)
                              const SizedBox(width: 8),
                            Text(location.locationName),
                          ],
                        ),
                      );
                    }).toList();
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Period: ${DateFormat('MMM d, y').format(DateTime.parse(_startDate))} - ${DateFormat('MMM d, y').format(DateTime.parse(_endDate))}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  onPressed: _loadStatement,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      floatingActionButton: PermissionFAB(
        permissionId: PermissionIds.customersAddPayment,
        onPressed: _showPaymentDialog,
        backgroundColor: AppColors.success,
        tooltip: 'Add Payment',
        child: const Icon(Icons.payment, color: Colors.white),
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
                  '${NumberFormat('#,###').format(_statement!.openingBalance)} TSh',
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
                  '${NumberFormat('#,###').format(_statement!.currentBalance)} TSh',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _statement!.currentBalance > 0
                        ? AppColors.error
                        : AppColors.success,
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
    print('🟢 DEBUG: Building transactions list');
    print('🟢 DEBUG: Total transactions: ${_statement!.transactions.length}');
    print('🟢 DEBUG: Selected location ID for filtering: $_selectedLocationId');

    // Filter out transactions where both credit and debit are 0
    var validTransactions = _statement!.transactions
        .where((t) => t.credit > 0 || t.debit > 0)
        .toList();

    print('🟢 DEBUG: Valid transactions (credit > 0 or debit > 0): ${validTransactions.length}');

    // Debug: Show all transaction stock_location_ids
    for (var t in validTransactions) {
      print('🟢 DEBUG: Transaction - Credit: ${t.credit}, Debit: ${t.debit}, StockLocationId: ${t.stockLocationId}');
    }

    // Filter by selected allowed location
    // Show transactions that match the selected location OR have no location assigned (null)
    if (_selectedLocationId != null) {
      validTransactions = validTransactions
          .where((t) => t.stockLocationId == _selectedLocationId || t.stockLocationId == null)
          .toList();
      print('🟢 DEBUG: After location filtering (including null): ${validTransactions.length} transactions');
    }

    // Sort by date (descending) - recent dates first
    validTransactions.sort((a, b) => b.date.compareTo(a.date));

    print('🟢 DEBUG: Final transaction count to display: ${validTransactions.length}');

    return ListView.builder(
      itemCount: validTransactions.length,
      itemBuilder: (context, index) {
        final transaction = validTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(CreditTransaction transaction) {
    final isCredit = transaction.credit > 0;
    final amount = isCredit ? transaction.credit : transaction.debit;
    final isPayment = !isCredit; // Payment transactions can be edited/deleted

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
            Expanded(
              child: Text(
                isCredit ? 'Credit Sale' : 'Payment',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
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
            if (transaction.saleId != null)
              Text('Sale ID: #${transaction.saleId}'),
            if (transaction.stockLocationId != null)
              Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  final location = locationProvider.allowedLocations.firstWhere(
                    (loc) => loc.locationId == transaction.stockLocationId,
                    orElse: () => StockLocation(
                      locationId: transaction.stockLocationId!,
                      locationName: 'Location ${transaction.stockLocationId}',
                    ),
                  );
                  return Text(
                    'Location: ${location.locationName}',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  );
                },
              ),
            Text(
              'Balance: ${NumberFormat('#,###').format(transaction.balance)} TSh',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isPayment) ...[
              const SizedBox(height: 8),
              Consumer<PermissionProvider>(
                builder: (context, permissionProvider, child) {
                  final hasEdit = permissionProvider.hasPermission(PermissionIds.creditsEdit);
                  final hasDelete = permissionProvider.hasPermission(PermissionIds.creditsDelete);

                  if (!hasEdit && !hasDelete) return const SizedBox.shrink();

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasEdit)
                        TextButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => _showEditPaymentDialog(transaction),
                        ),
                      if (hasDelete)
                        TextButton.icon(
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Delete'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => _deletePayment(transaction),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
        trailing: isCredit && transaction.saleId != null
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
      ),
    );

    // Make credit sales tappable to view details
    if (isCredit && transaction.saleId != null) {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SaleDetailsScreen(saleId: transaction.saleId!),
            ),
          );
        },
        child: card,
      );
    }

    return card;
  }
}

class PaymentDialog extends StatefulWidget {
  final int customerId;
  final String customerName;
  final double currentBalance;
  final List<CreditTransaction> creditSales;
  final VoidCallback onPaymentComplete;

  const PaymentDialog({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.currentBalance,
    required this.creditSales,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isSubmitting = false;
  int? _selectedSaleId;
  int? _selectedLocationId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Initialize location provider for all clients
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      locationProvider.initialize(moduleId: 'sales');
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Get location provider to access selected location
    final locationProvider = context.read<LocationProvider>();

    // Build description including selected sale if any
    String description = _descriptionController.text.trim();
    if (_selectedSaleId != null) {
      final saleNote = 'Payment for Sale #$_selectedSaleId';
      description = description.isEmpty
          ? saleNote
          : '$description - $saleNote';
    }

    // Ensure stock_location_id is always set (either from _selectedLocationId or default)
    final stockLocationId = _selectedLocationId ?? locationProvider.selectedLocation?.locationId;

    print('🔵 DEBUG: Submitting payment with stock_location_id: $stockLocationId');
    print('🔵 DEBUG: _selectedLocationId = $_selectedLocationId');
    print('🔵 DEBUG: locationProvider.selectedLocation?.locationId = ${locationProvider.selectedLocation?.locationId}');

    final formData = PaymentFormData(
      customerId: widget.customerId,
      amount: double.parse(_amountController.text),
      saleId: _selectedSaleId,
      stockLocationId: stockLocationId,
      description: description.isEmpty ? null : description,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
    );

    print('🔵 DEBUG: PaymentFormData JSON: ${formData.toJson()}');

    final response = await _apiService.addCreditPayment(formData);

    print('🔵 DEBUG: Response success: ${response.isSuccess}');
    print('🔵 DEBUG: Response data: ${response.data}');

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment added successfully')),
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
    return AlertDialog(
      title: const Text('Add Payment'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${widget.customerName}'),
              const SizedBox(height: 8),
              Text(
                'Current Balance: ${NumberFormat('#,###').format(widget.currentBalance)} TSh',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.currentBalance > 0
                      ? AppColors.error
                      : AppColors.success,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.creditSales.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  value: _selectedSaleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Credit Sale (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Choose a sale to pay against',
                  ),
                  items: widget.creditSales.map((sale) {
                    return DropdownMenuItem<int>(
                      value: sale.saleId,
                      child: Text(
                        'Sale #${sale.saleId} - ${NumberFormat('#,###').format(sale.credit)} TSh',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSaleId = value;
                      // Auto-populate location from the selected sale
                      if (value != null) {
                        final selectedSale = widget.creditSales.firstWhere(
                          (sale) => sale.saleId == value,
                        );
                        _selectedLocationId = selectedSale.stockLocationId;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              // Stock Location selector - for all clients
              Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  return Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedLocationId ?? locationProvider.selectedLocation?.locationId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Stock Location *',
                          border: const OutlineInputBorder(),
                          helperText: _selectedSaleId != null ? 'Location taken from selected sale' : null,
                        ),
                        items: locationProvider.allowedLocations.isEmpty
                            ? [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Loading locations...'),
                                )
                              ]
                            : locationProvider.allowedLocations.map((location) {
                                return DropdownMenuItem<int>(
                                  value: location.locationId,
                                  child: Text(
                                    location.locationName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                        onChanged: _selectedSaleId != null || locationProvider.allowedLocations.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedLocationId = value;
                                });
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a stock location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
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
                  if (double.parse(value) > widget.currentBalance) {
                    return 'Payment cannot exceed balance of ${NumberFormat('#,###').format(widget.currentBalance)} TSh';
                  }
                  return null;
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
              const SizedBox(height: 16),
              // Date field with permission
              Consumer<PermissionProvider>(
                builder: (context, permissionProvider, child) {
                  if (permissionProvider.hasPermission(PermissionIds.creditsDate)) {
                    return InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM d, y').format(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
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

class EditPaymentDialog extends StatefulWidget {
  final int paymentId;
  final String customerName;
  final double currentAmount;
  final String currentDescription;
  final String currentDate;
  final int? currentLocationId;
  final VoidCallback onPaymentUpdated;

  const EditPaymentDialog({
    super.key,
    required this.paymentId,
    required this.customerName,
    required this.currentAmount,
    required this.currentDescription,
    required this.currentDate,
    this.currentLocationId,
    required this.onPaymentUpdated,
  });

  @override
  State<EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<EditPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  bool _isSubmitting = false;
  late DateTime _selectedDate;
  int? _selectedLocationId;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.currentAmount.toString());
    _descriptionController = TextEditingController(text: widget.currentDescription);
    _selectedDate = DateTime.parse(widget.currentDate);
    _selectedLocationId = widget.currentLocationId;

    // Initialize location provider for all clients
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      locationProvider.initialize(moduleId: 'sales');
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Get location provider to access selected location
    final locationProvider = context.read<LocationProvider>();

    // Build update data with only changed fields
    final updateData = <String, dynamic>{};

    final newAmount = double.parse(_amountController.text);
    if (newAmount != widget.currentAmount) {
      updateData['amount'] = newAmount;
    }

    final newDescription = _descriptionController.text.trim();
    if (newDescription != widget.currentDescription) {
      updateData['description'] = newDescription;
    }

    final newDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    if (newDate != widget.currentDate) {
      updateData['date'] = newDate;
    }

    // Ensure we use either _selectedLocationId or fallback to provider's selected location
    final stockLocationId = _selectedLocationId ?? locationProvider.selectedLocation?.locationId;
    if (stockLocationId != widget.currentLocationId) {
      updateData['stock_location_id'] = stockLocationId;
    }

    if (updateData.isEmpty) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to save')),
        );
      }
      return;
    }

    final response = await _apiService.updateCreditPayment(
      widget.paymentId,
      updateData,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment updated successfully')),
        );
        widget.onPaymentUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Payment'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${widget.customerName}'),
              const SizedBox(height: 16),
              // Stock Location selector - for all clients
              Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  return Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedLocationId ?? locationProvider.selectedLocation?.locationId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Stock Location *',
                          border: OutlineInputBorder(),
                        ),
                        items: locationProvider.allowedLocations.isEmpty
                            ? [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Loading locations...'),
                                )
                              ]
                            : locationProvider.allowedLocations.map((location) {
                                return DropdownMenuItem<int>(
                                  value: location.locationId,
                                  child: Text(
                                    location.locationName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                        onChanged: locationProvider.allowedLocations.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedLocationId = value;
                                });
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a stock location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
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
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Date field with permission
              Consumer<PermissionProvider>(
                builder: (context, permissionProvider, child) {
                  if (permissionProvider.hasPermission(PermissionIds.creditsDate)) {
                    return InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM d, y').format(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
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
          onPressed: _isSubmitting ? null : _submitUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
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
              : const Text('Update Payment'),
        ),
      ],
    );
  }
}
