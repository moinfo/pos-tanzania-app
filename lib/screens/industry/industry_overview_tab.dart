import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';
import 'industry_stock_section_view.dart';

class IndustryOverviewTab extends StatefulWidget {
  final IndustryService service;
  final Future<void> Function() onSessionExpired;

  const IndustryOverviewTab({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryOverviewTab> createState() => _IndustryOverviewTabState();
}

class _IndustryOverviewTabState extends State<IndustryOverviewTab> {
  IndustryDashboard? _dashboard;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final response = await widget.service.getDashboard(date: dateStr);

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      setState(() {
        _dashboard = response.data;
        _isLoading = false;
      });
    } else if (response.statusCode == 440) {
      setState(() => _isLoading = false);
      await widget.onSessionExpired();
    } else {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final data = _dashboard?.data ?? {};
    final week = _dashboard?.week ?? {};

    Map<String, dynamic> m(String key) => (data[key] as Map<String, dynamic>?) ?? {};

    final labourersDay = m('labourers_day');
    final labourersWeek = m('labourers_week');
    final rollerDay = m('roller_day');
    final rollerWeek = m('roller_week');
    final mattressDay = m('mattress_day');
    final mattressWeek = m('mattress_week');
    final productionDay = m('production_day');
    final productionWeek = m('production_week');
    final stock = m('stock');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: industryScrollPadding(context),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEE, d MMM yyyy').format(_selectedDate),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Badilisha Tarehe'),
              ),
            ],
          ),
          if (week['start'] != null && week['end'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Wiki: ${week['start']} → ${week['end']}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No dashboard data for this date.')),
            )
          else ...[
            _buildCard('Wafanyakazi wa Kibarua & Malipo', [
              _row('Waliokuja / Jumla Wafanyakazi',
                  '${labourersDay['present'] ?? 0} / ${labourersDay['total'] ?? 0}', '-'),
              _row('Siku Zilizohudhuriwa', '-', '${labourersWeek['days_attended'] ?? 0}'),
              _row('Malipo Kabla ya Makato', '${labourersDay['gross'] ?? 0}', '${labourersWeek['gross'] ?? 0}'),
              _row('Makato ya Kuchelewa', '${labourersDay['penalty'] ?? 0}', '${labourersWeek['penalty'] ?? 0}'),
              _row('Malipo ya Dharura', '${labourersDay['adjustment'] ?? 0}', '${labourersWeek['adjustment'] ?? 0}'),
              _row('Jumla ya Malipo', '${labourersDay['net'] ?? 0}', '${labourersWeek['amount'] ?? 0}', bold: true),
              _row('Waliolipwa / Hawajalipwa', '-',
                  '${labourersWeek['paid_count'] ?? 0} / ${labourersWeek['unpaid_count'] ?? 0}'),
            ]),
            _buildCard('Roller', [
              _row('Roba Zilizopokelewa', '${rollerDay['bags_received'] ?? 0}', '${rollerWeek['bags_received'] ?? 0}'),
              _row('Roba Zilizofunguliwa', '${rollerDay['bags_opened'] ?? 0}', '${rollerWeek['bags_opened'] ?? 0}'),
              _row('Rollers Zilizovishwa (Big Roller/Small Roller)',
                  '${rollerDay['rollers_used_big'] ?? 0} / ${rollerDay['rollers_used_small'] ?? 0}',
                  '${rollerWeek['rollers_used_big'] ?? 0} / ${rollerWeek['rollers_used_small'] ?? 0}'),
              _row('Mikanda Iliyotumika (Kuvisha)', '${rollerDay['straps_used'] ?? 0}', '${rollerWeek['straps_used'] ?? 0}'),
              _row('Rollers Zilizopruniwa (Big Roller/Small Roller)',
                  '${rollerDay['trimmed_big'] ?? 0} / ${rollerDay['trimmed_small'] ?? 0}',
                  '${rollerWeek['trimmed_big'] ?? 0} / ${rollerWeek['trimmed_small'] ?? 0}'),
              _row('Mikanda Iliyochomwa', '${rollerDay['straps_welded'] ?? 0}', '${rollerWeek['straps_welded'] ?? 0}'),
              _row('Pcs Zinazotarajiwa (Kuchoma)', '${rollerDay['expected_pcs_from_welding'] ?? 0}', '-'),
            ]),
            _buildCard('Mattress', [
              _row('Magodoro Yaliyopokelewa', '${mattressDay['mattresses_received'] ?? 0}',
                  '${mattressWeek['mattresses_received'] ?? 0}'),
              _row('Magodoro Yaliyochanwa', '${mattressDay['mattresses_cut'] ?? 0}',
                  '${mattressWeek['mattresses_cut'] ?? 0}'),
              _row('Mikanda Halisi', '${mattressDay['straps_actual'] ?? 0}', '${mattressWeek['straps_actual'] ?? 0}'),
              _row('Mikanda Iliyoharibika', '${mattressDay['straps_damaged'] ?? 0}',
                  '${mattressWeek['straps_damaged'] ?? 0}'),
            ]),
            _buildCard('Uzalishaji (Production)', [
              _row('Pcs Zilizozalishwa (Mashine)', '${data['pcs_produced_day'] ?? 0}', '${data['pcs_produced_week'] ?? 0}'),
              _row('Dazeni Zilizopack (Nzima (Normal)/Mbovu (Reject))',
                  '${productionDay['dozens_packed'] ?? 0} / ${productionDay['dozens_packed_reject'] ?? 0}',
                  '${productionWeek['dozens_packed'] ?? 0} / ${productionWeek['dozens_packed_reject'] ?? 0}'),
              _row('Katoni Zilizopack (Nzima (Normal)/Mbovu (Reject))',
                  '${productionDay['cartons_packed'] ?? 0} / ${productionDay['cartons_packed_reject'] ?? 0}',
                  '${productionWeek['cartons_packed'] ?? 0} / ${productionWeek['cartons_packed_reject'] ?? 0}'),
              _row('Katoni Zilizotolewa (Issue) (Nzima (Normal)/Mbovu (Reject))',
                  '${productionDay['cartons_issued'] ?? 0} / ${productionDay['cartons_issued_reject'] ?? 0}',
                  '${productionWeek['cartons_issued'] ?? 0} / ${productionWeek['cartons_issued_reject'] ?? 0}'),
            ]),
            if (stock.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Stock ya Sasa Hivi',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandPrimary)),
              const SizedBox(height: 8),
              IndustryStockSectionView(stock: stock),
            ],
          ],
        ],
      ),
    );
  }

  _RowSpec _row(String label, String dayValue, String weekValue, {bool bold = false}) =>
      _RowSpec(label, dayValue, weekValue, bold);

  Widget _buildCard(String title, List<_RowSpec> rows) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandPrimary)),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              children: [
                const TableRow(children: [
                  SizedBox(),
                  Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('Siku Hii', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('Wiki Hii', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                  ),
                ]),
                for (final r in rows)
                  TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(r.label,
                          style: TextStyle(fontWeight: r.bold ? FontWeight.bold : FontWeight.normal)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(r.dayValue,
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: r.bold ? FontWeight.bold : FontWeight.normal)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(r.weekValue,
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: r.bold ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RowSpec {
  final String label;
  final String dayValue;
  final String weekValue;
  final bool bold;
  _RowSpec(this.label, this.dayValue, this.weekValue, this.bold);
}
