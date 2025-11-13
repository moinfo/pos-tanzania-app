import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/expense.dart';
import '../models/supervisor.dart';
import '../models/permission_model.dart';
import '../models/stock_location.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/permission_wrapper.dart';
import '../widgets/glassmorphic_card.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/permission_provider.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<Expense> _expenses = [];
  List<ExpenseCategory> _categories = [];

  // Date range state - default to today
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    // Defer location initialization until after build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.initialize(moduleId: 'sales');
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    try {
      final locationProvider = context.read<LocationProvider>();
      final selectedLocationId = locationProvider.selectedLocation?.locationId;

      final response = await _apiService.getExpenses(
        startDate: startDateStr,
        endDate: endDateStr,
        locationId: selectedLocationId,
      );

      if (response.isSuccess) {
        setState(() {
          _expenses = response.data ?? [];
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
        _error = 'Failed to load expenses';
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
      _loadExpenses();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _apiService.getExpenseCategories();
      if (response.isSuccess) {
        setState(() {
          _categories = response.data ?? [];
        });
      }
    } catch (e) {
      // Silently fail, categories are optional
    }
  }

  Future<void> _deleteExpense(int expenseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
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
      final response = await _apiService.deleteExpense(expenseId);

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadExpenses();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to delete expense'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (context) => ExpenseFormDialog(
        categories: _categories,
        onSaved: () {
          Navigator.pop(context);
          _loadExpenses();
        },
      ),
    );
  }

  void _showEditExpenseDialog(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => ExpenseFormDialog(
        expense: expense,
        categories: _categories,
        onSaved: () {
          Navigator.pop(context);
          _loadExpenses();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final locationProvider = context.watch<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;
    final locations = locationProvider.allowedLocations;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Expenses'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Location selector with proper menu positioning
          if (locations.isNotEmpty)
            PopupMenuButton<int>(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    selectedLocation?.locationName ?? 'Location',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
              color: isDark ? AppColors.darkCard : Colors.white,
              offset: const Offset(0, 50),
              onSelected: (locationId) {
                final location = locations.firstWhere((loc) => loc.locationId == locationId);
                locationProvider.selectLocation(location);
                _loadExpenses();
              },
              itemBuilder: (context) {
                return locations.map((location) {
                  return PopupMenuItem<int>(
                    value: location.locationId,
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 18,
                          color: selectedLocation?.locationId == location.locationId
                              ? AppColors.primary
                              : (isDark ? Colors.white70 : AppColors.textLight),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          location.locationName,
                          style: TextStyle(
                            color: selectedLocation?.locationId == location.locationId
                                ? AppColors.primary
                                : (isDark ? Colors.white : AppColors.text),
                            fontWeight: selectedLocation?.locationId == location.locationId
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
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
            color: isDark
                ? AppColors.darkSurface
                : AppColors.primary.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _startDate == _endDate
                      ? DateFormat('MMMM dd, yyyy').format(_startDate)
                      : '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.text,
                  ),
                ),
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Content with gradient background
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.darkBackground, AppColors.darkSurface]
                      : [AppColors.lightBackground, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: RefreshIndicator(
                onRefresh: _loadExpenses,
                child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadExpenses,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No expenses found',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textLight,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _showAddExpenseDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Expense'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _expenses.length,
                        itemBuilder: (context, index) {
                          final expense = _expenses[index];
                          return _buildExpenseCard(expense);
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _expenses.isNotEmpty
          ? PermissionFAB(
              permissionId: PermissionIds.expensesAdd,
              onPressed: _showAddExpenseDialog,
              tooltip: 'Add Expense',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      // Bottom navigation is now handled by MainNavigation
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final permissionProvider = context.read<PermissionProvider>();
    final hasEditPermission = permissionProvider.hasPermission(PermissionIds.expensesEdit);
    final hasDeletePermission = permissionProvider.hasPermission(PermissionIds.expensesDelete);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        isDark: isDark,
        child: InkWell(
        onTap: hasEditPermission ? () => _showEditExpenseDialog(expense) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category icon with gradient background
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.error.withOpacity(0.8),
                          AppColors.error,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.category?.name ?? 'Uncategorized',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              Formatters.formatDate(expense.date),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Amount with emphasis
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      Formatters.formatCurrency(expense.totalAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
              if (expense.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBackground.withOpacity(0.5)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notes,
                        size: 16,
                        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          expense.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.payment,
                    label: expense.paymentType,
                    color: _getPaymentTypeColor(expense.paymentType),
                    isDark: isDark,
                  ),
                  if (expense.supervisor != null) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.person,
                      label: expense.supervisor!.name,
                      color: AppColors.info,
                      isDark: isDark,
                    ),
                  ],
                  const Spacer(),
                  // Delete button with permission check
                  if (hasDeletePermission)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                        onPressed: () => _deleteExpense(expense.expenseId),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        tooltip: 'Delete expense',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPaymentTypeColor(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'credit':
      case 'debit':
        return AppColors.primary;
      case 'check':
        return AppColors.warning;
      case 'due':
        return AppColors.error;
      default:
        return AppColors.textLight;
    }
  }
}

// Expense Form Dialog
class ExpenseFormDialog extends StatefulWidget {
  final Expense? expense;
  final List<ExpenseCategory> categories;
  final VoidCallback onSaved;

  const ExpenseFormDialog({
    super.key,
    this.expense,
    required this.categories,
    required this.onSaved,
  });

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _amountController = TextEditingController();
  final _taxAmountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _taxCodeController = TextEditingController();

  TabController? _tabController;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  String _selectedPaymentType = 'Cash';
  int? _selectedCategoryId;
  String? _selectedSupervisorId;
  List<Supervisor> _supervisors = [];

  final List<String> _paymentTypes = ['Cash', 'Due', 'Check', 'Credit', 'Debit'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSupervisors();

    if (widget.expense != null) {
      _amountController.text = widget.expense!.amount.toString();
      _taxAmountController.text = widget.expense!.taxAmount.toString();
      _descriptionController.text = widget.expense!.description;
      _taxCodeController.text = widget.expense!.supplierTaxCode ?? '';
      _selectedDate = DateTime.parse(widget.expense!.date);
      _selectedPaymentType = widget.expense!.paymentType;
      _selectedCategoryId = widget.expense!.category?.id;
      _selectedSupervisorId = widget.expense!.supervisor?.id.toString();
    } else {
      // Set first category as default for new expenses
      if (widget.categories.isNotEmpty) {
        _selectedCategoryId = widget.categories.first.id;
      }
    }
  }

  Future<void> _loadSupervisors() async {
    try {
      final response = await _apiService.getSupervisors();
      if (response.isSuccess && mounted) {
        setState(() {
          _supervisors = (response.data as List<Supervisor>?) ?? [];
          // Set first supervisor as default if not editing and supervisors exist
          if (widget.expense == null && _supervisors.isNotEmpty && _selectedSupervisorId == null) {
            _selectedSupervisorId = _supervisors.first.id;
          }
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _amountController.dispose();
    _taxAmountController.dispose();
    _descriptionController.dispose();
    _taxCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final locationProvider = context.read<LocationProvider>();
      final selectedLocationId = locationProvider.selectedLocation?.locationId ?? 1;

      final formData = ExpenseFormData(
        date: Formatters.formatDateForApi(_selectedDate),
        amount: double.parse(_amountController.text),
        paymentType: _selectedPaymentType,
        description: _descriptionController.text,
        categoryId: _selectedCategoryId,
        supervisorId: _selectedSupervisorId != null ? int.tryParse(_selectedSupervisorId!) : null,
        taxAmount: _taxAmountController.text.isNotEmpty
            ? double.parse(_taxAmountController.text)
            : 0,
        supplierTaxCode: _taxCodeController.text.isNotEmpty ? _taxCodeController.text : null,
        stockLocationId: selectedLocationId, // Use selected location
      );

      final response = widget.expense == null
          ? await _apiService.createExpense(formData)
          : await _apiService.updateExpense(widget.expense!.expenseId, formData);

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.expense == null
                  ? 'Expense created successfully'
                  : 'Expense updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          widget.onSaved();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to save expense'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final permissionProvider = context.read<PermissionProvider>();
    final hasDatePermission = permissionProvider.hasPermission(PermissionIds.expensesDate);

    if (!hasDatePermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to change the date'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissionProvider = context.watch<PermissionProvider>();
    final hasDatePermission = permissionProvider.hasPermission(PermissionIds.expensesDate);
    final locationProvider = context.watch<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              widget.expense == null ? 'Add Expense' : 'Edit Expense',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.text,
              ),
            ),
          ),

          // Tabs
          if (_tabController != null)
            TabBar(
              controller: _tabController!,
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? Colors.white60 : AppColors.textLight,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Basic Info'),
                Tab(text: 'Additional'),
              ],
            ),

          // Tab Content
          if (_tabController != null)
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: SizedBox(
                      height: 500,
                      child: TabBarView(
                        controller: _tabController!,
                        children: [
                          _buildBasicInfoTab(isDark, hasDatePermission, selectedLocation),
                          _buildAdditionalTab(isDark),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Buttons
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveExpense,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.expense == null ? 'Add' : 'Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab(bool isDark, bool hasDatePermission, StockLocation? selectedLocation) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

                // Stock Location Display
                if (selectedLocation != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withOpacity(0.2)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Location: ${selectedLocation.locationName}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Date
                InkWell(
                  onTap: hasDatePermission ? _selectDate : null,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : null,
                      ),
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: hasDatePermission
                            ? (isDark ? Colors.white70 : null)
                            : AppColors.textLight,
                      ),
                      suffixIcon: !hasDatePermission
                          ? const Icon(Icons.lock, size: 16, color: AppColors.warning)
                          : null,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    child: Text(
                      Formatters.formatDate(_selectedDate.toString()),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.text,
                      ),
                    ),
                  ),
                ),
                if (!hasDatePermission) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'You do not have permission to change the date',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                    prefixIcon: Icon(Icons.money, color: isDark ? Colors.white70 : null),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category (Required)
                if (widget.categories.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: _selectedCategoryId,
                    dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                      prefixIcon: Icon(Icons.category, color: isDark ? Colors.white70 : null),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    items: widget.categories.map((category) {
                      return DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a category';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                    prefixIcon: Icon(Icons.description, color: isDark ? Colors.white70 : null),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          );
        }

        Widget _buildAdditionalTab(bool isDark) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Payment Type
              DropdownButtonFormField<String>(
                value: _selectedPaymentType,
                dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Payment Type',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                  prefixIcon: Icon(Icons.payment, color: isDark ? Colors.white70 : null),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                ),
                items: _paymentTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Supervisor
              if (_supervisors.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedSupervisorId,
                  dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                  decoration: InputDecoration(
                    labelText: 'Supervisor',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                    prefixIcon: Icon(Icons.person, color: isDark ? Colors.white70 : null),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  items: _supervisors.map((supervisor) {
                    return DropdownMenuItem(
                      value: supervisor.id,
                      child: Text(supervisor.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSupervisorId = value;
                    });
                  },
                ),
              const SizedBox(height: 16),

              // Tax Amount
              TextFormField(
                controller: _taxAmountController,
                style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Tax Amount (Optional)',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                  prefixIcon: Icon(Icons.attach_money, color: isDark ? Colors.white70 : null),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        );
      }
}
