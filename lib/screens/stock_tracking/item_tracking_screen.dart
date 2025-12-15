import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/stock_tracking.dart';
import '../../models/stock_location.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';

class ItemTrackingScreen extends StatefulWidget {
  const ItemTrackingScreen({super.key});

  @override
  State<ItemTrackingScreen> createState() => _ItemTrackingScreenState();
}

class _ItemTrackingScreenState extends State<ItemTrackingScreen> {
  final ApiService _apiService = ApiService();
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final TextEditingController _searchController = TextEditingController();

  ItemTrackingReport? _report;
  List<StockLocation> _locations = [];
  List<SimpleItem> _items = [];
  StockLocation? _selectedLocation;
  SimpleItem? _selectedItem;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  bool _isLoadingItems = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final response = await _apiService.getStockTrackingLocations();
    if (response.isSuccess && response.data != null) {
      setState(() {
        _locations = response.data!;
        if (_locations.isNotEmpty) {
          _selectedLocation = _locations.first;
        }
      });
    }
  }

  Future<void> _loadItems({String? search}) async {
    setState(() {
      _isLoadingItems = true;
    });

    final response = await _apiService.getStockItems(search: search, limit: 100);
    if (response.isSuccess && response.data != null) {
      setState(() {
        _items = response.data!;
        _isLoadingItems = false;
      });
    } else {
      setState(() {
        _isLoadingItems = false;
      });
    }
  }

  Future<void> _loadReport() async {
    if (_selectedLocation == null || _selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an item and location')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    final response = await _apiService.getItemTracking(
      startDate: startDateStr,
      endDate: endDateStr,
      itemId: _selectedItem!.itemId,
      stockLocationId: _selectedLocation!.locationId,
    );

    if (response.isSuccess && response.data != null) {
      setState(() {
        _report = response.data;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response.message ?? 'Failed to load item tracking';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      if (_selectedItem != null) {
        _loadReport();
      }
    }
  }

  void _showItemSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemSelectorSheet(
        selectedItem: _selectedItem,
        apiService: _apiService,
        onSelect: (item) {
          setState(() {
            _selectedItem = item;
          });
          Navigator.pop(context);
          _loadReport();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [AppColors.lightBackground, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              _buildFilters(isDark),
              Expanded(
                child: _isLoading
                    ? _buildSkeletonList(isDark)
                    : _errorMessage != null
                        ? _buildError(isDark)
                        : _report == null
                            ? _buildEmpty(isDark)
                            : _buildContent(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Item Tracking',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Item Selector
          GestureDetector(
            onTap: _showItemSelector,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    size: 20,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedItem?.displayName ?? 'Select Item',
                      style: TextStyle(
                        color: _selectedItem != null
                            ? (isDark ? AppColors.darkText : AppColors.text)
                            : (isDark ? AppColors.darkTextLight : AppColors.textLight),
                        fontWeight: _selectedItem != null ? FontWeight.w500 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Date Range Picker
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 18,
                          color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd').format(_endDate)}',
                            style: TextStyle(
                              color: isDark ? AppColors.darkText : AppColors.text,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Location Dropdown
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.1),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<StockLocation>(
                      value: _selectedLocation,
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                      items: _locations.map((location) {
                        return DropdownMenuItem<StockLocation>(
                          value: location,
                          child: Text(
                            location.locationName,
                            style: TextStyle(
                              color: isDark ? AppColors.darkText : AppColors.text,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLocation = value;
                        });
                        if (_selectedItem != null) {
                          _loadReport();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'Select an item to view tracking history',
            style: TextStyle(
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Info Card
            _buildItemInfoCard(isDark),
            const SizedBox(height: 16),

            // Balances Card
            _buildBalancesCard(isDark),
            const SizedBox(height: 16),

            // Transactions Table
            _buildTransactionsSection(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildItemInfoCard(bool isDark) {
    final item = _report!.item;
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                      if (item.itemNumber != null && item.itemNumber!.isNotEmpty)
                        Text(
                          '#${item.itemNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildItemInfoChip(isDark, 'Category', item.category ?? 'N/A'),
                const SizedBox(width: 8),
                _buildItemInfoChip(isDark, 'Cost', _currencyFormat.format(item.costPrice)),
                const SizedBox(width: 8),
                _buildItemInfoChip(isDark, 'Price', _currencyFormat.format(item.unitPrice)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemInfoChip(bool isDark, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancesCard(bool isDark) {
    final balances = _report!.balances;
    return Row(
      children: [
        Expanded(
          child: _buildBalanceCard(
            isDark: isDark,
            title: 'Opening',
            value: balances.opening,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildBalanceCard(
            isDark: isDark,
            title: 'Closing',
            value: balances.closing,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildBalanceCard(
            isDark: isDark,
            title: 'Available',
            value: balances.available,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard({
    required bool isDark,
    required String title,
    required double value,
    required Color color,
  }) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatNumber(value),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsSection(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.history, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Transactions (${_report!.transactions.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          if (_report!.transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No transactions found for this period',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 16,
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 56,
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
                dataTextStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Employee')),
                  DataColumn(label: Text('In'), numeric: true),
                  DataColumn(label: Text('Out'), numeric: true),
                  DataColumn(label: Text('Balance'), numeric: true),
                  DataColumn(label: Text('Event')),
                  DataColumn(label: Text('Customer/Supplier')),
                ],
                rows: _report!.transactions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final trans = entry.value;
                  return DataRow(
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(Text(_formatDate(trans.date))),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: Text(
                            trans.employee,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(
                        trans.inQuantity > 0 ? _formatNumber(trans.inQuantity) : '-',
                        style: TextStyle(
                          color: trans.inQuantity > 0 ? Colors.green : null,
                          fontWeight: trans.inQuantity > 0 ? FontWeight.bold : null,
                        ),
                      )),
                      DataCell(Text(
                        trans.outQuantity > 0 ? _formatNumber(trans.outQuantity) : '-',
                        style: TextStyle(
                          color: trans.outQuantity > 0 ? Colors.red : null,
                          fontWeight: trans.outQuantity > 0 ? FontWeight.bold : null,
                        ),
                      )),
                      DataCell(Text(_formatNumber(trans.balance))),
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: Text(
                            trans.event,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: Text(
                            trans.customerSupplier,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildSkeletonList(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary cards skeleton
          Row(
            children: [
              Expanded(child: _buildSkeletonSummaryCard(isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildSkeletonSummaryCard(isDark)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSkeletonSummaryCard(isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildSkeletonSummaryCard(isDark)),
            ],
          ),
          const SizedBox(height: 16),
          // History skeletons
          ...List.generate(6, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSkeletonHistoryCard(isDark),
          )),
        ],
      ),
    );
  }

  Widget _buildSkeletonSummaryCard(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonLoader(width: 32, height: 32, borderRadius: 8, isDark: isDark),
                const SizedBox(width: 8),
                SkeletonLoader(width: 60, height: 10, isDark: isDark),
              ],
            ),
            const SizedBox(height: 8),
            SkeletonLoader(width: 80, height: 18, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonHistoryCard(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SkeletonLoader(width: 36, height: 36, borderRadius: 8, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 100, height: 14, isDark: isDark),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: 80, height: 12, isDark: isDark),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SkeletonLoader(width: 60, height: 14, isDark: isDark),
                const SizedBox(height: 4),
                SkeletonLoader(width: 40, height: 12, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemSelectorSheet extends StatefulWidget {
  final SimpleItem? selectedItem;
  final ApiService apiService;
  final Function(SimpleItem) onSelect;

  const _ItemSelectorSheet({
    this.selectedItem,
    required this.apiService,
    required this.onSelect,
  });

  @override
  State<_ItemSelectorSheet> createState() => _ItemSelectorSheetState();
}

class _ItemSelectorSheetState extends State<_ItemSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<SimpleItem> _items = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadItems({String? search}) async {
    setState(() {
      _isLoading = true;
    });

    final response = await widget.apiService.getStockItems(search: search, limit: 100);
    if (mounted && response.isSuccess && response.data != null) {
      setState(() {
        _items = response.data!;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _loadItems(search: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          'No items found',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final isSelected = widget.selectedItem?.itemId == item.itemId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? AppColors.primary
                                  : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                              child: Icon(
                                Icons.inventory_2,
                                color: isSelected ? Colors.white : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isDark ? AppColors.darkText : AppColors.text,
                              ),
                            ),
                            subtitle: Text(
                              item.itemNumber != null ? '#${item.itemNumber}' : (item.category ?? ''),
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: AppColors.primary)
                                : null,
                            onTap: () => widget.onSelect(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
