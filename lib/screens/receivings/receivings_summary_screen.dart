import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/receiving_summary.dart';
import '../../models/stock_location.dart';
import '../../providers/location_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/skeleton_loader.dart';

class ReceivingsSummaryScreen extends StatefulWidget {
  const ReceivingsSummaryScreen({super.key});

  @override
  State<ReceivingsSummaryScreen> createState() => _ReceivingsSummaryScreenState();
}

class _ReceivingsSummaryScreenState extends State<ReceivingsSummaryScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String? _errorMessage;

  ReceivingSummaryResponse? _summaryData;

  // Date range filter
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Set default date range to today
    _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
    _endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);
  }

  Future<void> _loadSummary() async {
    final locationProvider = context.read<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;

    if (selectedLocation == null) {
      setState(() {
        _errorMessage = 'Please select a stock location';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getReceivingSummary(
        locationId: selectedLocation.locationId,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _summaryData = ReceivingSummaryResponse.fromJson(response.data!);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Failed to load summary';
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

  Future<void> _selectDateRange() async {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: AppColors.success,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                    secondary: AppColors.success,
                    onSecondary: Colors.white,
                    surfaceContainerHighest: const Color(0xFF2D2D2D),
                  ),
                  dialogBackgroundColor: const Color(0xFF1E1E1E),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.success,
                    ),
                  ),
                  datePickerTheme: DatePickerThemeData(
                    backgroundColor: const Color(0xFF1E1E1E),
                    headerBackgroundColor: AppColors.success,
                    headerForegroundColor: Colors.white,
                    dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      if (states.contains(WidgetState.disabled)) {
                        return Colors.grey.shade600;
                      }
                      return Colors.white;
                    }),
                    dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.success;
                      }
                      return null;
                    }),
                    todayForegroundColor: WidgetStateProperty.all(AppColors.success),
                    todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
                    yearForegroundColor: WidgetStateProperty.all(Colors.white),
                    rangePickerBackgroundColor: const Color(0xFF1E1E1E),
                    rangePickerHeaderBackgroundColor: AppColors.success,
                    rangePickerHeaderForegroundColor: Colors.white,
                    rangeSelectionBackgroundColor: AppColors.success.withOpacity(0.3),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppColors.success,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                    secondary: AppColors.success,
                  ),
                  datePickerTheme: DatePickerThemeData(
                    headerBackgroundColor: AppColors.success,
                    headerForegroundColor: Colors.white,
                    rangeSelectionBackgroundColor: AppColors.success.withOpacity(0.2),
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
    }
  }

  String _formatDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endDay = DateTime(_endDate.year, _endDate.month, _endDate.day);

    if (startDay == today && endDay == today) {
      return 'Today';
    } else if (startDay == endDay) {
      return DateFormat('dd MMM yyyy').format(_startDate);
    } else {
      return '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}';
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return 'Tshs${formatter.format(amount)}';
  }

  String _formatQuantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.success,
        foregroundColor: Colors.white,
        actions: [
          // Location selector
          if (locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 140),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PopupMenuButton<StockLocation>(
                  offset: const Offset(0, 40),
                  color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          locationProvider.selectedLocation!.locationName,
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
                    ],
                  ),
                  onSelected: (location) async {
                    await locationProvider.selectLocation(location);
                    setState(() {
                      _summaryData = null;
                    });
                  },
                  itemBuilder: (context) => locationProvider.allowedLocations
                      .map((location) => PopupMenuItem<StockLocation>(
                            value: location,
                            child: Text(
                              location.locationName,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
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
          // Date Range Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isDark ? AppColors.darkSurface : AppColors.success,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: AppColors.success, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            _formatDateRange(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkText : AppColors.success,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_drop_down, color: AppColors.success),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _loadSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Content
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
                              onPressed: _loadSummary,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _summaryData == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Select date range and tap Search',
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : _summaryData!.items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No data found',
                                      style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try a different date range',
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              )
                            : _buildDataTable(isDark),
          ),

          // Totals Footer
          if (_summaryData != null && _summaryData!.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${_summaryData!.items.length} items',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Qty Diff: ${_formatQuantity(_summaryData!.totals.totalDifferentQuantity)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Price Diff: ${_formatCurrency(_summaryData!.totals.totalDifferentPrice)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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

  Widget _buildDataTable(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            isDark ? AppColors.darkCard : Colors.blueGrey.shade700,
          ),
          headingTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          dataTextStyle: TextStyle(
            color: isDark ? AppColors.darkText : Colors.black87,
            fontSize: 12,
          ),
          columnSpacing: 16,
          horizontalMargin: 12,
          columns: const [
            DataColumn(label: Text('Item Name')),
            DataColumn(label: Text('Mainstore\nQty'), numeric: true),
            DataColumn(label: Text('Leruma\nQty'), numeric: true),
            DataColumn(label: Text('Diff\nQty'), numeric: true),
            DataColumn(label: Text('Mainstore\nPrice'), numeric: true),
            DataColumn(label: Text('Leruma\nReceiving'), numeric: true),
            DataColumn(label: Text('Diff\nPrice'), numeric: true),
          ],
          rows: _summaryData!.items.map((item) {
            final hasQtyDiff = item.differentQuantity > 0;
            final hasPriceDiff = item.differentPrice > 0;

            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      item.itemName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
                DataCell(Text(_formatQuantity(item.mainstoreQuantity))),
                DataCell(Text(_formatQuantity(item.lerumaQuantity))),
                DataCell(
                  Text(
                    _formatQuantity(item.differentQuantity),
                    style: TextStyle(
                      color: hasQtyDiff ? AppColors.error : null,
                      fontWeight: hasQtyDiff ? FontWeight.bold : null,
                    ),
                  ),
                ),
                DataCell(Text(_formatCurrency(item.mainstorePrice))),
                DataCell(Text(_formatCurrency(item.lerumaReceiving))),
                DataCell(
                  Text(
                    _formatCurrency(item.differentPrice),
                    style: TextStyle(
                      color: hasPriceDiff ? AppColors.error : null,
                      fontWeight: hasPriceDiff ? FontWeight.bold : null,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          8,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SkeletonLoader(width: double.infinity, height: 16, isDark: isDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SkeletonLoader(width: double.infinity, height: 16, isDark: isDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SkeletonLoader(width: double.infinity, height: 16, isDark: isDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SkeletonLoader(width: double.infinity, height: 16, isDark: isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
