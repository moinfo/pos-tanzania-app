import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/report.dart';
import '../../models/stock_location.dart';
import '../../services/api_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/location_provider.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';

class ReportViewScreen extends StatefulWidget {
  final ReportType reportType;

  const ReportViewScreen({
    super.key,
    required this.reportType,
  });

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  ReportData? _reportData;
  GraphicalReportData? _graphicalData;

  // Filter state - default from first day of current month to today
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;
    final locationProvider = context.read<LocationProvider>();
    print('📍 [Reports] Before initialize - locations: ${locationProvider.allowedLocations.length}, selected: ${locationProvider.selectedLocation?.locationName}');
    // Initialize with sales permissions (reports don't have their own location permission)
    await locationProvider.initialize(moduleId: 'sales');
    print('📍 [Reports] After initialize - locations: ${locationProvider.allowedLocations.length}, selected: ${locationProvider.selectedLocation?.locationName}');
    // Load report after location is initialized
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      // Check if this is a graphical report
      if (_isGraphicalReport(widget.reportType)) {
        await _loadGraphicalReport(startDateStr, endDateStr);
      } else {
        await _loadTableReport(startDateStr, endDateStr);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load report: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  bool _isGraphicalReport(ReportType type) {
    return type == ReportType.graphicalSales ||
        type == ReportType.graphicalItems ||
        type == ReportType.graphicalCategories;
  }

  Future<void> _loadTableReport(String startDate, String endDate) async {
    final locationProvider = context.read<LocationProvider>();
    final selectedLocationId = locationProvider.selectedLocation?.locationId;

    final response = await _apiService.getReport(
      widget.reportType,
      startDate: startDate,
      endDate: endDate,
      locationId: selectedLocationId,
    );

    if (mounted) {
      if (response.isSuccess) {
        setState(() {
          _reportData = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.message ?? 'Failed to load report';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadGraphicalReport(String startDate, String endDate) async {
    final locationProvider = context.read<LocationProvider>();
    final selectedLocationId = locationProvider.selectedLocation?.locationId;

    String graphType;
    switch (widget.reportType) {
      case ReportType.graphicalSales:
        graphType = 'sales';
        break;
      case ReportType.graphicalItems:
        graphType = 'items';
        break;
      case ReportType.graphicalCategories:
        graphType = 'categories';
        break;
      default:
        graphType = 'sales';
    }

    final response = await _apiService.getGraphicalReport(
      graphType,
      startDate: startDate,
      endDate: endDate,
      locationId: selectedLocationId,
    );

    if (mounted) {
      if (response.isSuccess) {
        setState(() {
          _graphicalData = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.message ?? 'Failed to load graphical report';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final isDark = context.read<ThemeProvider>().isDarkMode;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.darkSurface,
                    onSurface: AppColors.darkText,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppColors.text,
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
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final locationProvider = context.watch<LocationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reportType.displayName),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Date range selector
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
            tooltip: 'Refresh',
          ),
        ],
      ),
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
        child: Column(
          children: [
            // Date range display
            _buildDateRangeHeader(isDark),

            // Report content
            Expanded(
              child: _isLoading
                  ? _buildSkeletonList(isDark)
                  : _error != null
                      ? _buildErrorView(isDark)
                      : _isGraphicalReport(widget.reportType)
                          ? _buildGraphicalReport(isDark)
                          : _buildTableReport(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeHeader(bool isDark) {
    final locationProvider = context.watch<LocationProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark
          ? AppColors.darkSurface
          : AppColors.primary.withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _startDate == _endDate
                  ? DateFormat('MMMM dd, yyyy').format(_startDate)
                  : '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.text,
              ),
            ),
          ),
          if (locationProvider.selectedLocation != null)
            PopupMenuButton<StockLocation>(
              offset: const Offset(0, 30),
              color: isDark ? AppColors.darkCard : Colors.white,
              onSelected: (location) async {
                await locationProvider.selectLocation(location);
                _loadReport();
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
                                  ? AppColors.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              location.locationName,
                              style: TextStyle(
                                color: location.locationId == locationProvider.selectedLocation?.locationId
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkText : Colors.black87),
                                fontWeight: location.locationId == locationProvider.selectedLocation?.locationId
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      locationProvider.selectedLocation!.locationName,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReport,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableReport(bool isDark) {
    if (_reportData == null || _reportData!.rows.isEmpty) {
      return _buildEmptyView(isDark);
    }

    return Column(
      children: [
        // Totals summary (if available)
        if (_reportData!.totals != null && _reportData!.totals!.isNotEmpty)
          _buildTotalsSummary(isDark),

        // Data table
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildDataTable(isDark),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalsSummary(bool isDark) {
    final totals = _reportData!.totals!;
    final columns = _reportData!.columns;

    // Get totals that match column keys
    final displayTotals = <String, dynamic>{};
    for (var column in columns) {
      if (totals.containsKey(column.key)) {
        displayTotals[column.label] = totals[column.key];
      }
    }

    if (displayTotals.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16.0),
      child: GlassmorphicCard(
        isDark: isDark,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.summarize,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: displayTotals.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatValue(entry.value, 'currency'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(bool isDark) {
    final columns = _reportData!.columns;
    final rows = _reportData!.rows;

    // Check if this is a suppliers report (has receiving_id column)
    final isSupplierReport = widget.reportType == ReportType.summarySuppliers;

    // Calculate totals for currency and number columns
    final Map<String, double> totals = {};
    for (var column in columns) {
      if (column.type == 'currency' || column.type == 'number') {
        double sum = 0;
        for (var row in rows) {
          final value = row[column.key];
          if (value != null) {
            sum += value is num ? value.toDouble() : (double.tryParse(value.toString()) ?? 0);
          }
        }
        totals[column.key] = sum;
      }
    }

    // Build data rows including footer total row
    final dataRows = <DataRow>[
      // Regular data rows
      ...rows.map((row) {
        final receivingId = row['receiving_id'];
        return DataRow(
          // Make row tappable for supplier reports
          onSelectChanged: isSupplierReport && receivingId != null
              ? (_) => _showReceivingItems(receivingId, isDark)
              : null,
          cells: columns.map((column) {
            final value = row[column.key];
            return DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatValue(value, column.type),
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.text,
                      fontWeight: column.type == 'currency'
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                  // Add view icon for first column in supplier report
                  if (isSupplierReport && column.key == 'receiving_id')
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.visibility,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      }),
      // Footer total row
      DataRow(
        color: WidgetStateProperty.all(
          isDark ? AppColors.darkCard : AppColors.primary.withOpacity(0.15),
        ),
        cells: columns.asMap().entries.map((entry) {
          final index = entry.key;
          final column = entry.value;

          // First column shows "Total" label
          if (index == 0) {
            return DataCell(
              Text(
                'Total',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
              ),
            );
          }

          // Show total for currency/number columns
          if (totals.containsKey(column.key)) {
            return DataCell(
              Text(
                _formatValue(totals[column.key], column.type),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            );
          }

          // Empty cell for non-numeric columns
          return DataCell(
            Text(
              '-',
              style: TextStyle(
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
          );
        }).toList(),
      ),
    ];

    return DataTable(
      showCheckboxColumn: false, // Hide checkboxes for selectable rows
      headingRowColor: WidgetStateProperty.all(
        isDark ? AppColors.darkCard : AppColors.primary.withOpacity(0.1),
      ),
      dataRowColor: WidgetStateProperty.all(
        isDark ? AppColors.darkSurface : Colors.white,
      ),
      border: TableBorder.all(
        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        width: 1,
        borderRadius: BorderRadius.circular(8),
      ),
      columns: columns.map((column) {
        return DataColumn(
          label: Text(
            column.label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
        );
      }).toList(),
      rows: dataRows,
    );
  }

  /// Show receiving items in a dialog
  Future<void> _showReceivingItems(dynamic receivingId, bool isDark) async {
    final id = receivingId is int ? receivingId : int.tryParse(receivingId.toString()) ?? 0;
    if (id == 0) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final response = await _apiService.getReceivingItems(id);

    Navigator.of(context).pop(); // Close loading dialog

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final items = response.data!;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          title: Row(
            children: [
              Icon(Icons.inventory, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Receiving #$id Items',
                style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: items.isEmpty
                ? Text(
                    'No items found',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        color: isDark ? AppColors.darkSurface : Colors.grey[50],
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['item_name']?.toString() ?? 'Unknown Item',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? AppColors.darkText : AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (item['category'] != null)
                                Text(
                                  'Category: ${item['category']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Qty: ${item['quantity'] ?? item['quantity_purchased'] ?? 0}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? AppColors.darkText : AppColors.text,
                                    ),
                                  ),
                                  Text(
                                    'Price: ${Formatters.formatCurrency(_parseDouble(item['unit_price'] ?? item['item_unit_price']))}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              if (item['subtotal'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Subtotal: ${Formatters.formatCurrency(_parseDouble(item['subtotal']))}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Failed to load items'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    return value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
  }

  String _formatValue(dynamic value, String type) {
    if (value == null) return '-';

    switch (type) {
      case 'currency':
        final numValue = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
        return Formatters.formatCurrency(numValue);
      case 'number':
        final numValue = value is num ? value : num.tryParse(value.toString()) ?? 0;
        return NumberFormat('#,##0.##').format(numValue);
      case 'percent':
        final numValue = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
        return '${numValue.toStringAsFixed(2)}%';
      case 'date':
        return Formatters.formatDate(value.toString());
      default:
        return value.toString();
    }
  }

  Widget _buildGraphicalReport(bool isDark) {
    if (_graphicalData == null) {
      return _buildEmptyView(isDark);
    }

    final chartData = _graphicalData!.chartData;
    final summary = _graphicalData!.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          if (summary.isNotEmpty)
            _buildGraphicalSummary(isDark, summary),

          const SizedBox(height: 16),

          // Chart placeholder (charts would need fl_chart package)
          GlassmorphicCard(
            isDark: isDark,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bar_chart,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Chart Data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Simple bar representation (for now)
                if (chartData.datasets.isNotEmpty)
                  ...chartData.datasets.first.data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final value = entry.value;
                    final label = index < chartData.labels.length
                        ? chartData.labels[index]
                        : 'Item ${index + 1}';
                    final maxValue = chartData.datasets.first.data
                        .reduce((a, b) => a > b ? a : b);
                    final percentage = maxValue > 0 ? (value / maxValue) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.darkText
                                        : AppColors.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                Formatters.formatCurrency(value),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: isDark
                                ? AppColors.darkDivider
                                : AppColors.lightDivider,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphicalSummary(bool isDark, Map<String, dynamic> summary) {
    return GlassmorphicCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: summary.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatSummaryKey(entry.key),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextLight
                            : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.value is num
                          ? Formatters.formatCurrency(entry.value.toDouble())
                          : entry.value.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatSummaryKey(String key) {
    // Convert snake_case to Title Case
    return key
        .split('_')
        .map((word) => word.isEmpty
            ? ''
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assessment_outlined,
            size: 64,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No data available',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting the date range or filters',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            label: const Text('Change Date Range'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary section skeleton
          GlassmorphicCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SkeletonLoader(width: 100, height: 12, isDark: isDark),
                  const SizedBox(height: 8),
                  SkeletonLoader(width: 150, height: 28, isDark: isDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Table/List skeleton
          GlassmorphicCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(8, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SkeletonLoader(width: 36, height: 36, borderRadius: 8, isDark: isDark),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(width: 120, height: 14, isDark: isDark),
                            const SizedBox(height: 6),
                            SkeletonLoader(width: 80, height: 10, isDark: isDark),
                          ],
                        ),
                      ),
                      SkeletonLoader(width: 70, height: 16, isDark: isDark),
                    ],
                  ),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
