import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/permission_model.dart';
import '../models/supplier.dart';
import '../providers/permission_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/permission_wrapper.dart';
import 'supplier_credit_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Supplier> _suppliers = [];
  List<Supplier> _filteredSuppliers = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _searchController.addListener(_filterSuppliers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getSuppliers();

    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _suppliers = response.data ?? [];
        _filteredSuppliers = _suppliers;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  void _filterSuppliers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSuppliers = _suppliers;
      } else {
        _filteredSuppliers = _suppliers.where((supplier) {
          return supplier.displayName.toLowerCase().contains(query) ||
              supplier.companyName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _showSupplierForm({Supplier? supplier}) {
    showDialog(
      context: context,
      builder: (context) => _SupplierFormDialog(supplier: supplier),
    ).then((result) {
      if (result == true) {
        _loadSuppliers();
      }
    });
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Are you sure you want to delete "${supplier.displayName}"?'),
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
      final response = await _apiService.deleteSupplier(supplier.supplierId);
      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supplier deleted successfully')),
          );
          _loadSuppliers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.message}')),
          );
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
        title: const Text('Suppliers'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search suppliers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
              ),
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
                                style: TextStyle(color: isDark ? AppColors.darkText : AppColors.error)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadSuppliers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredSuppliers.isEmpty
                        ? Center(child: Text('No suppliers found', style: TextStyle(color: isDark ? AppColors.darkText : AppColors.text)))
                        : ListView.builder(
                            itemCount: _filteredSuppliers.length,
                            itemBuilder: (context, index) {
                              final supplier = _filteredSuppliers[index];
                              return _buildSupplierCard(supplier, isDark);
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
      floatingActionButton: Consumer<PermissionProvider>(
        builder: (context, permissionProvider, child) {
          final canAdd = permissionProvider.hasPermission(PermissionIds.suppliersAdd);

          if (!canAdd) return const SizedBox.shrink();

          return FloatingActionButton(
            onPressed: () => _showSupplierForm(),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }

  Widget _buildSupplierCard(Supplier supplier, bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                      if (supplier.companyName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          supplier.companyName,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: supplier.balance > 0
                            ? AppColors.error.withOpacity(0.1)
                            : (isDark ? AppColors.darkCard : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        supplier.balance > 0 ? 'OWING' : 'PAID',
                        style: TextStyle(
                          color: supplier.balance > 0
                              ? AppColors.error
                              : (isDark ? AppColors.darkTextLight : Colors.grey[700]),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer<PermissionProvider>(
                      builder: (context, permissionProvider, child) {
                        final hasEdit = permissionProvider.hasPermission(PermissionIds.suppliersEdit);
                        final hasDelete = permissionProvider.hasPermission(PermissionIds.suppliersDelete);

                        if (!hasEdit && !hasDelete) return const SizedBox.shrink();

                        return PopupMenuButton(
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
                              _showSupplierForm(supplier: supplier);
                            } else if (value == 'delete') {
                              _deleteSupplier(supplier);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Balance:',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '${NumberFormat('#,###').format(supplier.balance)} TSh',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: supplier.balance > 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Consumer<PermissionProvider>(
              builder: (context, permissionProvider, child) {
                final canViewCredit = permissionProvider.hasPermission(PermissionIds.suppliersCreditorsView);

                if (!canViewCredit) return const SizedBox.shrink();

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.account_balance, size: 16),
                      label: const Text('View Credit Account'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupplierCreditScreen(
                              supplierId: supplier.supplierId,
                              supplierName: supplier.displayName,
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierFormDialog extends StatefulWidget {
  final Supplier? supplier;

  const _SupplierFormDialog({this.supplier});

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Form controllers
  final _companyNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _countryController = TextEditingController();
  final _commentsController = TextEditingController();
  final _agencyNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _taxIdController = TextEditingController();

  String? _selectedGender;
  int? _selectedSupervisorId;
  int _selectedCategory = 0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _supervisors = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSupervisors();

    if (widget.supplier != null) {
      _populateForm(widget.supplier!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _commentsController.dispose();
    _agencyNameController.dispose();
    _accountNumberController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  void _populateForm(Supplier supplier) {
    _companyNameController.text = supplier.companyName;
    _firstNameController.text = supplier.firstName;
    _lastNameController.text = supplier.lastName;
    _emailController.text = supplier.email ?? '';
    _phoneController.text = supplier.phoneNumber ?? '';
    _address1Controller.text = supplier.address1 ?? '';
    _address2Controller.text = supplier.address2 ?? '';
    _cityController.text = supplier.city ?? '';
    _stateController.text = supplier.state ?? '';
    _zipController.text = supplier.zip ?? '';
    _countryController.text = supplier.country ?? '';
    _commentsController.text = supplier.comments ?? '';
    _agencyNameController.text = supplier.agencyName ?? '';
    _accountNumberController.text = supplier.accountNumber ?? '';
    _taxIdController.text = supplier.taxId ?? '';
    _selectedGender = supplier.gender;
    _selectedSupervisorId = supplier.supervisorId;
    _selectedCategory = supplier.category;
  }

  Future<void> _loadSupervisors() async {
    final response = await _apiService.getSupplierSupervisors();
    if (response.isSuccess && mounted) {
      setState(() {
        _supervisors = response.data ?? [];
      });
    }
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final supplierData = {
      'company_name': _companyNameController.text,
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'gender': _selectedGender,
      'email': _emailController.text,
      'phone_number': _phoneController.text,
      'address_1': _address1Controller.text,
      'address_2': _address2Controller.text,
      'city': _cityController.text,
      'state': _stateController.text,
      'zip': _zipController.text,
      'country': _countryController.text,
      'comments': _commentsController.text,
      'agency_name': _agencyNameController.text,
      'account_number': _accountNumberController.text,
      'tax_id': _taxIdController.text,
      'category': _selectedCategory,
      'supervisor_id': _selectedSupervisorId,
    };

    final response = widget.supplier == null
        ? await _apiService.createSupplier(supplierData)
        : await _apiService.updateSupplier(widget.supplier!.supplierId, supplierData);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.supplier == null
                ? 'Supplier created successfully'
                : 'Supplier updated successfully'),
          ),
        );
        Navigator.pop(context, true);
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

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.supplier == null ? 'Add Supplier' : 'Edit Supplier',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: isDark ? AppColors.darkText : AppColors.primary,
              unselectedLabelColor: isDark ? AppColors.darkTextLight : Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Basic Info'),
                Tab(text: 'Contact'),
                Tab(text: 'Other'),
              ],
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicInfoTab(isDark),
                    _buildContactTab(isDark),
                    _buildOtherTab(isDark),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.grey[100],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: isDark ? AppColors.darkTextLight : Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveSupplier,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
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
    );
  }

  Widget _buildBasicInfoTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _companyNameController,
            decoration: InputDecoration(
              labelText: 'Company Name *',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Company name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: 'First Name *',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'First name is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name *',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Last name is required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              labelText: 'Gender',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'Category',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Goods Supplier')),
              DropdownMenuItem(value: 1, child: Text('Cost Supplier')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value ?? 0;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedSupervisorId,
            decoration: InputDecoration(
              labelText: 'Supervisor',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              ..._supervisors.map((supervisor) {
                return DropdownMenuItem(
                  value: supervisor['id'] as int,
                  child: Text(supervisor['name'] as String),
                );
              }).toList(),
            ],
            onChanged: (value) {
              setState(() {
                _selectedSupervisorId = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!value.contains('@')) {
                  return 'Invalid email address';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _address1Controller,
            decoration: InputDecoration(
              labelText: 'Address Line 1',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _address2Controller,
            decoration: InputDecoration(
              labelText: 'Address Line 2',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: 'City',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: InputDecoration(
                    labelText: 'State',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _zipController,
                  decoration: InputDecoration(
                    labelText: 'ZIP Code',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countryController,
            decoration: InputDecoration(
              labelText: 'Country',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _agencyNameController,
            decoration: InputDecoration(
              labelText: 'Agency Name',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _accountNumberController,
            decoration: InputDecoration(
              labelText: 'Account Number',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _taxIdController,
            decoration: InputDecoration(
              labelText: 'Tax ID',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _commentsController,
            decoration: InputDecoration(
              labelText: 'Comments',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey[200],
            ),
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}
