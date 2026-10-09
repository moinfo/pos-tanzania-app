import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/industry_service.dart';
import '../../utils/constants.dart';
import '../../widgets/horizontal_scroll_table.dart';

class IndustryDailyReportScreen extends StatefulWidget {
  const IndustryDailyReportScreen({super.key});

  @override
  State<IndustryDailyReportScreen> createState() => _IndustryDailyReportScreenState();
}

class _IndustryDailyReportScreenState extends State<IndustryDailyReportScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    _end = DateTime.now();
  }

  Future<void> _pick({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
        if (_start.isAfter(_end)) _start = _end;
      }
    });
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          child: Text(_dateFormat.format(value)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startStr = _dateFormat.format(_start);
    final endStr = _dateFormat.format(_end);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            TabBar(
              labelColor: AppColors.brandPrimary,
              indicatorColor: AppColors.brandPrimary,
              tabs: [Tab(text: 'Steelwire'), Tab(text: 'Packing')],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _dateField('From', _start, () => _pick(isStart: true)),
                  const SizedBox(width: 12),
                  _dateField('To', _end, () => _pick(isStart: false)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ReportTab(kind: 'steelwire', startDate: startStr, endDate: endStr),
                  _ReportTab(kind: 'packing', startDate: startStr, endDate: endStr),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTab extends StatefulWidget {
  final String kind;
  final String startDate;
  final String endDate;

  const _ReportTab({required this.kind, required this.startDate, required this.endDate});

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> {
  final IndustryService _service = IndustryService();
  final NumberFormat _intFormat = NumberFormat('#,##0');

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ReportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.getDailyReport(
      kind: widget.kind,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = result.data;
      _error = result.isSuccess ? null : result.message;
    });
  }

  String _label(String key) => key
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  String _format(dynamic value) {
    if (value == null || value == '') return '-';
    if (value is num) {
      return value == value.roundToDouble()
          ? _intFormat.format(value)
          : NumberFormat('#,##0.##').format(value);
    }
    return value.toString();
  }

  bool _isNumeric(List<Map<String, dynamic>> rows, String key) {
    return rows.any((r) => r[key] is num);
  }

  /// Totals rule matches the web: opening/closing don't sum across days --
  /// the range opens on the earliest day's opening and closes on the latest
  /// day's closing. Other numeric columns are summed. Text columns get none.
  dynamic _total(List<Map<String, dynamic>> rows, String key, bool isDays) {
    if (isDays && (key == 'opening_cartons' || key == 'closing_cartons')) {
      final edge = rows.reduce((a, b) {
        final aIsEarlier = (a['date'] as String).compareTo(b['date'] as String) <= 0;
        if (key == 'opening_cartons') return aIsEarlier ? a : b;
        return aIsEarlier ? b : a;
      });
      return edge[key];
    }
    if (!_isNumeric(rows, key)) return null;
    return rows.fold<num>(0, (sum, r) => sum + (r[key] is num ? r[key] as num : 0));
  }

  Widget _section(String title, List<Map<String, dynamic>> rows, {bool isDays = false}) {
    final keys = rows.first.keys.where((k) => k != 'is_shared').toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          HorizontalScrollTable(
            child: DataTable(
              columnSpacing: 20,
              headingRowHeight: 36,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 44,
              border: TableBorder.all(color: Colors.grey.shade400, width: 1),
              dividerThickness: 1,
              columns: keys
                  .map((k) => DataColumn(
                        label: Text(_label(k), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        numeric: _isNumeric(rows, k),
                      ))
                  .toList(),
              rows: [
                ...rows.map((row) => DataRow(
                      cells: keys
                          .map((k) => DataCell(Text(_format(row[k]), style: const TextStyle(fontSize: 12))))
                          .toList(),
                    )),
                DataRow(
                  cells: [
                    for (var i = 0; i < keys.length; i++)
                      DataCell(Text(
                        i == 0
                            ? 'Total'
                            : (() {
                                final total = _total(rows, keys[i], isDays);
                                return total == null ? '' : _format(total);
                              })(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error ?? 'Could not load report', textAlign: TextAlign.center),
        ),
      );
    }

    final days = ((_data!['days'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final secondaryKey = widget.kind == 'steelwire' ? 'machines' : 'products';
    final secondaryTitle = widget.kind == 'steelwire' ? 'By Machine' : 'By Product';
    final secondary =
        ((_data![secondaryKey] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: industryScrollPadding(context),
        children: [
          if (days.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No data in this range.')),
            )
          else
            _section('By Day', days, isDays: true),
          if (secondary.isNotEmpty) _section(secondaryTitle, secondary),
        ],
      ),
    );
  }
}
