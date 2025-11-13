import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/customer.dart';
import '../models/supervisor.dart';
import '../models/permission_model.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/permission_wrapper.dart';
import '../utils/constants.dart';
import 'customer_credit_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final ApiService _apiService = ApiService();
  List<Customer> _customers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getCustomers(
      search: _searchQuery.isEmpty ? null : _searchQuery,
      limit: 100,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess) {
          _customers = response.data!;
        } else {
          _errorMessage = response.message;
        }
      });
    }
  }

  void _showCustomerForm({Customer? customer}) {
    showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(
        customer: customer,
        onSaved: () {
          Navigator.pop(context);
          _loadCustomers();
        },
      ),
    );
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete "${customer.displayName}"?'),
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
      final response = await _apiService.deleteCustomer(customer.personId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ??
              (response.isSuccess ? 'Customer deleted successfully' : 'Failed to delete customer')),
            backgroundColor: response.isSuccess ? AppColors.success : AppColors.error,
          ),
        );

        if (response.isSuccess) {
          _loadCustomers();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _loadCustomers();
              },
            ),
          ),
          // Customers list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(_errorMessage!,
                              style: TextStyle(
                                color: isDark ? AppColors.darkText : AppColors.text,
                              )),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadCustomers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _customers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: isDark ? AppColors.darkTextLight : Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No customers found'
                                      : 'No customers match your search',
                                  style: TextStyle(fontSize: 16, color: isDark ? AppColors.darkText : Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadCustomers,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _customers.length,
                              itemBuilder: (context, index) {
                                return _buildCustomerCard(_customers[index], isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: PermissionFAB(
        permissionId: PermissionIds.customersAdd,
        onPressed: () => _showCustomerForm(),
        tooltip: 'Add Customer',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildCustomerCard(Customer customer, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      customer.firstName.isNotEmpty ? customer.firstName[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        if (customer.accountNumber != null && customer.accountNumber!.isNotEmpty)
                          Text(
                            'Account: ${customer.accountNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (customer.supervisor != null)
                    Chip(
                      label: Text(
                        customer.supervisor!.name,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              if (customer.phoneNumber.isNotEmpty || customer.email.isNotEmpty)
                const SizedBox(height: 8),
              if (customer.phoneNumber.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: isDark ? AppColors.darkTextLight : AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      customer.phoneNumber,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              if (customer.email.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.email, size: 14, color: isDark ? AppColors.darkTextLight : AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      customer.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card, size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Credit: ${NumberFormat('#,###').format(customer.creditLimit)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 14,
                          color: customer.balance >= 0 ? AppColors.error : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Balance: ${NumberFormat('#,###').format(customer.balance)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: customer.balance >= 0 ? AppColors.error : AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Edit and Delete buttons with permissions
                  Row(
                    children: [
                      PermissionIconButton(
                        permissionId: PermissionIds.customersEdit,
                        onPressed: () => _showCustomerForm(customer: customer),
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Edit Customer',
                        color: AppColors.primary,
                        showDisabled: false,
                      ),
                      const SizedBox(width: 8),
                      PermissionIconButton(
                        permissionId: PermissionIds.customersDelete,
                        onPressed: () => _deleteCustomer(customer),
                        icon: const Icon(Icons.delete, size: 18),
                        tooltip: 'Delete Customer',
                        color: AppColors.error,
                        showDisabled: false,
                      ),
                    ],
                  ),
                  // Add Payment button
                  PermissionWrapper(
                    permissionId: PermissionIds.customersAddPayment,
                    child: TextButton.icon(
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Add Payment'),
                      onPressed: () {
                        // TODO: Navigate to Add Payment screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add Payment feature coming soon'),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.success,
                      ),
                    ),
                  ),
                  // View Credit Account button
                  PermissionWrapper(
                    permissionId: PermissionIds.customersViewCredit,
                    child: TextButton.icon(
                      icon: const Icon(Icons.account_balance, size: 16),
                      label: const Text('View Credit'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerCreditScreen(
                              customerId: customer.personId,
                              customerName: customer.displayName,
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ),
    );
  }
}

class CustomerFormDialog extends StatefulWidget {
  final Customer? customer;
  final VoidCallback onSaved;

  const CustomerFormDialog({
    super.key,
    this.customer,
    required this.onSaved,
  });

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _accountNumberController;
  late TextEditingController _companyNameController;
  late TextEditingController _creditLimitController;
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _cityController;
  late TextEditingController _countyController;
  late TextEditingController _postCodeController;
  late TextEditingController _countryController;
  late TextEditingController _commentsController;
  late TextEditingController _oneTimeCreditLimitController;
  late TextEditingController _discountController;
  late TextEditingController _dueDateDaysController;
  late TextEditingController _badDebtorDaysController;
  late TextEditingController _taxIdController;

  List<Supervisor> _supervisors = [];
  String? _selectedSupervisorId;
  bool _isLoading = false;
  bool _isAllowedCredit = false;
  bool _registrationConsent = true;
  String _gender = 'M';
  bool _isBodaBoda = false;
  String _discountType = 'percentage';
  bool _oneTimeCredit = false;
  String _dormantStatus = 'active';
  bool _taxable = true;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.customer?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.customer?.lastName ?? '');
    _emailController = TextEditingController(text: widget.customer?.email ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phoneNumber ?? '');
    _accountNumberController = TextEditingController(text: widget.customer?.accountNumber ?? '');
    _companyNameController = TextEditingController(text: widget.customer?.companyName ?? '');
    _creditLimitController = TextEditingController(
      text: widget.customer?.creditLimit.toString() ?? '0',
    );
    _address1Controller = TextEditingController(text: widget.customer?.address1 ?? '');
    _address2Controller = TextEditingController(text: widget.customer?.address2 ?? '');
    _cityController = TextEditingController(text: widget.customer?.city ?? '');
    _countyController = TextEditingController(text: widget.customer?.state ?? '');
    _postCodeController = TextEditingController(text: widget.customer?.zip ?? '');
    _countryController = TextEditingController(text: widget.customer?.country ?? '');
    _commentsController = TextEditingController(text: widget.customer?.comments ?? '');
    _oneTimeCreditLimitController = TextEditingController(text: '0');
    _discountController = TextEditingController(text: '0');
    _dueDateDaysController = TextEditingController(text: '0');
    _badDebtorDaysController = TextEditingController(text: '0');
    _taxIdController = TextEditingController(text: widget.customer?.taxId ?? '');

    _isAllowedCredit = widget.customer?.isAllowedCredit ?? false;
    _selectedSupervisorId = widget.customer?.supervisor?.id.toString();
    _taxable = widget.customer?.taxable ?? true;

    _loadSupervisors();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _accountNumberController.dispose();
    _companyNameController.dispose();
    _creditLimitController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _countyController.dispose();
    _postCodeController.dispose();
    _countryController.dispose();
    _commentsController.dispose();
    _oneTimeCreditLimitController.dispose();
    _discountController.dispose();
    _dueDateDaysController.dispose();
    _badDebtorDaysController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSupervisors() async {
    final response = await _apiService.getSupervisors();
    if (response.isSuccess && mounted) {
      setState(() {
        _supervisors = response.data!;
        if (_selectedSupervisorId == null && _supervisors.isNotEmpty) {
          _selectedSupervisorId = _supervisors.first.id;
        }
      });
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final formData = CustomerFormData(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      accountNumber: _accountNumberController.text.trim().isEmpty ? null : _accountNumberController.text.trim(),
      companyName: _companyNameController.text.trim().isEmpty ? null : _companyNameController.text.trim(),
      creditLimit: double.tryParse(_creditLimitController.text) ?? 0,
      oneTimeCreditLimit: double.tryParse(_oneTimeCreditLimitController.text) ?? 0,
      address1: _address1Controller.text.trim().isEmpty ? null : _address1Controller.text.trim(),
      address2: _address2Controller.text.trim().isEmpty ? null : _address2Controller.text.trim(),
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      state: _countyController.text.trim().isEmpty ? null : _countyController.text.trim(),
      zip: _postCodeController.text.trim().isEmpty ? null : _postCodeController.text.trim(),
      country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
      comments: _commentsController.text.trim().isEmpty ? null : _commentsController.text.trim(),
      gender: _gender == 'M' ? 1 : _gender == 'F' ? 0 : null,
      discount: double.tryParse(_discountController.text) ?? 0,
      discountType: _discountType == 'percentage' ? 0 : 1,
      taxable: _taxable,
      taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
      dueDate: int.tryParse(_dueDateDaysController.text) ?? 7,
      badDebtor: int.tryParse(_badDebtorDaysController.text) ?? 30,
      supervisorId: _selectedSupervisorId,
      isAllowedCredit: _isAllowedCredit,
      isBodaBoda: _isBodaBoda,
      consent: _registrationConsent,
    );

    final response = widget.customer == null
        ? await _apiService.createCustomer(formData)
        : await _apiService.updateCustomer(widget.customer!.personId, formData);

    if (mounted) {
      setState(() => _isLoading = false);

      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Customer saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Failed to save customer'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      widget.customer == null ? 'Add Customer' : 'Edit Customer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Tabs
              Container(
                color: AppColors.primary,
                child: const TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.person),
                      text: 'Basic Info',
                    ),
                    Tab(
                      icon: Icon(Icons.settings),
                      text: 'Additional Details',
                    ),
                  ],
                ),
              ),
              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: TabBarView(
                    children: [
                      _buildBasicInfoTab(),
                      _buildAdditionalDetailsTab(),
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveCustomer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Basic Info Tab - Essential customer information ONLY
  Widget _buildBasicInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // First Name and Last Name
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Gender
        Row(
          children: [
            const Text('Gender:', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 16),
            Radio<String>(
              value: 'M',
              groupValue: _gender,
              onChanged: (value) {
                setState(() => _gender = value!);
              },
            ),
            const Text('Male'),
            const SizedBox(width: 16),
            Radio<String>(
              value: 'F',
              groupValue: _gender,
              onChanged: (value) {
                setState(() => _gender = value!);
              },
            ),
            const Text('Female'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _creditLimitController,
          decoration: const InputDecoration(
            labelText: 'Credit Limit',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.credit_card),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Allow Credit'),
          subtitle: const Text('Enable credit facility for this customer'),
          value: _isAllowedCredit,
          onChanged: (value) {
            setState(() => _isAllowedCredit = value);
          },
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedSupervisorId,
          decoration: const InputDecoration(
            labelText: 'Supervisor Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: _supervisors.map((supervisor) {
            return DropdownMenuItem(
              value: supervisor.id,
              child: Text(supervisor.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedSupervisorId = value);
          },
        ),
      ],
    );
  }

  // Additional Details Tab - Advanced/Optional fields ONLY
  Widget _buildAdditionalDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Registration Consent
        CheckboxListTile(
          title: const Text('Registration Consent'),
          value: _registrationConsent,
          onChanged: (value) {
            setState(() => _registrationConsent = value ?? true);
          },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyNameController,
          decoration: const InputDecoration(
            labelText: 'Company',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _accountNumberController,
          decoration: const InputDecoration(
            labelText: 'Account #',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _address1Controller,
          decoration: const InputDecoration(
            labelText: 'Address 1',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _address2Controller,
          decoration: const InputDecoration(
            labelText: 'Address 2',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cityController,
          decoration: const InputDecoration(
            labelText: 'City',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _countyController,
          decoration: const InputDecoration(
            labelText: 'County',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _postCodeController,
          decoration: const InputDecoration(
            labelText: 'Post Code',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _countryController,
          decoration: const InputDecoration(
            labelText: 'Country',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _oneTimeCreditLimitController,
          decoration: const InputDecoration(
            labelText: 'One Time Credit Limit',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.credit_card),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('Is Boda Boda'),
          value: _isBodaBoda,
          onChanged: (value) {
            setState(() => _isBodaBoda = value ?? false);
          },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        // Discount Type
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Discount Type:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Radio<String>(
                  value: 'percentage',
                  groupValue: _discountType,
                  onChanged: (value) {
                    setState(() => _discountType = value!);
                  },
                ),
                const Text('Percentage'),
                const SizedBox(width: 16),
                Radio<String>(
                  value: 'fixed',
                  groupValue: _discountType,
                  onChanged: (value) {
                    setState(() => _discountType = value!);
                  },
                ),
                const Text('Fixed'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _discountController,
          decoration: const InputDecoration(
            labelText: 'Discount',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.percent),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _dueDateDaysController,
          decoration: const InputDecoration(
            labelText: 'Due Date Days',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_today),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _badDebtorDaysController,
          decoration: const InputDecoration(
            labelText: 'Bad Debtor Days',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.warning),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _dormantStatus,
          decoration: const InputDecoration(
            labelText: 'Dormant Status',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'active', child: Text('ACTIVE')),
            DropdownMenuItem(value: 'dormant', child: Text('DORMANT')),
            DropdownMenuItem(value: 'inactive', child: Text('INACTIVE')),
          ],
          onChanged: (value) {
            setState(() => _dormantStatus = value!);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _taxIdController,
          decoration: const InputDecoration(
            labelText: 'Tax ID',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('Taxable'),
          subtitle: const Text('Apply tax to this customer'),
          value: _taxable,
          onChanged: (value) {
            setState(() => _taxable = value ?? true);
          },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _commentsController,
          decoration: const InputDecoration(
            labelText: 'Comments',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }
}
