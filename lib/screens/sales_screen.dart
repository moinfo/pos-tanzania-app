import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sale_provider.dart';
import '../providers/permission_provider.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../models/item.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/permission_model.dart';
import '../models/stock_location.dart';
import '../utils/constants.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/permission_wrapper.dart';
import '../widgets/skeleton_loader.dart';
import 'package:intl/intl.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  List<Item> _items = [];
  List<Item> _filteredItems = [];
  bool _isLoading = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Defer location initialization until after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;
    final locationProvider = context.read<LocationProvider>();
    // Initialize for sales module to get sales-specific locations
    await locationProvider.initialize(moduleId: 'sales');
    // Load items after location is initialized
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);

    final locationProvider = context.read<LocationProvider>();
    final selectedLocationId = locationProvider.selectedLocation?.locationId;

    final response = await _apiService.getItems(
      limit: 100,
      locationId: selectedLocationId,
    );

    if (response.isSuccess && response.data != null) {
      setState(() {
        _items = response.data!;
        _filteredItems = []; // Start with empty list - show items only when user searches
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message)),
        );
      }
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = []; // Don't show items when search is empty
      } else {
        _filteredItems = _items
            .where((item) =>
                item.name.toLowerCase().contains(query.toLowerCase()) ||
                (item.itemNumber?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });
  }

  void _addItemToCart(Item item) {
    final locationProvider = context.read<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;

    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a stock location first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Get stock quantity for selected location
    double currentStock = 0;
    if (item.quantityByLocation != null) {
      currentStock = item.quantityByLocation![selectedLocation.locationId] ?? 0;
    } else {
      currentStock = item.quantity ?? 0;
    }

    if (currentStock <= 0) {
      // Show error - out of stock
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} is out of stock at ${selectedLocation.locationName}!'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final saleProvider = context.read<SaleProvider>();

    // Set stock location in provider if not already set
    if (saleProvider.stockLocation != selectedLocation.locationId) {
      saleProvider.setStockLocation(selectedLocation.locationId);
    }

    // Get current quantity in cart for this item
    final existingItemIndex = saleProvider.cartItems.indexWhere(
      (cartItem) => cartItem.itemId == item.itemId,
    );

    final currentQuantityInCart = existingItemIndex >= 0
        ? saleProvider.cartItems[existingItemIndex].quantity
        : 0;
    final totalQuantityInCart = currentQuantityInCart + 1;

    // Check if adding one more would exceed available stock
    if (totalQuantityInCart > currentStock) {
      // Show error - insufficient stock
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${item.name}: Only ${currentStock.toStringAsFixed(0)} available in stock!\nAlready have ${currentQuantityInCart.toStringAsFixed(0)} in cart.',
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Add to cart with location-specific stock
    saleProvider.addItem(item, quantity: 1, locationId: selectedLocation.locationId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to cart (${totalQuantityInCart.toStringAsFixed(0)}/${currentStock.toStringAsFixed(0)})'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _selectCustomer() async {
    // Show customer selection dialog
    showDialog(
      context: context,
      builder: (context) => const CustomerSelectionDialog(),
    );
  }

  Future<void> _suspendSale() async {
    final saleProvider = context.read<SaleProvider>();

    // Validate cart
    final validationError = saleProvider.validateCart();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    // Ask for optional comment
    String? comment;
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add an optional comment for this suspended sale:'),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: 'e.g., Customer will return later',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              comment = commentController.text.trim();
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final response = await _apiService.suspendSale(
        items: saleProvider.cartItems,
        customerId: saleProvider.selectedCustomer?.personId,
        comment: comment?.isNotEmpty == true ? comment : null,
      );

      setState(() => _isProcessing = false);

      if (response.isSuccess) {
        // Clear cart
        saleProvider.clearCart();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale suspended successfully!'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error suspending sale: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showDebugDialog(Map<String, dynamic> saleData) {
    final debug = saleData['debug'] as Map<String, dynamic>?;

    if (debug == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Sale Debug Info', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sale ID
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text('Sale ID: ${debug['sale_id']}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tables Updated
              const Text('✅ Tables Updated:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (debug['tables_updated'] != null) ...[
                for (var entry in (debug['tables_updated'] as Map<String, dynamic>).entries)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text('• ${entry.key}: ${entry.value} record(s)',
                      style: const TextStyle(fontSize: 13)),
                  ),
              ],

              const SizedBox(height: 16),
              const Divider(thickness: 2),
              const SizedBox(height: 16),

              // Inventory Logs
              Row(
                children: [
                  Icon(
                    (debug['inventory_logs_created'] ?? 0) > 0
                        ? Icons.check_circle
                        : Icons.error,
                    color: (debug['inventory_logs_created'] ?? 0) > 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Text('Inventory Logs: ${debug['inventory_logs_created']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: (debug['inventory_logs_created'] ?? 0) > 0
                          ? AppColors.success
                          : AppColors.error,
                    )),
                ],
              ),

              const SizedBox(height: 16),
              const Text('📦 Items with Stock Changes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),

              // Items with Before/After Quantities
              if (debug['items_processed'] != null) ...[
                for (var item in (debug['items_processed'] as List<dynamic>))
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['item_name']} (ID: ${item['item_id']})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Before', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('${item['quantity_before']}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ],
                            ),
                            const Text('−', style: TextStyle(fontSize: 24, color: AppColors.warning)),
                            Column(
                              children: [
                                const Text('Sold', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('${item['quantity_sold']}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.error)),
                              ],
                            ),
                            const Text('=', style: TextStyle(fontSize: 24, color: AppColors.warning)),
                            Column(
                              children: [
                                const Text('After', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('${item['quantity_after']}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('📝 Log: ${item['inventory_log']}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPayment() async {
    final saleProvider = context.read<SaleProvider>();

    // Validate customer is selected
    if (saleProvider.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer before adding payment'),
          backgroundColor: AppColors.warning,
        ),
      );
      // Open customer selection dialog
      _selectCustomer();
      return;
    }

    // Validate cart
    final validationError = saleProvider.validateCart();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    // Show payment dialog
    final payment = await showDialog<SalePayment>(
      context: context,
      builder: (context) => PaymentDialog(
        total: saleProvider.amountDue > 0 ? saleProvider.amountDue : saleProvider.total,
        customer: saleProvider.selectedCustomer,
      ),
    );

    if (payment == null) return;

    // Add payment to list
    saleProvider.addPayment(payment);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment added: ${payment.paymentType} - ${payment.amount.toStringAsFixed(0)} TSh'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _completeSale() async {
    final saleProvider = context.read<SaleProvider>();

    // Validate customer is selected
    if (saleProvider.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer before checkout'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Validate cart
    final validationError = saleProvider.validateCart();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    // Validate payments
    if (!saleProvider.hasPayments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one payment'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!saleProvider.isFullyPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment incomplete. Amount due: ${saleProvider.amountDue.toStringAsFixed(0)} TSh',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Create sale
    setState(() => _isProcessing = true);

    try {
      final sale = saleProvider.createSale();
      print('DEBUG: Creating sale with data: ${sale.toCreateJson()}');

      final response = await _apiService.createSale(sale);
      print('DEBUG: API Response - Success: ${response.isSuccess}, Message: ${response.message}');

      // Print debug info
      if (response.data != null && response.data!.toJson().containsKey('debug')) {
        print('DEBUG: Response contains debug info');
        print('DEBUG: Debug data: ${response.data!.toJson()['debug']}');
      }

      setState(() => _isProcessing = false);

      if (response.isSuccess) {
        // Clear cart
        saleProvider.clearCart();

        // Show debug info dialog
        if (mounted && response.data != null) {
          _showDebugDialog(response.data!.toJson());
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale completed successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      setState(() => _isProcessing = false);
      print('DEBUG: Exception creating sale: $e');
      print('DEBUG: Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saleProvider = context.watch<SaleProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales', style: TextStyle(fontSize: 18)),
            if (saleProvider.selectedCustomer != null)
              Text(
                '${saleProvider.selectedCustomer!.firstName} ${saleProvider.selectedCustomer!.lastName}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              )
            else
              const Text(
                'No Customer Selected',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.warning),
              ),
          ],
        ),
        actions: [
          // Location selector
          if (locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    _loadItems(); // Reload items for new location
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
                                    color: isDark ? Colors.white : Colors.black87,
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
            icon: const Icon(Icons.person_outline),
            onPressed: _selectCustomer,
            tooltip: 'Select Customer',
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeletonGrid(isDark)
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                              onPressed: () {
                                _searchController.clear();
                                _filterItems('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? AppColors.darkCard : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _filterItems,
                  ),
                ),

                // Items list
                Expanded(
                  child: Consumer<LocationProvider>(
                    builder: (context, locationProvider, child) {
                      return ListView.builder(
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];

                          // Get stock quantity for selected location
                          final selectedLocation = locationProvider.selectedLocation;
                          double stockQty = 0;
                          String locationName = '';

                          if (selectedLocation != null && item.quantityByLocation != null) {
                            stockQty = item.quantityByLocation![selectedLocation.locationId] ?? 0;
                            locationName = selectedLocation.locationName;
                          } else {
                            stockQty = item.quantity ?? 0;
                            locationName = 'Total';
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            color: isDark ? AppColors.darkCard : Colors.white,
                            elevation: isDark ? 2 : 1,
                            child: ListTile(
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                'Stock: ${stockQty.toStringAsFixed(0)} ($locationName) | '
                                'Price: ${_currencyFormat.format(item.unitPrice)} TSh',
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.add_shopping_cart,
                                  color: isDark ? AppColors.primary.withOpacity(0.8) : AppColors.primary,
                                ),
                                onPressed: () => _addItemToCart(item),
                              ),
                              onTap: () => _addItemToCart(item),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Cart summary and payments
                Consumer<SaleProvider>(
                  builder: (context, saleProvider, child) {
                    if (!saleProvider.hasItems) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Total and items count
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${saleProvider.itemCount} items',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                '${_currencyFormat.format(saleProvider.total)} TSh',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.primary.withOpacity(0.9) : AppColors.primary,
                                ),
                              ),
                            ],
                          ),

                          // Payment list (if any)
                          if (saleProvider.hasPayments) ...[
                            const SizedBox(height: 12),
                            Divider(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Payments',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${_currencyFormat.format(saleProvider.totalPayments)} TSh',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...saleProvider.payments.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final payment = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          payment.paymentType,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.grey.shade300 : Colors.grey[700],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '${_currencyFormat.format(payment.amount)} TSh',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark ? Colors.grey.shade300 : Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => saleProvider.removePayment(index),
                                              child: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 8),
                                Divider(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Amount Due',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${_currencyFormat.format(saleProvider.amountDue)} TSh',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: saleProvider.isFullyPaid ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),
                          // Action buttons - Compact layout
                          Column(
                            children: [
                              // Row 1: View Cart and Suspend
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: SizedBox(
                                      height: 44,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const CartScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.shopping_cart, size: 18),
                                        label: const Text(
                                          'View Cart',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: AppColors.primary, width: 1.5),
                                          foregroundColor: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Suspend button - requires permission
                                  Expanded(
                                    flex: 2,
                                    child: PermissionWrapper(
                                      permissionId: PermissionIds.salesSuspended,
                                      child: SizedBox(
                                        height: 44,
                                        child: OutlinedButton.icon(
                                          onPressed: _isProcessing ? null : _suspendSale,
                                          icon: const Icon(Icons.pause_circle_outline, size: 18),
                                          label: const Text(
                                            'Suspend',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.warning,
                                            side: BorderSide(color: AppColors.warning, width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Row 2: Add Payment and Complete Sale
                              Row(
                                children: [
                                  // Add Payment button - requires permission
                                  Expanded(
                                    child: PermissionWrapper(
                                      permissionId: PermissionIds.salesAddPayment,
                                      child: SizedBox(
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          onPressed: _isProcessing ? null : _addPayment,
                                          icon: const Icon(Icons.add_card, size: 20),
                                          label: const Text(
                                            'Add Payment',
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Complete Sale button - requires permission
                                  Expanded(
                                    child: PermissionWrapper(
                                      permissionId: PermissionIds.salesAdd,
                                      child: SizedBox(
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          onPressed: (_isProcessing || !saleProvider.isFullyPaid)
                                              ? null
                                              : _completeSale,
                                          icon: _isProcessing
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Icon(
                                                  saleProvider.isFullyPaid
                                                      ? Icons.check_circle
                                                      : Icons.lock,
                                                  size: 20,
                                                ),
                                          label: Text(
                                            saleProvider.isFullyPaid ? 'Complete' : 'Complete',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: saleProvider.isFullyPaid
                                                ? AppColors.success
                                                : Colors.grey.shade400,
                                            foregroundColor: Colors.white,
                                            elevation: saleProvider.isFullyPaid ? 2 : 0,
                                            disabledBackgroundColor: Colors.grey.shade300,
                                            disabledForegroundColor: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
      // Bottom navigation is now handled by MainNavigation
    );
  }

  Widget _buildSkeletonGrid(bool isDark) {
    return Column(
      children: [
        // Search bar skeleton
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SkeletonLoader(
            width: double.infinity,
            height: 48,
            borderRadius: 12,
            isDark: isDark,
          ),
        ),
        // Items grid skeleton
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) => _buildSkeletonItemCard(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonItemCard(bool isDark) {
    return Card(
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonLoader(width: 50, height: 50, borderRadius: 8, isDark: isDark),
            const SizedBox(height: 8),
            SkeletonLoader(width: 60, height: 12, isDark: isDark),
            const SizedBox(height: 4),
            SkeletonLoader(width: 40, height: 14, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

// Cart Screen
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Map<int, TextEditingController> _discountControllers = {};
  final Map<int, TextEditingController> _quantityControllers = {};

  @override
  void dispose() {
    for (var controller in _discountControllers.values) {
      controller.dispose();
    }
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'en_US');

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
        foregroundColor: isDark ? AppColors.darkText : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<SaleProvider>().clearCart();
              Navigator.pop(context);
            },
            tooltip: 'Clear Cart',
          ),
        ],
      ),
      body: Consumer<SaleProvider>(
        builder: (context, saleProvider, child) {
          if (!saleProvider.hasItems) {
            return Center(
              child: Text(
                'Cart is empty',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: saleProvider.cartItems.length,
                  itemBuilder: (context, index) {
                    final item = saleProvider.cartItems[index];
                    final discountLimit = item.discountLimit ?? 0;

                    // Initialize discount controller for this item
                    if (!_discountControllers.containsKey(index)) {
                      // Show discount per item, not total
                      final discountPerItem = item.discount > 0 ? (item.discount / item.quantity) : 0;
                      _discountControllers[index] = TextEditingController(
                        text: discountPerItem > 0 ? discountPerItem.toStringAsFixed(0) : '',
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      color: isDark ? AppColors.darkCard : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
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
                                        item.itemName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isDark ? AppColors.darkText : AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '@ ${currencyFormat.format(item.unitPrice)} TSh',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                                        ),
                                      ),
                                      if (item.availableStock != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Stock: ${item.availableStock!.toStringAsFixed(0)} available',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: item.availableStock! < item.quantity
                                                ? AppColors.error
                                                : item.availableStock! < item.quantity * 2
                                                    ? AppColors.warning
                                                    : AppColors.success,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: AppColors.error),
                                  onPressed: () => saleProvider.removeItem(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Quantity controls
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () => saleProvider.decrementQuantity(index),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        // Show dialog to edit quantity
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            final controller = TextEditingController(
                                              text: item.quantity.toStringAsFixed(0),
                                            );
                                            return AlertDialog(
                                              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                                              title: Text(
                                                'Edit Quantity',
                                                style: TextStyle(
                                                  color: isDark ? AppColors.darkText : AppColors.text,
                                                ),
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (item.availableStock != null)
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 12),
                                                      child: Text(
                                                        'Available stock: ${item.availableStock!.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: isDark ? AppColors.darkTextLight : Colors.grey[700],
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  TextField(
                                                    controller: controller,
                                                    keyboardType: TextInputType.number,
                                                    autofocus: true,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Quantity',
                                                      border: OutlineInputBorder(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    final newQuantity = double.tryParse(controller.text) ?? 1;

                                                    // Validate quantity > 0
                                                    if (newQuantity <= 0) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Quantity must be greater than 0'),
                                                          backgroundColor: AppColors.error,
                                                        ),
                                                      );
                                                      return;
                                                    }

                                                    // Validate against available stock
                                                    if (item.availableStock != null && newQuantity > item.availableStock!) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Cannot exceed available stock of ${item.availableStock!.toStringAsFixed(0)}',
                                                          ),
                                                          backgroundColor: AppColors.error,
                                                          duration: const Duration(seconds: 3),
                                                        ),
                                                      );
                                                      return;
                                                    }

                                                    // Update quantity
                                                    saleProvider.updateQuantity(index, newQuantity);
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text('Update'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isDark
                                                ? AppColors.darkTextLight.withOpacity(0.3)
                                                : Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          color: isDark
                                              ? AppColors.darkBackground
                                              : Colors.grey.shade50,
                                        ),
                                        child: Text(
                                          '${item.quantity.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.darkText : AppColors.text,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () {
                                        // Check if incrementing would exceed available stock
                                        if (item.availableStock != null &&
                                            item.quantity + 1 > item.availableStock!) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Cannot exceed available stock of ${item.availableStock!.toStringAsFixed(0)}',
                                              ),
                                              backgroundColor: AppColors.error,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        } else {
                                          saleProvider.incrementQuantity(index);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                // Price
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${currencyFormat.format(item.unitPrice * item.quantity)} TSh',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isDark ? AppColors.darkTextLight : Colors.grey,
                                        decoration: item.discount > 0 ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    if (item.discount > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${currencyFormat.format(item.calculateTotal())} TSh',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ] else
                                      Text(
                                        '${currencyFormat.format(item.calculateTotal())} TSh',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.darkText : AppColors.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            // Only show discount field if item has discount limit
                            if (discountLimit > 0) ...[
                              const SizedBox(height: 8),
                              // Discount input
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _discountControllers[index],
                                      decoration: InputDecoration(
                                        labelText: 'Discount per item (TSh)',
                                        helperText: 'Limit: ${currencyFormat.format(discountLimit)} TSh',
                                        helperStyle: const TextStyle(
                                          color: AppColors.warning,
                                          fontSize: 11,
                                        ),
                                        border: const OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final discountPerItem = double.tryParse(value) ?? 0;

                                        // Validate against discount limit per item
                                        if (discountPerItem > discountLimit) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Discount cannot exceed ${currencyFormat.format(discountLimit)} TSh per item',
                                              ),
                                              backgroundColor: AppColors.error,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                          _discountControllers[index]?.text = discountLimit.toString();
                                          // Total discount = discount per item × quantity
                                          saleProvider.updateDiscount(index, discountLimit.toDouble() * item.quantity, discountType: 1);
                                        } else {
                                          // Total discount = discount per item × quantity
                                          saleProvider.updateDiscount(index, discountPerItem * item.quantity, discountType: 1);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Cart summary
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal:',
                          style: TextStyle(
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        Text(
                          '${currencyFormat.format(saleProvider.subtotal)} TSh',
                          style: TextStyle(
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      ],
                    ),
                    if (saleProvider.totalDiscount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Discount:',
                            style: TextStyle(color: AppColors.error),
                          ),
                          Text(
                            '- ${currencyFormat.format(saleProvider.totalDiscount)} TSh',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ],
                    Divider(
                      height: 16,
                      color: isDark ? AppColors.darkTextLight.withOpacity(0.3) : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        Text(
                          '${currencyFormat.format(saleProvider.total)} TSh',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Payment Dialog
class PaymentDialog extends StatefulWidget {
  final double total;
  final Customer? customer;

  const PaymentDialog({
    super.key,
    required this.total,
    this.customer,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _paymentMethod = 'Cash';
  final TextEditingController _amountController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.total.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Widget _buildCreditInfo() {
    if (_paymentMethod != 'Credit Card' || widget.customer == null) {
      return const SizedBox.shrink();
    }

    final customer = widget.customer!;
    final currentBalance = customer.balance;
    final creditLimit = customer.creditLimit;
    final availableCredit = creditLimit - currentBalance;
    final isAllowedCredit = customer.isAllowedCredit;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Credit Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCreditInfoRow(
            'Credit Status',
            isAllowedCredit ? 'ACTIVE' : 'INACTIVE',
            isAllowedCredit ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 6),
          _buildCreditInfoRow(
            'Credit Limit',
            '${_currencyFormat.format(creditLimit)} TSh',
            Colors.grey.shade700,
          ),
          const SizedBox(height: 6),
          _buildCreditInfoRow(
            'Current Balance',
            '${_currencyFormat.format(currentBalance)} TSh',
            Colors.grey.shade700,
          ),
          const SizedBox(height: 6),
          _buildCreditInfoRow(
            'Available Credit',
            '${_currencyFormat.format(availableCredit)} TSh',
            availableCredit > 0 ? AppColors.success : AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  String? _validatePayment() {
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (amount <= 0) {
      return 'Invalid amount';
    }

    // Validate credit card payment
    if (_paymentMethod == 'Credit Card' && widget.customer != null) {
      final customer = widget.customer!;

      // Check if customer is allowed credit
      if (!customer.isAllowedCredit) {
        return 'Customer is not allowed to make credit purchases.\nPlease pay with cash.';
      }

      // Check credit limit
      final currentBalance = customer.balance;
      final creditLimit = customer.creditLimit;
      final availableCredit = creditLimit - currentBalance;

      if (amount > availableCredit) {
        return 'Credit limit exceeded!\n'
            'Available credit: ${_currencyFormat.format(availableCredit)} TSh\n'
            'Requested: ${_currencyFormat.format(amount)} TSh';
      }
    }

    return null; // Valid
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'Credit Card', child: Text('Credit Card')),
              ],
              onChanged: (value) {
                setState(() => _paymentMethod = value!);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                suffixText: 'TSh',
                border: OutlineInputBorder(),
              ),
            ),
            _buildCreditInfo(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final validationError = _validatePayment();
            if (validationError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(validationError),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 4),
                ),
              );
              return;
            }

            final amount = double.tryParse(_amountController.text) ?? 0;
            Navigator.pop(context,
              SalePayment(paymentType: _paymentMethod, amount: amount),
            );
          },
          child: const Text('Add Payment'),
        ),
      ],
    );
  }
}

// Customer Selection Dialog
class CustomerSelectionDialog extends StatefulWidget {
  const CustomerSelectionDialog({super.key});

  @override
  State<CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<CustomerSelectionDialog> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);

    final response = await _apiService.getCustomers(limit: 100);

    if (response.isSuccess && response.data != null) {
      setState(() {
        _customers = response.data!;
        _filteredCustomers = _customers;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message)),
        );
      }
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        _filteredCustomers = _customers
            .where((customer) =>
                customer.firstName.toLowerCase().contains(query.toLowerCase()) ||
                customer.lastName.toLowerCase().contains(query.toLowerCase()) ||
                (customer.phoneNumber?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Customer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _filterCustomers('');
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _filterCustomers(value);
                });
              },
            ),
            const SizedBox(height: 16),

            // Customers list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCustomers.isEmpty
                      ? const Center(child: Text('No customers found'))
                      : ListView.builder(
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    customer.firstName[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  '${customer.firstName} ${customer.lastName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (customer.phoneNumber != null)
                                      Text(customer.phoneNumber!),
                                    if (customer.balance != null && customer.balance != 0)
                                      Text(
                                        'Balance: ${NumberFormat('#,###').format(customer.balance)} TSh',
                                        style: TextStyle(
                                          color: customer.balance! > 0
                                              ? AppColors.error
                                              : AppColors.success,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  context.read<SaleProvider>().setCustomer(customer);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Customer: ${customer.firstName} ${customer.lastName}'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return Column(
      children: [
        // Search bar skeleton
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SkeletonLoader(
            width: double.infinity,
            height: 48,
            borderRadius: 8,
            isDark: isDark,
          ),
        ),
        // Items grid skeleton
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) => _buildSkeletonItemCard(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonItemCard(bool isDark) {
    return Card(
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonLoader(width: 50, height: 50, borderRadius: 8, isDark: isDark),
            const SizedBox(height: 8),
            SkeletonLoader(width: 60, height: 12, isDark: isDark),
            const SizedBox(height: 4),
            SkeletonLoader(width: 40, height: 14, isDark: isDark),
          ],
        ),
      ),
    );
  }
}
