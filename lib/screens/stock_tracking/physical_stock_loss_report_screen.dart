import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/physical_stock.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../sale_details_screen.dart';

/// Loss Stock report (mobile version of web /items/physical_stock_loss_report).
/// Every shortage this month, valued at the item's current selling price,
/// with a grand total and a link to whichever sale wrote it off, if any.
class PhysicalStockLossReportScreen extends StatefulWidget {
  const PhysicalStockLossReportScreen({super.key});

  @override
  State<PhysicalStockLossReportScreen> createState() =>
      _PhysicalStockLossReportScreenState();
}

class _PhysicalStockLossReportScreenState
    extends State<PhysicalStockLossReportScreen> {
  final ApiService _apiService = ApiService();

  PhysicalStockLossReport? _report;
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

    final result = await _apiService.getPhysicalStockLossReport(
      month: _month,
      week: _week == 'all' ? null : _week,
      locationId: _locationId > 0 ? _locationId : null,
    );

    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      setState(() {
        _report = PhysicalStockLossReport.fromJson(result.data!);
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
      appBar: AppBar(title: const Text('Loss Stock Report')),
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

    final byWeek = <int, List<PhysicalStockLossRecord>>{};
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
            child: Center(child: Text('No losses recorded for this filter')),
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

  Widget _buildFilters(PhysicalStockLossReport report) {
    final monthOptions = report.months.isEmpty ? [report.month] : report.months;
    final monthValue =
        monthOptions.contains(_month) ? _month : monthOptions.first;

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
                      child:
                          Text(l.locationName, overflow: TextOverflow.ellipsis),
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

  Widget _buildSummary(PhysicalStockLossSummary summary, bool isDark) {
    Widget tile(String label, String value) {
      return Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error)),
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

    final qtyFmt = NumberFormat('#,###.##');
    final valueFmt = NumberFormat('#,###');
    return Row(
      children: [
        tile('Items', summary.totalItems.toString()),
        tile('Lost qty', qtyFmt.format(summary.totalLossQty)),
        tile('Value', valueFmt.format(summary.totalLossValue)),
      ],
    );
  }

  Widget _buildRecordCard(PhysicalStockLossRecord record, bool isDark) {
    final qtyFmt = NumberFormat('#,###.##');
    final valueFmt = NumberFormat('#,###');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        title: Text(record.itemName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${record.locationName}'
          '${record.countDate != null ? '  ·  ${record.countDate}' : ''}\n'
          'Lost ${qtyFmt.format(record.lossQty)} × ${valueFmt.format(record.unitPrice)}',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(valueFmt.format(record.lossValue),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                      fontSize: 13)),
            ),
            if (record.saleId != null) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SaleDetailsScreen(saleId: record.saleId!),
                  ),
                ),
                child: Text(
                  'Sale #${record.saleId}',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.brandPrimary,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
