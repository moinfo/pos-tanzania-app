import 'package:flutter/material.dart';
import '../../utils/constants.dart';

import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/item.dart';
import '../../models/supplier.dart';
import '../../providers/location_provider.dart';
import '../../providers/receiving_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_bottom_navigation.dart';

class NewReceivingScreen extends StatefulWidget {
  const NewReceivingScreen({super.key});

  @override
  State<NewReceivingScreen> createState() => _NewReceivingScreenState();
}

class _NewReceivingScreenState extends State<NewReceivingScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  List<Item> _searchResults = [];
  bool _isSearching = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Set stock location from LocationProvider after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      final receivingProvider = context.read<ReceivingProvider>();
      if (locationProvider.selectedLocation != null) {
        receivingProvider.setStockLocation(locationProvider.selectedLocation!.locationId);
      }
      // For Leruma: Set Credit Card as default payment type
      if (_hasCreditCardOnlyFeature()) {
        receivingProvider.setPaymentType('Credit Card');
      }
    });
  }

  /// Helper method to safely check if supplier filtering by location is enabled
  /// This is a Leruma-specific feature
  bool _hasSuppliersByLocationFeature() {
    try {
      return ApiService.currentClient?.features.hasSuppliersByLocation ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Helper method to check if only Credit Card payment is allowed (Leruma-specific)
  bool _hasCreditCardOnlyFeature() {
    try {
      return ApiService.currentClient?.features.hasReceivingCreditCardOnly ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _referenceController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _searchItems(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await _apiService.getItems(
        search: query,
        limit: 20,
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          // Filter to show only active (non-dormant) items
          _searchResults = response.data!
              .where((item) => item.dormant == 'ACTIVE')
              .toList();
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _addItemToCart(Item item) {
    final receivingProvider = context.read<ReceivingProvider>();

    // Show dialog to enter quantity and cost price
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        item: item,
        onAdd: (quantity, costPrice) {
          receivingProvider.addItem(item, quantity: quantity, costPrice: costPrice);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.name} added to cart'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 1),
            ),
          );
          setState(() {
            _searchResults = [];
            _searchController.clear();
          });
        },
      ),
    );
  }

  Future<void> _selectSupplier() async {
    // Check if we should filter suppliers by location (Leruma-specific feature)
    final bool filterByLocation = _hasSuppliersByLocationFeature();
    final locationProvider = context.read<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;

    // If filtering by location, we need a selected location
    if (filterByLocation && selectedLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a stock location first'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Call the appropriate API based on feature flag
    final response = filterByLocation && selectedLocation != null
        ? await _apiService.getSuppliersByLocation(selectedLocation.locationId)
        : await _apiService.getSuppliers();

    if (!response.isSuccess || response.data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Failed to load suppliers'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final suppliers = response.data!;

    if (!mounted) return;

    final selected = await showDialog<Supplier>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Supplier'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(supplier.companyName[0].toUpperCase()),
                ),
                title: Text(supplier.companyName),
                subtitle: Text('Balance: ${supplier.balance.toStringAsFixed(0)} TSh'),
                onTap: () => Navigator.pop(context, supplier),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null) {
      context.read<ReceivingProvider>().setSupplier(selected);
    }
  }

  Future<void> _completeReceiving() async {
    final receivingProvider = context.read<ReceivingProvider>();

    // Validate
    final validationError = receivingProvider.validateCart();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Receiving'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supplier: ${receivingProvider.selectedSupplier?.companyName}'),
            const SizedBox(height: 8),
            Text('Items: ${receivingProvider.itemCount}'),
            Text('Total Quantity: ${receivingProvider.totalQuantity.toStringAsFixed(0)}'),
            Text('Total Cost: ${_formatCurrency(receivingProvider.total)}'),
            const SizedBox(height: 16),
            const Text(
              'This will increase stock quantities.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // Set reference and comment
      if (_referenceController.text.isNotEmpty) {
        receivingProvider.setReference(_referenceController.text);
      }
      if (_commentController.text.isNotEmpty) {
        receivingProvider.setComment(_commentController.text);
      }

      final receiving = receivingProvider.createReceiving();
      final response = await _apiService.createReceiving(receiving);

      if (response.isSuccess) {
        if (mounted) {
          receivingProvider.clearCart();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Receiving created successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to create receiving'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
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
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return '${formatter.format(amount)} TSh';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('New Receiving'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.success,
        foregroundColor: Colors.white,
        actions: [
          // Location selector
          Consumer<LocationProvider>(
            builder: (context, locationProvider, child) {
              if (locationProvider.selectedLocation == null) {
                return const SizedBox.shrink();
              }

              return Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        locationProvider.selectedLocation!.locationName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Receivings'),
                  content: const Text(
                    'Receivings are used to record inventory purchased from suppliers. '
                    'This will increase your stock quantities.\n\n'
                    '1. Select a supplier\n'
                    '2. Add items with quantity and cost price\n'
                    '3. Complete the receiving',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<ReceivingProvider>(
        builder: (context, receivingProvider, child) {
          return Column(
            children: [
              // Supplier selection
              Container(
                padding: const EdgeInsets.all(12),
                color: isDark ? AppColors.darkSurface : AppColors.success,
                child: InkWell(
                  onTap: _selectSupplier,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? AppColors.darkDivider : AppColors.success,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isDark ? AppColors.darkCard : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.business,
                          color: isDark ? AppColors.success : AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receivingProvider.selectedSupplier != null
                                    ? receivingProvider.selectedSupplier!.companyName
                                    : 'Select Supplier',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: receivingProvider.selectedSupplier != null
                                      ? (isDark ? AppColors.darkText : Colors.black87)
                                      : (isDark ? AppColors.darkTextLight : Colors.grey.shade600),
                                ),
                              ),
                              if (receivingProvider.selectedSupplier == null)
                                Text(
                                  'Tap to select',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextLight : Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: isDark ? AppColors.darkTextLight : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? AppColors.darkText : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search items to receive...',
                    hintStyle: TextStyle(
                      color: isDark ? AppColors.darkTextLight : Colors.grey.shade600,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? AppColors.darkTextLight : Colors.grey.shade600,
                    ),
                    suffixIcon: _isSearching
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? AppColors.success : AppColors.primary,
                              ),
                            ),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.success : AppColors.success,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : Colors.grey.shade100,
                  ),
                  onChanged: _searchItems,
                ),
              ),

              // Search results
              if (_searchResults.isNotEmpty)
                Consumer<LocationProvider>(
                  builder: (context, locationProvider, child) {
                    return Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];

                          // Get stock quantity for selected location
                          final selectedLocation = locationProvider.selectedLocation;
                          double stockQty = 0;
                          String locationName = '';

                          if (selectedLocation != null && item.quantityByLocation != null) {
                            stockQty = item.quantityByLocation![selectedLocation.locationId] ?? 0;
                            locationName = selectedLocation.locationName;
                          }

                          return ListTile(
                            tileColor: isDark ? AppColors.darkCard : Colors.white,
                            leading: Icon(
                              Icons.inventory_2_outlined,
                              color: isDark ? AppColors.success : AppColors.primary,
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                color: isDark ? AppColors.darkText : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              'Stock: ${stockQty.toStringAsFixed(0)} ($locationName)',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextLight : Colors.grey.shade600,
                              ),
                            ),
                            trailing: Text(
                              _formatCurrency(item.costPrice),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkText : Colors.black87,
                              ),
                            ),
                            onTap: () => _addItemToCart(item),
                          );
                        },
                      ),
                    );
                  },
                ),

              // Cart
              Expanded(
                child: receivingProvider.hasItems
                    ? ListView.builder(
                        itemCount: receivingProvider.cartItems.length,
                        itemBuilder: (context, index) {
                          final item = receivingProvider.cartItems[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            color: isDark ? AppColors.darkCard : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.itemName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.darkText : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: AppColors.error),
                                        onPressed: () =>
                                            receivingProvider.removeItem(index),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Quantity controls
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          color: isDark ? AppColors.darkBackground : Colors.white,
                                        ),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.remove,
                                                size: 18,
                                                color: isDark ? AppColors.darkText : Colors.black87,
                                              ),
                                              onPressed: () => receivingProvider
                                                  .decrementQuantity(index),
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12),
                                              child: Text(
                                                item.quantity.toStringAsFixed(0),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? AppColors.darkText : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.add,
                                                size: 18,
                                                color: isDark ? AppColors.darkText : Colors.black87,
                                              ),
                                              onPressed: () => receivingProvider
                                                  .incrementQuantity(index),
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Cost price
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Cost: ${_formatCurrency(item.costPrice)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDark ? AppColors.darkTextLight : Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              'Total: ${_formatCurrency(item.calculateTotal())}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: isDark ? AppColors.darkTextLight : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items in cart',
                              style: TextStyle(
                                fontSize: 18,
                                color: isDark ? AppColors.darkText : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Search and add items to receive',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.darkTextLight : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // Bottom summary and action
              if (receivingProvider.hasItems)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.grey.shade300,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Payment Type dropdown
                      // For Leruma: Only show Credit Card option
                      DropdownButtonFormField<String>(
                        value: receivingProvider.paymentType,
                        dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Payment Type',
                          labelStyle: TextStyle(
                            color: isDark ? AppColors.darkTextLight : Colors.grey.shade700,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkBackground : Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _hasCreditCardOnlyFeature()
                            ? [
                                // Leruma: Only Credit Card
                                DropdownMenuItem(
                                  value: 'Credit Card',
                                  child: Text(
                                    'Credit Card',
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkText : Colors.black87,
                                    ),
                                  ),
                                ),
                              ]
                            : [
                                // Other clients: Cash and Credit Card
                                DropdownMenuItem(
                                  value: 'Cash',
                                  child: Text(
                                    'Cash',
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkText : Colors.black87,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Credit Card',
                                  child: Text(
                                    'Credit Card',
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkText : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                        onChanged: _hasCreditCardOnlyFeature()
                            ? null  // Disable changing for Leruma (only one option)
                            : (value) {
                                if (value != null) {
                                  receivingProvider.setPaymentType(value);
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      // Reference field
                      TextField(
                        controller: _referenceController,
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Reference (Optional)',
                          labelStyle: TextStyle(
                            color: isDark ? AppColors.darkTextLight : Colors.grey.shade700,
                          ),
                          hintText: 'PO number, invoice...',
                          hintStyle: TextStyle(
                            color: isDark ? AppColors.darkTextLight : Colors.grey.shade500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkBackground : Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _commentController,
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Comment (Optional)',
                          labelStyle: TextStyle(
                            color: isDark ? AppColors.darkTextLight : Colors.grey.shade700,
                          ),
                          hintText: 'Additional notes...',
                          hintStyle: TextStyle(
                            color: isDark ? AppColors.darkTextLight : Colors.grey.shade500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkBackground : Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${receivingProvider.itemCount} items',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? AppColors.darkTextLight : Colors.grey,
                                ),
                              ),
                              Text(
                                _formatCurrency(receivingProvider.total),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _completeReceiving,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check_circle),
                            label: Text(
                              _isProcessing ? 'Processing...' : 'Complete',
                              style: const TextStyle(fontSize: 16),
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
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }
}

// Dialog to add item with quantity and cost price
class _AddItemDialog extends StatefulWidget {
  final Item item;
  final Function(double quantity, double costPrice) onAdd;

  const _AddItemDialog({
    required this.item,
    required this.onAdd,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  late TextEditingController _quantityController;
  late TextEditingController _costPriceController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _costPriceController = TextEditingController(
      text: widget.item.costPrice.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costPriceController.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final costPrice = double.tryParse(_costPriceController.text) ?? 0;

    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (costPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid cost price'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    widget.onAdd(quantity, costPrice);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _costPriceController,
            decoration: const InputDecoration(
              labelText: 'Cost Price (TSh)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Text(
            'Current stock: ${widget.item.quantity.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
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
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
