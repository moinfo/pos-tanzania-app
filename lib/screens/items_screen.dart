import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/permission_model.dart';
import '../models/stock_location.dart';
import '../providers/location_provider.dart';
import '../providers/permission_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/permission_wrapper.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Item> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize location after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
    _loadItems();
    // Auto-search while typing
    _searchController.addListener(() {
      _loadItems();
    });
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;
    final locationProvider = context.read<LocationProvider>();
    // Initialize if not already done
    if (locationProvider.allowedLocations.isEmpty) {
      await locationProvider.initialize();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Get selected location for filtering (especially for days calculation)
    final locationProvider = context.read<LocationProvider>();
    final selectedLocationId = locationProvider.selectedLocation?.locationId;

    final response = await _apiService.getItems(
      search: _searchController.text.isEmpty ? null : _searchController.text,
      limit: 100,
      locationId: selectedLocationId,
    );

    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _items = response.data ?? [];
      } else {
        _errorMessage = response.message;
      }
    });
  }

  void _showItemForm({Item? item}) {
    showDialog(
      context: context,
      builder: (context) => ItemFormDialog(
        item: item,
        onSaved: () {
          Navigator.pop(context);
          _loadItems();
        },
      ),
    );
  }

  Future<void> _deleteItem(Item item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
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
      final response = await _apiService.deleteItem(item.itemId);
      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully')),
          );
          _loadItems();
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
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Items'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Location selector - show if user has locations
          if (locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildSkeletonList(isDark)
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage!,
                                style: TextStyle(color: isDark ? AppColors.darkText : AppColors.error)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadItems,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _items.isEmpty
                        ? Center(child: Text('No items found', style: TextStyle(color: isDark ? AppColors.darkText : AppColors.text)))
                        : RefreshIndicator(
                            onRefresh: _loadItems,
                            child: ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _buildItemCard(item, isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: PermissionFAB(
        permissionId: PermissionIds.itemsAdd,
        onPressed: () => _showItemForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  // Skeleton loading placeholder list
  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      itemCount: 8, // Show 8 skeleton cards
      itemBuilder: (context, index) => _buildSkeletonCard(isDark),
    );
  }

  // Skeleton loading placeholder card
  Widget _buildSkeletonCard(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title skeleton
            _SkeletonBox(
              width: 200,
              height: 20,
              baseColor: baseColor,
              highlightColor: highlightColor,
            ),
            const SizedBox(height: 12),
            // Category skeleton
            _SkeletonBox(
              width: 150,
              height: 14,
              baseColor: baseColor,
              highlightColor: highlightColor,
            ),
            const SizedBox(height: 8),
            // Price skeleton
            _SkeletonBox(
              width: 120,
              height: 14,
              baseColor: baseColor,
              highlightColor: highlightColor,
            ),
            const SizedBox(height: 8),
            // Discount skeleton
            _SkeletonBox(
              width: 160,
              height: 14,
              baseColor: baseColor,
              highlightColor: highlightColor,
            ),
            const SizedBox(height: 8),
            // Stock skeleton
            _SkeletonBox(
              width: 180,
              height: 14,
              baseColor: baseColor,
              highlightColor: highlightColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Item item, bool isDark) {
    final locationProvider = context.watch<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;
    // Check if client has extended item info feature (Leruma only)
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    // Get quantity for selected location
    double displayQuantity = 0;
    String locationLabel = '...';

    if (selectedLocation != null) {
      locationLabel = selectedLocation.locationName;
      if (item.quantityByLocation != null) {
        displayQuantity = item.quantityByLocation![selectedLocation.locationId] ?? 0;
      }
    } else if (locationProvider.isLoading) {
      locationLabel = 'Loading...';
    } else if (locationProvider.allowedLocations.isEmpty) {
      locationLabel = 'No Location';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          item.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.text,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Row with Category and Variation (Leruma only)
            Row(
              children: [
                Expanded(
                  child: Text('Category: ${item.category}',
                      style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                ),
                if (isLeruma)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.variation == 'CTN' ? Colors.blue.withOpacity(0.2)
                           : item.variation == 'BUNDLE' ? Colors.orange.withOpacity(0.2)
                           : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(item.variation,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.variation == 'CTN' ? Colors.blue
                               : item.variation == 'BUNDLE' ? Colors.orange
                               : Colors.green,
                        )),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Price: ${NumberFormat('#,###').format(item.unitPrice)} TSh',
                style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
            // Row with Days and Mainstore (Leruma only)
            if (isLeruma) ...[
              Row(
                children: [
                  Expanded(
                    child: Text('Days: ${item.days ?? '-'}',
                        style: TextStyle(
                          color: (item.days != null && item.days! > 30)
                              ? Colors.red
                              : (isDark ? AppColors.darkTextLight : AppColors.textLight),
                          fontWeight: (item.days != null && item.days! > 30) ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                  Text('Mainstore: ${item.mainstore != null ? NumberFormat('#,###.##').format(item.mainstore) : '-'}',
                      style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text('Stock: ${NumberFormat('#,###.##').format(displayQuantity)} ($locationLabel)',
                style: TextStyle(color: isDark ? AppColors.darkText : AppColors.text)),
          ],
        ),
        trailing: Consumer<PermissionProvider>(
          builder: (context, permissionProvider, child) {
            final hasEdit = permissionProvider.hasPermission(PermissionIds.itemsEdit);
            final hasDelete = permissionProvider.hasPermission(PermissionIds.itemsDelete);

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
                  _showItemForm(item: item);
                } else if (value == 'delete') {
                  _deleteItem(item);
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class ItemFormDialog extends StatefulWidget {
  final Item? item;
  final VoidCallback onSaved;

  const ItemFormDialog({
    super.key,
    this.item,
    required this.onSaved,
  });

  @override
  State<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  late TextEditingController _itemNumberController;
  late TextEditingController _costPriceController;
  late TextEditingController _unitPriceController;
  late TextEditingController _reorderLevelController;
  late TextEditingController _receivingQuantityController;
  late TextEditingController _qtyPerPackController;
  late TextEditingController _packNameController;
  late TextEditingController _hsnCodeController;
  late TextEditingController _arrangeController;
  late TextEditingController _discountLimitController;

  bool _isSubmitting = false;
  bool _allowAltDescription = false;
  bool _isSerialized = false;
  int _stockType = 0;
  int _itemType = 0;
  int? _taxCategoryId;
  int? _supplierId;
  String _dormant = 'ACTIVE';

  List<StockLocation> _stockLocations = [];
  Map<int, TextEditingController> _quantityControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _nameController = TextEditingController(text: widget.item?.name);
    _categoryController = TextEditingController(text: widget.item?.category);
    _descriptionController = TextEditingController(text: widget.item?.description);
    _itemNumberController = TextEditingController(text: widget.item?.itemNumber);
    _costPriceController = TextEditingController(
      text: widget.item?.costPrice.toString() ?? '0',
    );
    _unitPriceController = TextEditingController(
      text: widget.item?.unitPrice.toString() ?? '0',
    );
    _reorderLevelController = TextEditingController(
      text: widget.item?.reorderLevel.toString() ?? '0',
    );
    _receivingQuantityController = TextEditingController(
      text: widget.item?.receivingQuantity.toString() ?? '1',
    );
    _qtyPerPackController = TextEditingController(
      text: widget.item?.qtyPerPack.toString() ?? '1',
    );
    _packNameController = TextEditingController(
      text: widget.item?.packName ?? 'Each',
    );
    _hsnCodeController = TextEditingController(
      text: widget.item?.hsnCode ?? '',
    );
    _arrangeController = TextEditingController(
      text: widget.item?.arrange.toString() ?? '0',
    );
    _discountLimitController = TextEditingController(
      text: widget.item?.discountLimit.toString() ?? '0',
    );

    // Initialize state variables
    _allowAltDescription = widget.item?.allowAltDescription ?? false;
    _isSerialized = widget.item?.isSerialized ?? false;
    _stockType = widget.item?.stockType ?? 0;
    _itemType = widget.item?.itemType ?? 0;
    _taxCategoryId = widget.item?.taxCategoryId;
    _supplierId = widget.item?.supplierId;
    _dormant = widget.item?.dormant ?? 'ACTIVE';

    _loadStockLocations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _itemNumberController.dispose();
    _costPriceController.dispose();
    _unitPriceController.dispose();
    _reorderLevelController.dispose();
    _receivingQuantityController.dispose();
    _qtyPerPackController.dispose();
    _packNameController.dispose();
    _hsnCodeController.dispose();
    _arrangeController.dispose();
    _discountLimitController.dispose();
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStockLocations() async {
    final response = await _apiService.getAllowedStockLocations(moduleId: 'items');
    if (response.isSuccess && mounted) {
      setState(() {
        _stockLocations = response.data ?? [];
        // Initialize quantity controllers for each location
        for (var location in _stockLocations) {
          double quantity = 0;
          if (widget.item?.quantityByLocation != null) {
            quantity = widget.item!.quantityByLocation![location.locationId] ?? 0;
          }
          _quantityControllers[location.locationId] = TextEditingController(
            text: quantity.toString(),
          );
        }
      });
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Build quantity by location map
    Map<int, double> quantityByLocation = {};
    for (var entry in _quantityControllers.entries) {
      quantityByLocation[entry.key] = double.tryParse(entry.value.text) ?? 0;
    }

    final formData = ItemFormData(
      name: _nameController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
      itemNumber: _itemNumberController.text.trim().isEmpty
          ? null
          : _itemNumberController.text.trim(),
      costPrice: double.tryParse(_costPriceController.text) ?? 0,
      unitPrice: double.tryParse(_unitPriceController.text) ?? 0,
      reorderLevel: double.tryParse(_reorderLevelController.text) ?? 0,
      receivingQuantity: double.tryParse(_receivingQuantityController.text) ?? 1,
      allowAltDescription: _allowAltDescription,
      isSerialized: _isSerialized,
      stockType: _stockType,
      itemType: _itemType,
      taxCategoryId: _taxCategoryId,
      supplierId: _supplierId,
      qtyPerPack: double.tryParse(_qtyPerPackController.text) ?? 1,
      packName: _packNameController.text.trim(),
      arrange: int.tryParse(_arrangeController.text) ?? 0,
      discountLimit: int.tryParse(_discountLimitController.text) ?? 0,
      dormant: _dormant,
      quantityByLocation: quantityByLocation,
    );

    final response = widget.item == null
        ? await _apiService.createItem(formData)
        : await _apiService.updateItem(widget.item!.itemId, formData);

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item == null
                ? 'Item created successfully'
                : 'Item updated successfully'),
          ),
        );
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionProvider = context.watch<PermissionProvider>();
    final canSeeCostPrice = permissionProvider.hasPermission(PermissionIds.itemsCostPrice);
    final canSeeQuantity = permissionProvider.hasPermission(PermissionIds.itemsQuantity);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.item == null ? 'Add Item' : 'Edit Item',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Basic Info'),
                Tab(text: 'Additional Details'),
              ],
            ),
            // Tab Views
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicInfoTab(canSeeCostPrice),
                    _buildAdditionalDetailsTab(canSeeQuantity),
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _saveItem,
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

  Widget _buildBasicInfoTab(bool canSeeCostPrice) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Item Name *',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter item name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _itemNumberController,
            decoration: const InputDecoration(
              labelText: 'Item Number/Barcode',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          if (canSeeCostPrice)
            Column(
              children: [
                TextFormField(
                  controller: _costPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Cost Price',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
              ],
            ),
          TextFormField(
            controller: _unitPriceController,
            decoration: const InputDecoration(
              labelText: 'Unit Price *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter unit price';
              }
              if (double.tryParse(value) == null) {
                return 'Please enter a valid number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _discountLimitController,
            decoration: const InputDecoration(
              labelText: 'Discount Limit',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetailsTab(bool canSeeQuantity) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stock Type
          DropdownButtonFormField<int>(
            value: _stockType,
            decoration: const InputDecoration(
              labelText: 'Stock Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Stock Item')),
              DropdownMenuItem(value: 1, child: Text('Non-Stock')),
            ],
            onChanged: (value) => setState(() => _stockType = value ?? 0),
          ),
          const SizedBox(height: 16),
          // Item Type
          DropdownButtonFormField<int>(
            value: _itemType,
            decoration: const InputDecoration(
              labelText: 'Item Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Standard')),
              DropdownMenuItem(value: 1, child: Text('Kit')),
            ],
            onChanged: (value) => setState(() => _itemType = value ?? 0),
          ),
          const SizedBox(height: 16),
          // Receiving Quantity
          TextFormField(
            controller: _receivingQuantityController,
            decoration: const InputDecoration(
              labelText: 'Receiving Quantity',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          // Reorder Level
          TextFormField(
            controller: _reorderLevelController,
            decoration: const InputDecoration(
              labelText: 'Reorder Level',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          // Qty Per Pack
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _qtyPerPackController,
                  decoration: const InputDecoration(
                    labelText: 'Qty Per Pack',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _packNameController,
                  decoration: const InputDecoration(
                    labelText: 'Pack Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // HSN Code
          TextFormField(
            controller: _hsnCodeController,
            decoration: const InputDecoration(
              labelText: 'HSN Code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Arrange/Sort
          TextFormField(
            controller: _arrangeController,
            decoration: const InputDecoration(
              labelText: 'Sort Order',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          // Switches
          SwitchListTile(
            title: const Text('Allow Alternate Description'),
            value: _allowAltDescription,
            onChanged: (value) => setState(() => _allowAltDescription = value),
          ),
          SwitchListTile(
            title: const Text('Item has Serial Number'),
            value: _isSerialized,
            onChanged: (value) => setState(() => _isSerialized = value),
          ),
          const SizedBox(height: 16),
          // Stock Quantities by Location
          if (canSeeQuantity && _stockLocations.isNotEmpty) ...[
            const Text(
              'Stock Quantities by Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._stockLocations.map((location) {
              final controller = _quantityControllers[location.locationId];
              final permissionProvider = context.watch<PermissionProvider>();
              final locationPermission = 'items_${location.locationName.toUpperCase()}';
              final hasLocationPermission = permissionProvider.hasPermission(locationPermission);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: location.locationName,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: hasLocationPermission,
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}

// Animated skeleton box widget for loading placeholders
class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final Color baseColor;
  final Color highlightColor;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _animation.value, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
