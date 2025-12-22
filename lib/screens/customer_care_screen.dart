import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/customer_care.dart';
import '../models/stock_location.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import '../widgets/skeleton_loader.dart';

/// Customer Care Screen (CRM View)
/// Shows customers with credit info and days since last purchase
class CustomerCareScreen extends StatefulWidget {
  const CustomerCareScreen({super.key});

  @override
  State<CustomerCareScreen> createState() => _CustomerCareScreenState();
}

class _CustomerCareScreenState extends State<CustomerCareScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  List<CustomerCareItem> _customers = [];
  List<CustomerCareItem> _filteredCustomers = [];
  CustomerCareTotals? _totals;
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'all'; // all, active, attention, at_risk, inactive, new

  // Use app brand colors
  static const Color _headerColor = AppColors.primary;
  static const Color _headerColorDark = AppColors.primaryDark;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCustomers);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _customers.where((customer) {
        // Filter by search query
        final matchesQuery = query.isEmpty ||
            customer.fullName.toLowerCase().contains(query) ||
            (customer.phoneNumber?.contains(query) ?? false) ||
            (customer.address1?.toLowerCase().contains(query) ?? false);

        // Filter by status
        final matchesStatus = _filterStatus == 'all' ||
            customer.activityStatus == _filterStatus;

        return matchesQuery && matchesStatus;
      }).toList();

      // Sort by days since last sale (null = new customers first, then ascending)
      _filteredCustomers.sort((a, b) {
        if (a.daysSinceLastSale == null && b.daysSinceLastSale == null) return 0;
        if (a.daysSinceLastSale == null) return -1;
        if (b.daysSinceLastSale == null) return 1;
        return b.daysSinceLastSale!.compareTo(a.daysSinceLastSale!); // Inactive first
      });
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final locationProvider = context.read<LocationProvider>();
    final locationId = locationProvider.selectedLocation?.locationId;

    if (locationId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No location selected';
      });
      return;
    }

    final response = await _apiService.getCustomerCare(locationId: locationId);

    if (response.isSuccess && response.data != null) {
      setState(() {
        _customers = response.data!.customers;
        _totals = response.data!.totals;
        _isLoading = false;
      });
      _filterCustomers();
    } else {
      setState(() {
        _isLoading = false;
        _error = response.message;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'attention':
        return Colors.amber;
      case 'at_risk':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      case 'new':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'attention':
        return 'Needs Attention';
      case 'at_risk':
        return 'At Risk';
      case 'inactive':
        return 'Inactive';
      case 'new':
        return 'New Customer';
      default:
        return 'Unknown';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'attention':
        return Icons.warning;
      case 'at_risk':
        return Icons.error;
      case 'inactive':
        return Icons.cancel;
      case 'new':
        return Icons.star;
      default:
        return Icons.help;
    }
  }

  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
      return;
    }
    final formattedPhone = phone.startsWith('0') ? phone : '0$phone';
    final uri = Uri.parse('tel:$formattedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _messageCustomer(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
      return;
    }
    final formattedPhone = phone.startsWith('0') ? phone : '0$phone';
    final uri = Uri.parse('sms:$formattedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: _headerColor,
        foregroundColor: Colors.white,
        title: const Text('Customer Care', style: TextStyle(fontSize: 18)),
        actions: [
          // Location selector
          if (locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PopupMenuButton<StockLocation>(
                  offset: const Offset(0, 40),
                  color: isDark ? AppColors.darkCard : Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        locationProvider.selectedLocation!.locationName,
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
                    ],
                  ),
                  onSelected: (location) async {
                    await locationProvider.selectLocation(location);
                    _loadData();
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
                                  size: 18,
                                  color: location.locationId == locationProvider.selectedLocation?.locationId
                                      ? _headerColor
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  location.locationName,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Search field
              TextField(
                controller: _searchController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search customer name, phone, or address...',
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              // Status filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All', Icons.people, Colors.grey, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('active', 'Active', Icons.check_circle, Colors.green, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('attention', 'Attention', Icons.warning, Colors.amber, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('at_risk', 'At Risk', Icons.error, Colors.orange, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('inactive', 'Inactive', Icons.cancel, Colors.red, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('new', 'New', Icons.star, Colors.blue, isDark),
                  ],
                ),
              ),
              // Summary row
              if (_totals != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: _headerColor),
                        const SizedBox(width: 4),
                        Text(
                          '${_filteredCustomers.length} of ${_totals!.customerCount}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '${_currencyFormat.format(_totals!.balance)} TSh',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? _buildSkeletonList(isDark)
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 16),
                          Text(_error!, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _headerColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredCustomers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty || _filterStatus != 'all'
                                    ? 'No customers found'
                                    : 'No customers',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: _headerColor,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredCustomers.length + 1, // +1 for totals card
                            itemBuilder: (context, index) {
                              if (index == _filteredCustomers.length) {
                                return _buildTotalsCard(isDark);
                              }
                              return _buildCustomerCard(_filteredCustomers[index], index + 1, isDark);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String status, String label, IconData icon, Color color, bool isDark) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? Colors.white : color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = status;
        });
        _filterCustomers();
      },
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
      selectedColor: color,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildCustomerCard(CustomerCareItem customer, int number, bool isDark) {
    final statusColor = _getStatusColor(customer.activityStatus);
    final statusLabel = _getStatusLabel(customer.activityStatus);
    final statusIcon = _getStatusIcon(customer.activityStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 2 : 3,
      color: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status color gradient
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_headerColor, _headerColorDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                // Number badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: _headerColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Customer name and phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (customer.phoneNumber != null && customer.phoneNumber!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.phone, size: 12, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                customer.phoneNumber!.startsWith('0')
                                    ? customer.phoneNumber!
                                    : '0${customer.phoneNumber}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        customer.daysSinceLastSale != null
                            ? '${customer.daysSinceLastSale}d'
                            : 'New',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Customer details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Address
                if ((customer.address1 != null && customer.address1!.isNotEmpty) ||
                    (customer.address2 != null && customer.address2!.isNotEmpty))
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [customer.address1, customer.address2]
                                .where((a) => a != null && a.isNotEmpty)
                                .join(', '),
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Credit info
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        'Credit Limit',
                        '${_currencyFormat.format(customer.creditLimit)} TSh',
                        Icons.account_balance_wallet,
                        Colors.blue,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoTile(
                        'Balance',
                        '${_currencyFormat.format(customer.balance)} TSh',
                        Icons.money,
                        customer.balance > 0 ? Colors.orange : Colors.green,
                        isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Status info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 20, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              customer.daysSinceLastSale != null
                                  ? 'Last purchase: ${customer.daysSinceLastSale} days ago'
                                  : 'No purchase yet',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: Icons.phone,
                  label: 'Call',
                  color: Colors.green,
                  onTap: () => _callCustomer(customer.phoneNumber),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.message,
                  label: 'SMS',
                  color: Colors.blue,
                  onTap: () => _messageCustomer(customer.phoneNumber),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(bool isDark) {
    if (_totals == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 2 : 3,
      color: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _headerColor,
          width: 2,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _headerColor.withOpacity(0.1),
              _headerColorDark.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: _headerColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Totals',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTotalItem(
                    'Total Customers',
                    '${_totals!.customerCount}',
                    Icons.people,
                    Colors.blue,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTotalItem(
                    'Total Credit Limit',
                    '${_currencyFormat.format(_totals!.creditLimit)} TSh',
                    Icons.account_balance_wallet,
                    Colors.green,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTotalItem(
                    'Total Balance',
                    '${_currencyFormat.format(_totals!.balance)} TSh',
                    Icons.money,
                    _totals!.balance > 0 ? Colors.orange : Colors.green,
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalItem(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 4,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: isDark ? AppColors.darkCard : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader(width: 150, height: 20, borderRadius: 4, isDark: isDark),
              const SizedBox(height: 12),
              SkeletonLoader(width: double.infinity, height: 16, borderRadius: 4, isDark: isDark),
              const SizedBox(height: 8),
              SkeletonLoader(width: double.infinity, height: 16, borderRadius: 4, isDark: isDark),
              const SizedBox(height: 8),
              SkeletonLoader(width: 200, height: 16, borderRadius: 4, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}
