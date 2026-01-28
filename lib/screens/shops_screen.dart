import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/shop.dart';
import '../models/customer.dart';
import '../widgets/app_bottom_navigation.dart';
import '../utils/constants.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  final ApiService _apiService = ApiService();
  List<Shop> _shops = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getShops(search: _searchQuery.isEmpty ? null : _searchQuery);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _shops = response.data!;
        } else {
          _errorMessage = response.message;
        }
      });
    }
  }

  void _showAddShopDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddShopScreen(
          onShopCreated: () => _loadShops(),
        ),
      ),
    );
  }

  void _showShopDetails(Shop shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ShopDetailsSheet(
        shop: shop,
        onEdit: () => _editShop(shop),
        onDelete: () => _loadShops(),
      ),
    );
  }

  void _editShop(Shop shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditShopScreen(
          shop: shop,
          onShopUpdated: () => _loadShops(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shops'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadShops,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search shops...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                _searchQuery = value;
              },
              onSubmitted: (_) => _loadShops(),
            ),
          ),

          // Total shops count card
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.store, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Shops',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_shops.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _shops.isEmpty ? 'None' : 'Registered',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(_errorMessage!, style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadShops,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _shops.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No shops registered',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap + to register a new shop',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadShops,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: _shops.length,
                              itemBuilder: (context, index) {
                                final shop = _shops[index];
                                return _ShopListItem(
                                  shop: shop,
                                  onTap: () => _showShopDetails(shop),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddShopDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Shop', style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }
}

class _ShopListItem extends StatelessWidget {
  final Shop shop;
  final VoidCallback onTap;

  const _ShopListItem({required this.shop, required this.onTap});

  Color _getServiceStatusColor() {
    if (shop.daysSinceService == null) return Colors.grey;
    if (shop.daysSinceService! <= 7) return Colors.green;
    if (shop.daysSinceService! <= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final serviceColor = _getServiceStatusColor();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shop icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.store, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              // Shop details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.shopName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    if (shop.customer != null)
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            shop.customer!.displayName,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    if (shop.address != null && shop.address!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              shop.address!,
                              style: TextStyle(color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (shop.hasLocation) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.gps_fixed, size: 14, color: Colors.green[600]),
                          const SizedBox(width: 4),
                          Text(
                            'GPS: ${shop.latitude!.toStringAsFixed(6)}, ${shop.longitude!.toStringAsFixed(6)}',
                            style: TextStyle(color: Colors.green[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    // Registered by
                    if (shop.registeredBy != null && shop.registeredBy!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_add, size: 14, color: Colors.blue[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Registered by: ${shop.registeredBy}',
                            style: TextStyle(color: Colors.blue[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    // Days since service
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: serviceColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: serviceColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 14, color: serviceColor),
                          const SizedBox(width: 4),
                          Text(
                            shop.serviceStatusText,
                            style: TextStyle(
                              color: serviceColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopDetailsSheet extends StatefulWidget {
  final Shop shop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShopDetailsSheet({
    required this.shop,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ShopDetailsSheet> createState() => _ShopDetailsSheetState();
}

class _ShopDetailsSheetState extends State<_ShopDetailsSheet> {
  final ApiService _apiService = ApiService();
  bool _isDeleting = false;

  Shop get shop => widget.shop;

  Future<void> _openMap(BuildContext context) async {
    if (!shop.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No GPS coordinates for this shop'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final url = 'https://www.google.com/maps/search/?api=1&query=${shop.latitude},${shop.longitude}';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open map'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showServiceHistory(BuildContext context) {
    Navigator.pop(context); // Close the bottom sheet first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceHistoryScreen(shop: shop),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shop'),
        content: Text('Are you sure you want to delete "${shop.shopName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      setState(() => _isDeleting = true);

      final response = await _apiService.deleteShop(shop.shopId);

      if (mounted) {
        setState(() => _isDeleting = false);

        if (response.isSuccess) {
          Navigator.pop(context);
          widget.onDelete();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shop deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.store, color: AppColors.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.shopName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (shop.customer != null)
                      Text(
                        'Customer: ${shop.customer!.displayName}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Details
          _DetailRow(icon: Icons.calendar_today, label: 'Created', value: dateFormat.format(shop.createdAt)),

          if (shop.registeredBy != null && shop.registeredBy!.isNotEmpty)
            _DetailRow(icon: Icons.person_add, label: 'Registered By', value: shop.registeredBy!),

          if (shop.address != null && shop.address!.isNotEmpty)
            _DetailRow(icon: Icons.location_on, label: 'Address', value: shop.address!),

          if (shop.hasLocation) ...[
            _DetailRow(icon: Icons.my_location, label: 'Latitude', value: shop.latitude!.toStringAsFixed(8)),
            _DetailRow(icon: Icons.my_location, label: 'Longitude', value: shop.longitude!.toStringAsFixed(8)),
          ],

          if (shop.customer?.phoneNumber != null && shop.customer!.phoneNumber!.isNotEmpty)
            _DetailRow(icon: Icons.phone, label: 'Phone', value: shop.customer!.phoneNumber!),

          // Service status
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.access_time,
            label: 'Service',
            value: shop.serviceStatusText,
          ),

          const SizedBox(height: 24),

          // Action buttons - Row 1: Map and History
          Row(
            children: [
              // View on Map button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: shop.hasLocation ? () => _openMap(context) : null,
                  icon: const Icon(Icons.map),
                  label: const Text('View Map'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[700],
                    side: BorderSide(color: shop.hasLocation ? Colors.green : Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // View History button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showServiceHistory(context),
                  icon: const Icon(Icons.history),
                  label: const Text('History'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action buttons - Row 2: Edit and Delete
          Row(
            children: [
              // Edit button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onEdit();
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange[700],
                    side: BorderSide(color: Colors.orange[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Delete button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : () => _confirmDelete(context),
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete),
                  label: Text(_isDeleting ? 'Deleting...' : 'Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ============ ADD SHOP SCREEN ============

class AddShopScreen extends StatefulWidget {
  final VoidCallback onShopCreated;

  const AddShopScreen({super.key, required this.onShopCreated});

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();

  Customer? _selectedCustomer;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  bool _isSaving = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled. Please enable them.';
          _isLoadingLocation = false;
        });
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permission permanently denied. Please enable in settings.';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: $e';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _selectCustomer() async {
    final customer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerSelectorScreen(),
      ),
    );

    if (customer != null) {
      setState(() {
        _selectedCustomer = customer;
        // Pre-fill shop name with customer's company name if available
        if (_shopNameController.text.isEmpty && customer.companyName != null) {
          _shopNameController.text = customer.companyName!;
        }
      });
    }
  }

  Future<void> _saveShop() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final formData = ShopFormData(
      customerId: _selectedCustomer!.personId,
      shopName: _shopNameController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
    );

    final response = await _apiService.createShop(formData);

    if (mounted) {
      setState(() => _isSaving = false);

      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop registered successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onShopCreated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Shop'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // GPS Location Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gps_fixed, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'GPS Location',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_isLoadingLocation)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _getCurrentLocation,
                            tooltip: 'Refresh location',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_locationError != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _locationError!,
                                style: TextStyle(color: Colors.orange[700], fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_latitude != null && _longitude != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Location captured',
                                  style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lat: ${_latitude!.toStringAsFixed(8)}',
                              style: TextStyle(color: Colors.green[700], fontFamily: 'monospace'),
                            ),
                            Text(
                              'Lng: ${_longitude!.toStringAsFixed(8)}',
                              style: TextStyle(color: Colors.green[700], fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Getting location...'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Customer Selection
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                title: Text(
                  _selectedCustomer?.displayName ?? 'Select Customer',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _selectedCustomer == null ? Colors.grey : null,
                  ),
                ),
                subtitle: _selectedCustomer != null
                    ? Text(_selectedCustomer!.phoneNumber)
                    : const Text('Tap to select a customer'),
                trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                onTap: _selectCustomer,
              ),
            ),

            const SizedBox(height: 16),

            // Shop Name
            TextFormField(
              controller: _shopNameController,
              decoration: InputDecoration(
                labelText: 'Shop Name *',
                prefixIcon: const Icon(Icons.store),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Shop name is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Address (optional)
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address (optional)',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveShop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Register Shop', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ CUSTOMER SELECTOR SCREEN ============

// ============ EDIT SHOP SCREEN ============

class EditShopScreen extends StatefulWidget {
  final Shop shop;
  final VoidCallback onShopUpdated;

  const EditShopScreen({super.key, required this.shop, required this.onShopUpdated});

  @override
  State<EditShopScreen> createState() => _EditShopScreenState();
}

class _EditShopScreenState extends State<EditShopScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _shopNameController;
  late TextEditingController _addressController;

  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  bool _isSaving = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController(text: widget.shop.shopName);
    _addressController = TextEditingController(text: widget.shop.address ?? '');
    _latitude = widget.shop.latitude;
    _longitude = widget.shop.longitude;
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled. Please enable them.';
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permission permanently denied. Please enable in settings.';
          _isLoadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: $e';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _saveShop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final formData = ShopFormData(
      customerId: widget.shop.customerId,
      shopName: _shopNameController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
    );

    final response = await _apiService.updateShop(widget.shop.shopId, formData);

    if (mounted) {
      setState(() => _isSaving = false);

      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onShopUpdated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Shop'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // GPS Location Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gps_fixed, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'GPS Location',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_isLoadingLocation)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.my_location),
                            onPressed: _getCurrentLocation,
                            tooltip: 'Update location',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_locationError != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _locationError!,
                                style: TextStyle(color: Colors.orange[700], fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_latitude != null && _longitude != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Location set',
                                  style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lat: ${_latitude!.toStringAsFixed(8)}',
                              style: TextStyle(color: Colors.green[700], fontFamily: 'monospace'),
                            ),
                            Text(
                              'Lng: ${_longitude!.toStringAsFixed(8)}',
                              style: TextStyle(color: Colors.green[700], fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.location_off, size: 20, color: Colors.grey),
                            SizedBox(width: 8),
                            Text('No location set'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Customer info (read-only)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person, color: Colors.grey[600]),
                ),
                title: Text(
                  widget.shop.customer?.displayName ?? 'Customer #${widget.shop.customerId}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('Customer cannot be changed'),
              ),
            ),

            const SizedBox(height: 16),

            // Shop Name
            TextFormField(
              controller: _shopNameController,
              decoration: InputDecoration(
                labelText: 'Shop Name *',
                prefixIcon: const Icon(Icons.store),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Shop name is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Address (optional)
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address (optional)',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveShop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Update Shop', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ SERVICE HISTORY SCREEN ============

class ServiceHistoryScreen extends StatefulWidget {
  final Shop shop;

  const ServiceHistoryScreen({super.key, required this.shop});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<ServiceHistory> _history = [];
  bool _isLoading = true;
  String? _errorMessage;
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getServiceHistory(widget.shop.shopId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _history = response.data!;
        } else {
          _errorMessage = response.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Service History', style: TextStyle(fontSize: 16)),
            Text(
              widget.shop.shopName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadHistory,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              : _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No service history',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This shop has never been serviced',
                            style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final sale = _history[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.receipt, color: AppColors.primary),
                              ),
                              title: Text(
                                '${_currencyFormat.format(sale.total)} TSh',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFormat.format(sale.saleTime),
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                  if (sale.servedBy != null) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.person, size: 12, color: Colors.blue[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Served by: ${sale.servedBy}',
                                          style: TextStyle(color: Colors.blue[600], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    '${sale.items.length} items',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                ],
                              ),
                              children: [
                                // Items list
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: sale.items.map((item) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey[200]!,
                                              width: sale.items.last == item ? 0 : 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.itemName,
                                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                                  ),
                                                  Text(
                                                    '${item.quantity.toStringAsFixed(0)} x ${_currencyFormat.format(item.unitPrice)} TSh',
                                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '${_currencyFormat.format(item.lineTotal)} TSh',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ============ CUSTOMER SELECTOR SCREEN ============

class CustomerSelectorScreen extends StatefulWidget {
  const CustomerSelectorScreen({super.key});

  @override
  State<CustomerSelectorScreen> createState() => _CustomerSelectorScreenState();
}

class _CustomerSelectorScreenState extends State<CustomerSelectorScreen> {
  final ApiService _apiService = ApiService();
  List<Customer> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);

    final response = await _apiService.getCustomers(
      search: _searchQuery.isEmpty ? null : _searchQuery,
      limit: 100,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _customers = response.data!;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Customer'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                _searchQuery = value;
              },
              onSubmitted: (_) => _loadCustomers(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _customers.length,
                    itemBuilder: (context, index) {
                      final customer = _customers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            customer.firstName.isNotEmpty ? customer.firstName[0].toUpperCase() : '?',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                        title: Text(customer.displayName),
                        subtitle: Text(customer.phoneNumber),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, customer),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
