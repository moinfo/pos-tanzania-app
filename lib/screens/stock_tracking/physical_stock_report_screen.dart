import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/physical_stock.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

/// Physical Stock Report (mobile version of web /items/physical_stock_report).
/// Shows the latest count per (week, item, location) for a month, grouped by
/// week, with surplus/shortage/matched summary and month/week/location filters.
class PhysicalStockReportScreen extends StatefulWidget {
  const PhysicalStockReportScreen({super.key});

  @override
  State<PhysicalStockReportScreen> createState() =>
      _PhysicalStockReportScreenState();
}

class _PhysicalStockReportScreenState extends State<PhysicalStockReportScreen> {
  final ApiService _apiService = ApiService();

  PhysicalStockReport? _report;
  bool _isLoading = true;
  String? _error;

  String? _month; // YYYY-MM, null = current month
  String _week = 'all'; // 'all' or '1'..'4'
  int _locationId = 0; // 0 = all locations

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _apiService.getPhysicalStockReport(
      month: _month,
      week: _week == 'all' ? null : _week,
      locationId: _locationId > 0 ? _locationId : null,
    );

    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      setState(() {
        _report = PhysicalStockReport.fromJson(result.data!);
        _month = _report!.month;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Physical Stock Report')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadReport,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReport,
                  child: _buildContent(isDark),
                ),
    );
  }

  Widget _buildContent(bool isDark) {
    final report = _report!;

    // Group records by week for section headers
    final byWeek = <int, List<PhysicalStockReportRecord>>{};
    for (final r in report.records) {
      byWeek.putIfAbsent(r.weekNumber, () => []).add(r);
    }
    final weeks = byWeek.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFilters(report),
        const SizedBox(height: 12),
        _buildSummary(report.summary, isDark),
        const SizedBox(height: 8),
        if (report.records.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No counts recorded for this filter')),
          ),
        for (final week in weeks) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              'Week $week  (${report.weekRanges[week] ?? ''})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          ...byWeek[week]!.map((r) => _buildRecordCard(r, isDark)),
        ],
      ],
    );
  }

  Widget _buildFilters(PhysicalStockReport report) {
    final monthOptions = report.months.isEmpty ? [report.month] : report.months;
    // Guard against a month value not present in the options list
    final monthValue = monthOptions.contains(_month) ? _month : monthOptions.first;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: monthValue,
            decoration: const InputDecoration(
              labelText: 'Month',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: monthOptions
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                _month = v;
                _loadReport();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _week,
            decoration: const InputDecoration(
              labelText: 'Week',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: '1', child: Text('Week 1')),
              DropdownMenuItem(value: '2', child: Text('Week 2')),
              DropdownMenuItem(value: '3', child: Text('Week 3')),
              DropdownMenuItem(value: '4', child: Text('Week 4')),
            ],
            onChanged: (v) {
              if (v != null) {
                _week = v;
                _loadReport();
              }
            },
          ),
        ),
        if (_report != null && _report!.locations.length > 1) ...[
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _locationId,
              decoration: const InputDecoration(
                labelText: 'Location',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 0, child: Text('All')),
                ..._report!.locations.map((l) => DropdownMenuItem(
                      value: l.locationId,
                      child: Text(l.locationName,
                          overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) {
                if (v != null) {
                  _locationId = v;
                  _loadReport();
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(PhysicalStockSummary summary, bool isDark) {
    Widget tile(String label, String value, Color color) {
      return Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 2),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextLight
                          : AppColors.textLight,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    final fmt = NumberFormat('#,###.##');
    return Row(
      children: [
        tile('Counted', summary.totalCounted.toString(),
            isDark ? AppColors.darkText : AppColors.text),
        tile('Surplus', '+${fmt.format(summary.totalSurplus)}', Colors.green),
        tile('Shortage', fmt.format(summary.totalShortage), Colors.red),
        tile('Matched', summary.matchedCount.toString(), Colors.blueGrey),
      ],
    );
  }

  Widget _buildRecordCard(PhysicalStockReportRecord record, bool isDark) {
    final fmt = NumberFormat('#,###.##');
    final Color diffColor;
    final String diffLabel;
    if (record.difference > 0) {
      diffColor = Colors.green;
      diffLabel = '+${fmt.format(record.difference)}';
    } else if (record.difference < 0) {
      diffColor = Colors.red;
      diffLabel = fmt.format(record.difference);
    } else {
      diffColor = Colors.blueGrey;
      diffLabel = '0';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        title: Text(record.itemName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${record.locationName}'
          '${record.countDate != null ? '  ·  ${record.countDate}' : ''}\n'
          'System: ${fmt.format(record.systemQty)}   '
          'Physical: ${fmt.format(record.physicalQty)}',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: diffColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(diffLabel,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: diffColor, fontSize: 13)),
        ),
      ),
    );
  }
}
