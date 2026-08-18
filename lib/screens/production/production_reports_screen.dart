import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/production_report.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';

/// Menu of the production reports. Each entry opens the same generic viewer --
/// they all return {data, summary, columns}, so the only thing that differs is
/// the endpoint key and whether a raw material has to be picked first.
class ProductionReportsScreen extends StatelessWidget {
  const ProductionReportsScreen({super.key});

  static const List<_ReportEntry> _reports = [
    _ReportEntry('batches', 'Production Batches',
        'Expected vs actual output, efficiency and cost per unit', Icons.inventory_2_outlined),
    _ReportEntry('products', 'Production by Product',
        'Totals grouped by the item produced', Icons.category_outlined),
    _ReportEntry('operators', 'Efficiency by Operator',
        'Which operators hit the expected yield', Icons.people_outline),
    _ReportEntry('variance', 'Standard vs Actual Cost',
        'Where entered expenses differ from the costing rates', Icons.compare_arrows),
    _ReportEntry('expenses', 'Expense Reconciliation',
        'Every shilling: linked to batches, overhead, or unaccounted', Icons.receipt_long_outlined),
    _ReportEntry('lots', 'Sand Lot History',
        'Cost per bag and yield of each lot', Icons.layers_outlined),
    _ReportEntry('material_journey', 'Material Journey',
        'Purchased vs sold vs used, against actual stock', Icons.route_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Production Reports'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _reports.length,
        itemBuilder: (context, i) {
          final r = _reports[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: isDark ? AppColors.darkCard : Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(r.icon, color: AppColors.primary, size: 21),
              ),
              title: Text(r.title,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText)),
              subtitle: Text(r.subtitle,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextLight : Colors.grey[600])),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductionReportViewScreen(
                    reportKey: r.key,
                    title: r.title,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportEntry {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ReportEntry(this.key, this.title, this.subtitle, this.icon);
}

/// Generic viewer: date range, optional material picker, table, summary.
class ProductionReportViewScreen extends StatefulWidget {
  final String reportKey;
  final String title;

  const ProductionReportViewScreen({
    super.key,
    required this.reportKey,
    required this.title,
  });

  @override
  State<ProductionReportViewScreen> createState() => _ProductionReportViewScreenState();
}

class _ProductionReportViewScreenState extends State<ProductionReportViewScreen> {
  final ApiService _apiService = ApiService();
  final _number = NumberFormat('#,##0.##');
  final _dateApi = DateFormat('yyyy-MM-dd');
  final _dateLabel = DateFormat('dd MMM yyyy');

  late DateTimeRange _range;
  ProductionReport? _report;
  List<RawMaterial> _materials = [];
  int? _materialId;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _needsMaterial => widget.reportKey == 'material_journey';

  @override
  void initState() {
    super.initState();
    // Matches the web default (commit af9565e41: last 30 days, not today only).
    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 29)),
      end: now,
    );

    if (_needsMaterial) {
      _loadMaterials();
    } else {
      _load();
    }
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    final response = await _apiService.getProductionRawMaterials();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _materials = response.data!;
        // Auto-select so the report shows something immediately rather than
        // an empty screen with a picker the user has to discover.
        if (_materials.isNotEmpty) _materialId = _materials.first.itemId;
      } else {
        _errorMessage = response.message;
      }
    });

    if (_materialId != null) _load();
  }

  Future<void> _load() async {
    if (_needsMaterial && _materialId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getProductionReport(
      widget.reportKey,
      startDate: _dateApi.format(_range.start),
      endDate: _dateApi.format(_range.end),
      itemId: _needsMaterial ? _materialId : null,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _report = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load();
    }
  }

  /// Column labels arrive already localised from the server; only the values
  /// need formatting, and only when the column declares itself numeric.
  String _cell(Map<String, dynamic> row, ReportColumn column) {
    final value = row[column.field];
    if (value == null || value.toString().isEmpty) return '—';
    if (column.isNumeric) {
      final parsed = value is num ? value.toDouble() : double.tryParse(value.toString());
      if (parsed != null) return _number.format(parsed);
    }
    return value.toString();
  }

  String _humanize(String key) => key
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _summaryValue(dynamic value) {
    if (value == null) return '—';
    final parsed = value is num ? value.toDouble() : double.tryParse(value.toString());
    return parsed != null ? _number.format(parsed) : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControls(isDark),
          Expanded(child: _buildBody(isDark)),
        ],
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurface : Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          InkWell(
            onTap: _pickRange,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                    color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_dateLabel.format(_range.start)}  -  ${_dateLabel.format(_range.end)}',
                      style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? AppColors.darkText : AppColors.lightText),
                    ),
                  ),
                  Icon(Icons.expand_more,
                      size: 18,
                      color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
                ],
              ),
            ),
          ),
          if (_needsMaterial && _materials.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _materialId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Raw material',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _materials
                  .map((m) => DropdownMenuItem(
                        value: m.itemId,
                        child: Text(m.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _materialId = value);
                _load();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark ? AppColors.darkTextLight : Colors.grey[600])),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final report = _report;
    if (report == null) {
      return Center(
        child: Text('Pick a range to run this report',
            style: TextStyle(
                color: isDark ? AppColors.darkTextLight : Colors.grey[600])),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (report.summary.isNotEmpty) _buildSummary(report, isDark),
        const SizedBox(height: 12),
        if (report.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.bar_chart,
                    size: 48, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                const SizedBox(height: 10),
                Text('No rows in this period',
                    style: TextStyle(
                        color: isDark ? AppColors.darkTextLight : Colors.grey[500])),
              ],
            ),
          )
        else
          _buildTable(report, isDark),
      ],
    );
  }

  Widget _buildSummary(ProductionReport report, bool isDark) {
    return Card(
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: report.summary.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(_humanize(entry.key),
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextLight
                                : Colors.grey[600])),
                  ),
                  Text(
                    _summaryValue(entry.value),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Horizontally scrollable: these reports carry up to 13 columns, which no
  /// phone fits. The table scrolls inside itself; the page does not.
  Widget _buildTable(ProductionReport report, bool isDark) {
    return Card(
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 48,
          columnSpacing: 22,
          columns: report.columns
              .map((c) => DataColumn(
                    numeric: c.isNumeric,
                    label: Text(
                      c.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ))
              .toList(),
          rows: report.rows
              .map((row) => DataRow(
                    cells: report.columns
                        .map((c) => DataCell(Text(
                              _cell(row, c),
                              style: const TextStyle(fontSize: 12.5),
                            )))
                        .toList(),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
