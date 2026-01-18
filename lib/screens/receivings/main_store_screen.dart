import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/receiving.dart';
import '../../providers/location_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/skeleton_loader.dart';
import 'new_receiving_screen.dart';

class MainStoreScreen extends StatefulWidget {
  const MainStoreScreen({super.key});

  @override
  State<MainStoreScreen> createState() => _MainStoreScreenState();
}

class _MainStoreScreenState extends State<MainStoreScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String? _errorMessage;

  MainStoreData? _mainStoreData;

  // Selected date for filtering
  DateTime _selectedDate = DateTime.now();

  // Track expanded sales
  final Set<int> _expandedSales = {};

  @override
  void initState() {
    super.initState();
    // Load data after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMainStore();
    });
  }

  Future<void> _loadMainStore() async {
    final locationProvider = context.read<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getMainStore(
        locationId: selectedLocation?.locationId,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _mainStoreData = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Failed to load main store data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleSaleExpanded(int saleId) {
    setState(() {
      if (_expandedSales.contains(saleId)) {
        _expandedSales.remove(saleId);
      } else {
        _expandedSales.add(saleId);
      }
    });
  }

  Future<void> _selectDate() async {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadMainStore();
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return '${formatter.format(amount)} TSh';
  }

  String _formatTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('HH:mm:ss').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  void _navigateToReceivingWithItems(List<MainStoreSaleItem> items) {
    // Convert main store items to receiving items format
    final receivingItems = items.map((item) => ReceivingItem(
      itemId: item.itemId,
      itemName: item.itemName,
      itemNumber: item.itemNumber,
      line: 0,
      quantity: item.quantity,
      costPrice: item.lerumaUnitPrice, // Use leruma price as cost
      unitPrice: item.lerumaUnitPrice,
    )).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewReceivingScreen(
          preloadedItems: receivingItems,
        ),
      ),
    ).then((_) => _loadMainStore());
  }

  void _copyAllToCart() {
    if (_mainStoreData == null || _mainStoreData!.sales.isEmpty) return;

    final allItems = <MainStoreSaleItem>[];
    for (final sale in _mainStoreData!.sales) {
      allItems.addAll(sale.items);
    }

    _navigateToReceivingWithItems(allItems);
  }

  void _copySaleToCart(MainStoreSale sale) {
    _navigateToReceivingWithItems(sale.items);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Store (MS)'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMainStore,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Compact header with filters
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Location and Date row
                Row(
                  children: [
                    // Location selector
                    Expanded(
                      flex: 3,
                      child: PopupMenuButton<int>(
                        offset: const Offset(0, 40),
                        color: Colors.white,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.store, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _mainStoreData?.locationName ??
                                      locationProvider.selectedLocation?.locationName ??
                                      'Location',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 20, color: Colors.white70),
                            ],
                          ),
                        ),
                        onSelected: (locationId) async {
                          final location = locationProvider.allowedLocations
                              .firstWhere((l) => l.locationId == locationId);
                          await locationProvider.selectLocation(location);
                          _loadMainStore();
                        },
                        itemBuilder: (context) => locationProvider.allowedLocations
                            .map((location) => PopupMenuItem<int>(
                                  value: location.locationId,
                                  child: Text(location.locationName),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Date picker
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('dd MMM').format(_selectedDate),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Summary stats row
                if (_mainStoreData != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildCompactStat(
                        icon: Icons.check_circle_outline,
                        value: '${_mainStoreData!.summary.matchCount}',
                        label: 'Match',
                        color: Colors.greenAccent,
                      ),
                      const SizedBox(width: 12),
                      _buildCompactStat(
                        icon: Icons.warning_amber_rounded,
                        value: '${_mainStoreData!.summary.mismatchCount}',
                        label: 'Mismatch',
                        color: Colors.orangeAccent,
                      ),
                      const SizedBox(width: 12),
                      _buildCompactStat(
                        icon: Icons.receipt_long,
                        value: '${_mainStoreData!.summary.totalSales}',
                        label: 'Sales',
                        color: Colors.white,
                      ),
                      const Spacer(),
                      // Total amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(_mainStoreData!.summary.grandTotal),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Qty: ${_mainStoreData!.summary.totalQuantity.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
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

          // Copy All button - compact design
          if (_mainStoreData != null && _mainStoreData!.sales.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Material(
                color: isDark ? Colors.green.shade800 : Colors.green.shade600,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _copyAllToCart,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Copy All to Cart',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_mainStoreData!.summary.totalSales} sales · ${_mainStoreData!.summary.totalQuantity.toStringAsFixed(0)} items',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Sales list
          Expanded(
            child: _isLoading
                ? _buildSkeletonList(isDark)
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadMainStore,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _mainStoreData == null || _mainStoreData!.sales.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No sales found for today',
                                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try selecting a different location',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadMainStore,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _mainStoreData!.sales.length,
                              itemBuilder: (context, index) {
                                final sale = _mainStoreData!.sales[index];
                                return _buildSaleCard(sale, isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildCompactStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSaleCard(MainStoreSale sale, bool isDark) {
    final isExpanded = _expandedSales.contains(sale.saleId);
    final matchCount = sale.items.where((i) => i.isMatch).length;
    final mismatchCount = sale.items.where((i) => i.isMismatch).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sale header - compact
          InkWell(
            onTap: () => _toggleSaleExpanded(sale.saleId),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Left: Sale info
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.primary : AppColors.primary).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '#${sale.saleId}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sale.customerName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDark ? AppColors.darkText : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTime(sale.saleTime),
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: matchCount > 0 && mismatchCount == 0
                                          ? Colors.green.shade50
                                          : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${sale.items.length} items',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: matchCount > 0 && mismatchCount == 0
                                            ? Colors.green.shade700
                                            : Colors.orange.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right: Amount and expand
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(sale.saleTotal),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.success,
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded content - cleaner items list
          if (isExpanded) ...[
            Divider(height: 1, color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
            // Items list
            ...sale.items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: item.isMismatch
                      ? (isDark ? Colors.orange.withOpacity(0.08) : Colors.orange.shade50)
                      : null,
                ),
                child: Row(
                  children: [
                    // Status icon
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: item.isMatch
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        item.isMatch ? Icons.check : Icons.warning_amber_rounded,
                        size: 14,
                        color: item.isMatch ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Item details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkText : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'MS: ${NumberFormat('#,##0').format(item.mainstoreUnitPrice)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'LR: ${NumberFormat('#,##0').format(item.lerumaUnitPrice)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Quantity
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'x${item.quantity.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkText : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Copy to cart button - subtle
            Padding(
              padding: const EdgeInsets.all(10),
              child: OutlinedButton.icon(
                onPressed: () => _copySaleToCart(sale),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                  minimumSize: const Size(double.infinity, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text('Copy to Cart', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: isDark ? AppColors.darkCard : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonLoader(width: 100, height: 16, isDark: isDark),
                  SkeletonLoader(width: 60, height: 16, isDark: isDark),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonLoader(width: 120, height: 14, isDark: isDark),
                  SkeletonLoader(width: 80, height: 14, isDark: isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
