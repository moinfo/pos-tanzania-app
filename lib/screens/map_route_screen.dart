import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/map_route.dart';
import '../models/stock_location.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import '../widgets/skeleton_loader.dart';

/// Map Route Screen (Delivery Route Planning)
/// Shows ALL active customers with reordering capability
class MapRouteScreen extends StatefulWidget {
  const MapRouteScreen({super.key});

  @override
  State<MapRouteScreen> createState() => _MapRouteScreenState();
}

class _MapRouteScreenState extends State<MapRouteScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<MapRouteCustomer> _customers = [];
  List<MapRouteCustomer> _filteredCustomers = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  bool _hasChanges = false;

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
      if (query.isEmpty) {
        _filteredCustomers = List.from(_customers);
      } else {
        _filteredCustomers = _customers.where((customer) {
          return customer.fullName.toLowerCase().contains(query) ||
              (customer.address1?.toLowerCase().contains(query) ?? false) ||
              (customer.address2?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _hasChanges = false;
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

    final response = await _apiService.getMapRoute(locationId: locationId);

    if (response.isSuccess && response.data != null) {
      setState(() {
        _customers = response.data!.customers;
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

  void _moveUp(int index) {
    if (index <= 0 || _searchController.text.isNotEmpty) return;

    setState(() {
      final customer = _customers.removeAt(index);
      _customers.insert(index - 1, customer);
      _filteredCustomers = List.from(_customers);
      _hasChanges = true;
    });
  }

  void _moveDown(int index) {
    if (index >= _customers.length - 1 || _searchController.text.isNotEmpty) return;

    setState(() {
      final customer = _customers.removeAt(index);
      _customers.insert(index + 1, customer);
      _filteredCustomers = List.from(_customers);
      _hasChanges = true;
    });
  }

  Future<void> _saveOrder() async {
    if (!_hasChanges) return;

    setState(() {
      _isSaving = true;
    });

    final orders = _customers.asMap().entries.map((entry) {
      return {
        'person_id': entry.value.personId,
        'sort_order': entry.key + 1,
      };
    }).toList();

    final response = await _apiService.updateCustomerOrder(orders: orders);

    setState(() {
      _isSaving = false;
    });

    if (response.isSuccess) {
      setState(() {
        _hasChanges = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route order saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${response.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        title: const Text('Map Route', style: TextStyle(fontSize: 18)),
        actions: [
          // Location selector
          if (locationProvider.allowedLocations.isNotEmpty &&
              locationProvider.selectedLocation != null)
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
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down,
                          size: 18, color: Colors.white),
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
                                  location.locationId ==
                                          locationProvider
                                              .selectedLocation?.locationId
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: location.locationId ==
                                          locationProvider
                                              .selectedLocation?.locationId
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
      floatingActionButton: _hasChanges
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _saveOrder,
              backgroundColor: _headerColor,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Order',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(bool isDark) {
    return Column(
      children: [
        // Search Bar and Count
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
                  hintText: 'Search customer name or address...',
                  hintStyle: TextStyle(
                      color:
                          isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: 18,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              // Summary row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, size: 16, color: _headerColor),
                      const SizedBox(width: 4),
                      Text(
                        '${_filteredCustomers.length} of ${_customers.length} customers',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if (_searchController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Reorder disabled while searching',
                        style: TextStyle(fontSize: 10, color: Colors.orange),
                      ),
                    ),
                ],
              ),
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
                          Icon(Icons.error_outline,
                              size: 48, color: AppColors.error),
                          const SizedBox(height: 16),
                          Text(_error!,
                              style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87)),
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
                              Icon(Icons.map_outlined,
                                  size: 64,
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No customers found'
                                    : 'No customers',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
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
                            itemCount: _filteredCustomers.length,
                            itemBuilder: (context, index) {
                              return _buildCustomerCard(
                                  _filteredCustomers[index], index, isDark);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(MapRouteCustomer customer, int index, bool isDark) {
    final canReorder = _searchController.text.isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isDark ? 2 : 3,
      color: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Number badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _headerColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Customer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.fullName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (customer.address1 != null &&
                      customer.address1!.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            customer.address1!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (customer.address2 != null &&
                      customer.address2!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              customer.address2!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Days badge
            if (customer.daysSinceLastSale != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _getDaysColor(customer.daysSinceLastSale!).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${customer.daysSinceLastSale}d',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getDaysColor(customer.daysSinceLastSale!),
                  ),
                ),
              ),

            // Reorder buttons
            Column(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_upward,
                    size: 20,
                    color: canReorder && index > 0
                        ? _headerColor
                        : Colors.grey.shade400,
                  ),
                  onPressed: canReorder && index > 0
                      ? () => _moveUp(index)
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_downward,
                    size: 20,
                    color: canReorder && index < _filteredCustomers.length - 1
                        ? _headerColor
                        : Colors.grey.shade400,
                  ),
                  onPressed: canReorder && index < _filteredCustomers.length - 1
                      ? () => _moveDown(index)
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getDaysColor(int days) {
    if (days <= 7) return Colors.green;
    if (days <= 14) return Colors.amber;
    if (days <= 30) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: isDark ? AppColors.darkCard : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SkeletonLoader(
                  width: 32, height: 32, borderRadius: 16, isDark: isDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(
                        width: 150, height: 16, borderRadius: 4, isDark: isDark),
                    const SizedBox(height: 8),
                    SkeletonLoader(
                        width: double.infinity,
                        height: 12,
                        borderRadius: 4,
                        isDark: isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
