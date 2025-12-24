import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../models/customer.dart';
import '../models/supervisor.dart';
import '../models/permission_model.dart';
import '../models/stock_location.dart';
import '../models/nfc_wallet.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/permission_provider.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/permission_wrapper.dart';
import '../widgets/nfc_scan_dialog.dart';
import '../utils/constants.dart';
import 'customer_credit_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final ApiService _apiService = ApiService();
  final NfcService _nfcService = NfcService();
  List<Customer> _customers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  bool _nfcAvailable = false;

  // Track which customers have NFC cards linked
  Map<int, String> _customerNfcCards = {}; // customerId -> cardUid

  @override
  void initState() {
    super.initState();
    // Initialize location after build is complete (Leruma only)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
    _loadCustomers();
    _checkNfcAvailability();
    _loadCustomerNfcCards();
  }

  Future<void> _loadCustomerNfcCards() async {
    final response = await _apiService.getAllCustomerCards();
    if (response.isSuccess && response.data != null) {
      final cards = response.data!;
      if (mounted) {
        setState(() {
          _customerNfcCards = {
            for (var card in cards.where((c) => c.isActive))
              card.customerId: card.cardUid
          };
        });
      }
    }
  }

  Future<void> _checkNfcAvailability() async {
    final isAvailable = await _nfcService.isNfcAvailable();
    if (mounted) {
      setState(() => _nfcAvailable = isAvailable);
    }
  }

  Future<void> _registerCardToCustomer(Customer customer) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NfcRegisterCardDialog(customer: customer),
    );

    if (result == true && mounted) {
      // Refresh NFC cards list
      _loadCustomerNfcCards();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.nfc, color: Colors.white),
              const SizedBox(width: 8),
              Text('Card registered to ${customer.firstName}'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _viewCustomerNfcCard(Customer customer) async {
    final cardUid = _customerNfcCards[customer.personId];
    if (cardUid == null) return;

    // Fetch card balance info
    final response = await _apiService.getNfcCardBalance(cardUid);

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final balance = response.data!;
      final currencyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.nfc, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('NFC Card Details'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardDetailRow('Customer', customer.displayName),
              _buildCardDetailRow('Card UID', cardUid),
              const Divider(height: 24),
              _buildCardDetailRow('Balance', currencyFormat.format(balance.balance),
                  valueColor: balance.balance > 0 ? Colors.green : Colors.grey),
              _buildCardDetailRow('Total Deposited', currencyFormat.format(balance.totalDeposited)),
              _buildCardDetailRow('Total Spent', currencyFormat.format(balance.totalSpent)),
              const Divider(height: 24),
              _buildCardDetailRow('Confirm Required', balance.nfcConfirmRequired ? 'Yes' : 'No'),
              _buildCardDetailRow('Payment Enabled', balance.nfcPaymentEnabled ? 'Yes' : 'No'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading card: ${response.message}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildCardDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeLocation() async {
    // Only for Leruma - customers filtered by stock location's supervisor
    if (ApiService.currentClient?.id != 'leruma') return;
    if (!mounted) return;
    final locationProvider = context.read<LocationProvider>();
    if (locationProvider.allowedLocations.isEmpty) {
      await locationProvider.initialize();
    }
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // For Leruma: filter customers by stock location's supervisor
    int? locationId;
    if (ApiService.currentClient?.id == 'leruma') {
      final locationProvider = context.read<LocationProvider>();
      locationId = locationProvider.selectedLocation?.locationId;
    }

    final response = await _apiService.getCustomers(
      search: _searchQuery.isEmpty ? null : _searchQuery,
      limit: 100,
      locationId: locationId,
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
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Location selector - Leruma only (customers filtered by location's supervisor)
          if (isLeruma && locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PopupMenuButton<StockLocation>(
                  offset: const Offset(0, 40),
                  color: Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        locationProvider.selectedLocation!.locationName,
                        style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 20, color: Colors.white),
                    ],
                  ),
                  onSelected: (location) async {
                    await locationProvider.selectLocation(location);
                    _loadCustomers(); // Reload customers for new location
                  },
                  itemBuilder: (context) => locationProvider.allowedLocations
                      .map((location) => PopupMenuItem<StockLocation>(
                            value: location,
                            child: Row(
                              children: [
                                Icon(
                                  location.locationId == locationProvider.selectedLocation?.locationId
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: location.locationId == locationProvider.selectedLocation?.locationId
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  location.locationName,
                                  style: TextStyle(
                                    color: location.locationId == locationProvider.selectedLocation?.locationId
                                        ? AppColors.primary
                                        : Colors.black87,
                                    fontWeight: location.locationId == locationProvider.selectedLocation?.locationId
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
        ],
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
                ? _buildSkeletonLoading(isDark)
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
                                return _buildCustomerCard(_customers[index], isDark, isLeruma);
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

  Widget _buildCustomerCard(Customer customer, bool isDark, bool isLeruma) {
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
                  // NFC Card indicator - Leruma only
                  if (ApiService.currentClient?.id == 'leruma' && _customerNfcCards.containsKey(customer.personId)) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.nfc, size: 14, color: Colors.orange),
                          SizedBox(width: 4),
                          Text(
                            'NFC',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  // Days since last sale - Leruma only
                  if (isLeruma && customer.days != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: customer.days! > 30 ? AppColors.error.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${customer.days} days',
                        style: TextStyle(
                          fontSize: 12,
                          color: customer.days! > 30 ? AppColors.error : AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Edit, Delete, and NFC buttons with permissions
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
                      // NFC Card button - Leruma only, different action based on whether card exists
                      if (_nfcAvailable && ApiService.currentClient?.id == 'leruma') ...[
                        const SizedBox(width: 8),
                        if (_customerNfcCards.containsKey(customer.personId))
                          // Customer already has NFC card - show view button
                          PermissionIconButton(
                            permissionId: PermissionIds.nfcCardsView,
                            onPressed: () => _viewCustomerNfcCard(customer),
                            icon: const Icon(Icons.credit_card, size: 18),
                            tooltip: 'View NFC Card',
                            color: Colors.green,
                            showDisabled: false,
                          )
                        else
                          // Customer doesn't have NFC card - show register button
                          PermissionIconButton(
                            permissionId: PermissionIds.nfcCardsRegister,
                            onPressed: () => _registerCardToCustomer(customer),
                            icon: const Icon(Icons.add_card, size: 18),
                            tooltip: 'Register NFC Card',
                            color: Colors.orange,
                            showDisabled: false,
                          ),
                      ],
                    ],
                  ),
                  // Add Payment button - only show if customer has balance > 0
                  if (customer.balance > 0)
                    Flexible(
                      child: PermissionWrapper(
                        permissionId: PermissionIds.customersAddPayment,
                        child: TextButton.icon(
                          icon: const Icon(Icons.payment, size: 16),
                          label: const Text('Add Payment', overflow: TextOverflow.ellipsis),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                  // View Credit Account button
                  Flexible(
                    child: PermissionWrapper(
                      permissionId: PermissionIds.customersViewCredit,
                      child: TextButton.icon(
                        icon: const Icon(Icons.account_balance, size: 16),
                        label: const Text('View Credit', overflow: TextOverflow.ellipsis),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
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

  /// Build skeleton loading placeholder for customers list
  Widget _buildSkeletonLoading(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 6, // Show 6 skeleton cards
      itemBuilder: (context, index) {
        return _buildSkeletonCard(isDark);
      },
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with avatar and name
            Row(
              children: [
                // Avatar skeleton
                _buildShimmerBox(40, 40, baseColor, highlightColor, isCircle: true),
                const SizedBox(width: 12),
                // Name and supervisor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(120, 16, baseColor, highlightColor),
                      const SizedBox(height: 6),
                      _buildShimmerBox(80, 12, baseColor, highlightColor),
                    ],
                  ),
                ),
                // Supervisor badge skeleton
                _buildShimmerBox(100, 24, baseColor, highlightColor, borderRadius: 12),
              ],
            ),
            const SizedBox(height: 12),
            // Phone number
            _buildShimmerBox(100, 14, baseColor, highlightColor),
            const SizedBox(height: 8),
            // Credit and Balance row
            Row(
              children: [
                Expanded(child: _buildShimmerBox(80, 14, baseColor, highlightColor)),
                const SizedBox(width: 16),
                Expanded(child: _buildShimmerBox(80, 14, baseColor, highlightColor)),
              ],
            ),
            const Divider(height: 24),
            // Action buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildShimmerBox(32, 32, baseColor, highlightColor, isCircle: true),
                    const SizedBox(width: 8),
                    _buildShimmerBox(32, 32, baseColor, highlightColor, isCircle: true),
                  ],
                ),
                Row(
                  children: [
                    _buildShimmerBox(70, 28, baseColor, highlightColor, borderRadius: 4),
                    const SizedBox(width: 8),
                    _buildShimmerBox(80, 28, baseColor, highlightColor, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox(double width, double height, Color baseColor, Color highlightColor, {bool isCircle = false, double borderRadius = 4}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Color.lerp(baseColor, highlightColor, (value * 2 - 1).abs()),
            borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          ),
        );
      },
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
  // NFC settings
  bool _nfcConfirmRequired = false;
  bool _nfcPaymentEnabled = false;

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
    // NFC settings
    _nfcConfirmRequired = widget.customer?.nfcConfirmRequired ?? false;
    _nfcPaymentEnabled = widget.customer?.nfcPaymentEnabled ?? false;

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
      nfcConfirmRequired: _nfcConfirmRequired,
      nfcPaymentEnabled: _nfcPaymentEnabled,
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
        const Divider(),
        // NFC Settings Section - Leruma only, requires nfc_cards_settings permission
        if (ApiService.currentClient?.id == 'leruma')
          Consumer<PermissionProvider>(
            builder: (context, permissionProvider, child) {
              if (!permissionProvider.hasPermission(PermissionIds.nfcCardsSettings)) {
                return const SizedBox.shrink();
              }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.nfc, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'NFC Card Settings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('NFC Payment Enabled'),
                  subtitle: const Text('Allow customer to pay using NFC card balance'),
                  value: _nfcPaymentEnabled,
                  onChanged: (value) {
                    setState(() => _nfcPaymentEnabled = value);
                  },
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.green,
                ),
                SwitchListTile(
                  title: const Text('NFC Confirmation Required'),
                  subtitle: const Text('Require NFC card scan for credit sales'),
                  value: _nfcConfirmRequired,
                  onChanged: (value) {
                    setState(() => _nfcConfirmRequired = value);
                  },
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.orange,
                ),
                const Divider(),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedSupervisorId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Supervisor Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: _supervisors.map((supervisor) {
            return DropdownMenuItem(
              value: supervisor.id,
              child: Text(
                supervisor.name,
                overflow: TextOverflow.ellipsis,
              ),
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
        // Hide Is Boda Boda for Leruma (column doesn't exist in Leruma database)
        if (ApiService.currentClient?.id != 'leruma')
          CheckboxListTile(
            title: const Text('Is Boda Boda'),
            value: _isBodaBoda,
            onChanged: (value) {
              setState(() => _isBodaBoda = value ?? false);
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        if (ApiService.currentClient?.id != 'leruma')
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
