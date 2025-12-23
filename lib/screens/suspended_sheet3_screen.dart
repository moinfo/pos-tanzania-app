import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../models/suspended_sheet3.dart';
import '../models/stock_location.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import '../widgets/skeleton_loader.dart';

/// Full Receipt Sheet Screen (Sheet3)
/// Shows suspended sales WITH prices AND free items from offers
class SuspendedSheet3Screen extends StatefulWidget {
  const SuspendedSheet3Screen({super.key});

  @override
  State<SuspendedSheet3Screen> createState() => _SuspendedSheet3ScreenState();
}

class _SuspendedSheet3ScreenState extends State<SuspendedSheet3Screen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  List<SuspendedSheet3Sale> _sales = [];
  List<SuspendedSheet3Sale> _filteredSales = [];
  bool _isLoading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  // Use app brand colors
  static const Color _headerColor = AppColors.primary;
  static const Color _headerColorDark = AppColors.primaryDark;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterSales);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSales() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSales = List.from(_sales);
      } else {
        _filteredSales = List.from(_sales);
        _filteredSales.sort((a, b) {
          final aMatches = a.customerName.toLowerCase().contains(query) ||
              (a.customerPhone?.contains(query) ?? false) ||
              a.items.any((item) => item.itemName.toLowerCase().contains(query));
          final bMatches = b.customerName.toLowerCase().contains(query) ||
              (b.customerPhone?.contains(query) ?? false) ||
              b.items.any((item) => item.itemName.toLowerCase().contains(query));

          if (aMatches && !bMatches) return -1;
          if (!aMatches && bMatches) return 1;
          return 0;
        });
      }
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
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

    final response = await _apiService.getSuspendedSheet3(locationId: locationId);

    if (response.isSuccess && response.data != null) {
      setState(() {
        _sales = response.data!;
        _filteredSales = _sales;
        _isLoading = false;
      });
      _filterSales();
    } else {
      setState(() {
        _isLoading = false;
        _error = response.message;
      });
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
        title: const Text('Receipt Sheet', style: TextStyle(fontSize: 18)),
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
        // Search and Date Filter Bar
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
          child: Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search customer or item...',
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
              ),
              const SizedBox(width: 8),
              // Date picker button
              Material(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: _headerColor),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd/MM').format(_selectedDate),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                  : _filteredSales.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No results found'
                                    : 'No pending receipts',
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
                            itemCount: _filteredSales.length,
                            itemBuilder: (context, index) => _buildSaleCard(_filteredSales[index], index + 1, isDark),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildSaleCard(SuspendedSheet3Sale sale, int number, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 2 : 3,
      color: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with brand color gradient
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_headerColor, _headerColorDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
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
                // Customer name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.customerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.phone, size: 12, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                '0${sale.customerPhone}',
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
                // Receipt icon
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: _headerColor,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Items table (WITH prices and Free column)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text('#', style: _headerStyle(isDark)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('Item', style: _headerStyle(isDark)),
                      ),
                      SizedBox(
                        width: 35,
                        child: Text('Qty', style: _headerStyle(isDark), textAlign: TextAlign.right),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text('Free', style: _headerStyle(isDark), textAlign: TextAlign.right),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text('Total', style: _headerStyle(isDark), textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Table rows
                ...sale.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${idx + 1}',
                            style: _cellStyle(isDark),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            item.itemName,
                            style: _cellStyle(isDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 35,
                          child: Text(
                            item.quantity.toStringAsFixed(0),
                            style: _cellStyle(isDark),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: item.freeQuantity > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${item.freeQuantity}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : Text(
                                  '-',
                                  style: _cellStyle(isDark),
                                  textAlign: TextAlign.right,
                                ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            _currencyFormat.format(item.lineTotal),
                            style: _cellStyle(isDark),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                // Total row
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '${_currencyFormat.format(sale.saleTotal)} TSh',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _headerColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Comment if any
          if (sale.comment != null && sale.comment!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border(
                  left: BorderSide(color: Colors.amber.shade700, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.comment, size: 14, color: Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sale.comment!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Date info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  sale.formattedTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Signature section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kama Mzigo uliopokea ni Sahihi saini hapa',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Receiver Name: ____________________',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Signature:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(top: 20),
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer with Print, PDF, and Download buttons
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${sale.items.length} items',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.print,
                      label: 'Print',
                      color: _headerColor,
                      onTap: () => _printCard(sale),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.picture_as_pdf,
                      label: 'PDF',
                      color: Colors.red.shade600,
                      onTap: () => _exportPdf(sale),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.download,
                      label: 'Download',
                      color: Colors.green.shade600,
                      onTap: () => _downloadPdf(sale),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
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

  Future<void> _printCard(SuspendedSheet3Sale sale) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preparing to print ${sale.customerName}...'),
          duration: const Duration(seconds: 1),
        ),
      );

      await PdfService.printSheet3(sale);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _exportPdf(SuspendedSheet3Sale sale) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generating PDF for ${sale.customerName}...'),
          duration: const Duration(seconds: 1),
        ),
      );

      await PdfService.shareSheet3Pdf(sale);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _downloadPdf(SuspendedSheet3Sale sale) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading PDF for ${sale.customerName}...'),
          duration: const Duration(seconds: 1),
        ),
      );

      await PdfService.downloadSheet3Pdf(sale);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF ready! Choose where to save it.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  TextStyle _headerStyle(bool isDark) {
    return TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      letterSpacing: 0.5,
    );
  }

  TextStyle _cellStyle(bool isDark) {
    return TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white : Colors.black87,
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
              const SizedBox(height: 12),
              SkeletonLoader(width: 100, height: 20, borderRadius: 4, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}