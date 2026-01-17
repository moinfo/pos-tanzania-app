import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
    // Get current location for location-specific pricing
    final locationProvider = context.read<LocationProvider>();
    final currentLocationId = locationProvider.selectedLocation?.locationId;

    showDialog(
      context: context,
      builder: (context) => ItemFormDialog(
        item: item,
        currentLocationId: currentLocationId,
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
                                Flexible(
                                  child: Text(
                                    location.locationName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: location.locationId == locationProvider.selectedLocation?.locationId
                                          ? AppColors.primary
                                          : Colors.black87,
                                      fontWeight: location.locationId == locationProvider.selectedLocation?.locationId
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
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
  final int? currentLocationId; // Current location for location-specific pricing

  const ItemFormDialog({
    super.key,
    this.item,
    required this.onSaved,
    this.currentLocationId,
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
  late TextEditingController _wholesalePriceController;

  bool _isSubmitting = false;
  bool _allowAltDescription = false;
  bool _isSerialized = false;
  bool _showOnLanding = false;
  int _stockType = 0;
  int _itemType = 0;
  int? _taxCategoryId;
  int? _supplierId;
  String _dormant = 'ACTIVE';

  List<StockLocation> _stockLocations = [];
  Map<int, TextEditingController> _quantityControllers = {};

  // Image picker state
  final ImagePicker _imagePicker = ImagePicker();
  File? _mainImage;
  List<File> _galleryImages = [];
  List<File> _portfolioImages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

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
    _wholesalePriceController = TextEditingController(
      text: widget.item?.wholesalePrice.toString() ?? '0',
    );

    // Initialize state variables
    _allowAltDescription = widget.item?.allowAltDescription ?? false;
    _isSerialized = widget.item?.isSerialized ?? false;
    _showOnLanding = widget.item?.showOnLanding ?? false;
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
    _wholesalePriceController.dispose();
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

  // Image picker methods
  Future<void> _pickMainImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _mainImage = File(image.path));
    }
  }

  Future<void> _pickGalleryImages() async {
    final List<XFile> images = await _imagePicker.pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (images.isNotEmpty) {
      setState(() {
        _galleryImages.addAll(images.map((img) => File(img.path)));
      });
    }
  }

  Future<void> _pickPortfolioImages() async {
    final List<XFile> images = await _imagePicker.pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (images.isNotEmpty) {
      setState(() {
        _portfolioImages.addAll(images.map((img) => File(img.path)));
      });
    }
  }

  void _removeMainImage() {
    setState(() => _mainImage = null);
  }

  void _removeGalleryImage(int index) {
    setState(() => _galleryImages.removeAt(index));
  }

  void _removePortfolioImage(int index) {
    setState(() => _portfolioImages.removeAt(index));
  }

  /// Validate profit margin to ensure no loss
  /// Returns error message if validation fails, null if valid
  String? _validateProfitMargin() {
    final costPrice = double.tryParse(_costPriceController.text) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0;
    final discountLimit = double.tryParse(_discountLimitController.text) ?? 0;

    // Skip validation if prices are not set
    if (unitPrice <= 0) return null;

    // Selling price must be >= cost price
    if (costPrice > 0 && unitPrice < costPrice) {
      return 'Selling price (${NumberFormat('#,###').format(unitPrice)}) cannot be less than cost price (${NumberFormat('#,###').format(costPrice)})';
    }

    // Discount limit cannot exceed profit margin (sell - cost)
    if (costPrice > 0 && discountLimit > 0) {
      final maxDiscount = unitPrice - costPrice;
      if (discountLimit > maxDiscount) {
        return 'Discount limit (${NumberFormat('#,###').format(discountLimit)}) exceeds profit margin (${NumberFormat('#,###').format(maxDiscount)}). Maximum discount allowed is ${NumberFormat('#,###').format(maxDiscount)} TSh.';
      }
    }

    return null;
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate profit margin before saving
    final profitError = _validateProfitMargin();
    if (profitError != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Validation Error'),
            ],
          ),
          content: Text(profitError),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Build quantity by location map
    Map<int, double> quantityByLocation = {};
    for (var entry in _quantityControllers.entries) {
      quantityByLocation[entry.key] = double.tryParse(entry.value.text) ?? 0;
    }

    // Build location-specific pricing if editing from a specific location
    // This ensures the price the user sees and edits is saved to the correct location
    Map<int, ItemLocationPriceFormData>? locationPrices;

    // When editing from a specific location, only update location-specific prices
    // Keep default prices unchanged (use original values from item)
    double defaultCostPrice = double.tryParse(_costPriceController.text) ?? 0;
    double defaultUnitPrice = double.tryParse(_unitPriceController.text) ?? 0;
    int defaultDiscountLimit = int.tryParse(_discountLimitController.text) ?? 0;

    if (widget.currentLocationId != null && widget.item != null) {
      final unitPrice = double.tryParse(_unitPriceController.text);
      final costPrice = double.tryParse(_costPriceController.text);
      final discountLimit = int.tryParse(_discountLimitController.text);

      locationPrices = {
        widget.currentLocationId!: ItemLocationPriceFormData(
          costPrice: costPrice,
          unitPrice: unitPrice,
          discountLimit: discountLimit,
        ),
      };

      // Use original default prices (not the edited location-specific values)
      defaultCostPrice = widget.item!.defaultCostPrice ?? widget.item!.costPrice;
      defaultUnitPrice = widget.item!.defaultUnitPrice ?? widget.item!.unitPrice;
      defaultDiscountLimit = widget.item!.defaultDiscountLimit ?? widget.item!.discountLimit;
    }

    final formData = ItemFormData(
      name: _nameController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
      itemNumber: _itemNumberController.text.trim().isEmpty
          ? null
          : _itemNumberController.text.trim(),
      costPrice: defaultCostPrice,
      unitPrice: defaultUnitPrice,
      wholesalePrice: double.tryParse(_wholesalePriceController.text) ?? 0,
      reorderLevel: double.tryParse(_reorderLevelController.text) ?? 0,
      receivingQuantity: double.tryParse(_receivingQuantityController.text) ?? 1,
      allowAltDescription: _allowAltDescription,
      isSerialized: _isSerialized,
      showOnLanding: _showOnLanding,
      stockType: _stockType,
      itemType: _itemType,
      taxCategoryId: _taxCategoryId,
      supplierId: _supplierId,
      qtyPerPack: double.tryParse(_qtyPerPackController.text) ?? 1,
      packName: _packNameController.text.trim(),
      arrange: int.tryParse(_arrangeController.text) ?? 0,
      discountLimit: defaultDiscountLimit,
      dormant: _dormant,
      quantityByLocation: quantityByLocation,
      locationPrices: locationPrices,
    );

    // Check if any images are selected - use multipart upload if so
    final hasImages = _mainImage != null ||
        _galleryImages.isNotEmpty ||
        _portfolioImages.isNotEmpty;

    final response = hasImages
        ? (widget.item == null
            ? await _apiService.createItemWithImages(
                formData,
                mainImagePath: _mainImage?.path,
                galleryImagePaths: _galleryImages.map((f) => f.path).toList(),
                portfolioImagePaths: _portfolioImages.map((f) => f.path).toList(),
              )
            : await _apiService.updateItemWithImages(
                widget.item!.itemId,
                formData,
                mainImagePath: _mainImage?.path,
                galleryImagePaths: _galleryImages.map((f) => f.path).toList(),
                portfolioImagePaths: _portfolioImages.map((f) => f.path).toList(),
              ))
        : (widget.item == null
            ? await _apiService.createItem(formData)
            : await _apiService.updateItem(widget.item!.itemId, formData));

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
                Tab(text: 'Details'),
                Tab(text: 'Images'),
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
                    _buildImagesTab(),
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
          const SizedBox(height: 16),
          // Wholesale Price
          TextFormField(
            controller: _wholesalePriceController,
            decoration: const InputDecoration(
              labelText: 'Wholesale Price',
              border: OutlineInputBorder(),
              helperText: 'Price for wholesale/bulk orders',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          // Show on Landing
          SwitchListTile(
            title: const Text('Show on Landing Page'),
            subtitle: const Text('Display this item on the public landing page'),
            value: _showOnLanding,
            onChanged: (value) => setState(() => _showOnLanding = value),
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

  Widget _buildImagesTab() {
    final existingMainImage = widget.item?.picFilename;
    final existingGalleryImages = widget.item?.galleryImages ?? [];
    final existingPortfolioImages = widget.item?.portfolioImages ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Item Image
          const Text(
            'Main Item Image',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _mainImage != null
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _mainImage!,
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _removeMainImage,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                )
              : existingMainImage != null && existingMainImage.isNotEmpty
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: '${ApiService.baseUrlSync}/uploads/item_pics/$existingMainImage.png',
                            height: 150,
                            width: 150,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 150,
                              width: 150,
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 150,
                              width: 150,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: _pickMainImage,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.edit, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  : OutlinedButton.icon(
                      onPressed: _pickMainImage,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Select Main Image'),
                    ),
          const SizedBox(height: 24),

          // Gallery Images
          const Text(
            'Gallery Images',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Additional images for product gallery',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          if (existingGalleryImages.isNotEmpty || _galleryImages.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Existing gallery images from API
                ...existingGalleryImages.map((img) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: img.url,
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 80,
                            width: 80,
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 80,
                            width: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        ),
                      ),
                      if (img.isPrimary)
                        Positioned(
                          bottom: 2,
                          left: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Primary', style: TextStyle(color: Colors.white, fontSize: 8)),
                          ),
                        ),
                    ],
                  );
                }),
                // New gallery images (local files)
                ..._galleryImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final image = entry.value;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          image,
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeGalleryImage(index),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 8)),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _pickGalleryImages,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(existingGalleryImages.isEmpty && _galleryImages.isEmpty ? 'Select Gallery Images' : 'Add More'),
          ),
          const SizedBox(height: 24),

          // Portfolio/History Images
          const Text(
            'Portfolio Images',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Product history or manufacturing images',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          if (existingPortfolioImages.isNotEmpty || _portfolioImages.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Existing portfolio images from API
                ...existingPortfolioImages.map((img) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: img.url,
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 80,
                            width: 80,
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 80,
                            width: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                // New portfolio images (local files)
                ..._portfolioImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final image = entry.value;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          image,
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removePortfolioImage(index),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 8)),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _pickPortfolioImages,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(existingPortfolioImages.isEmpty && _portfolioImages.isEmpty ? 'Select Portfolio Images' : 'Add More'),
          ),
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
