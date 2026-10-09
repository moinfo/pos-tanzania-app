import 'package:flutter/material.dart';
import '../../widgets/horizontal_scroll_table.dart';
import 'package:intl/intl.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';
import 'industry_stock_section_view.dart';

/// Full carbon-copy of application/views/industry/report.php: Date Range,
/// Casual Labourers -- Attendance & Earnings, Roller, Mattress, and
/// Machine Production & Packing panels.
class IndustryReportScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryReportScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryReportScreen> createState() => _IndustryReportScreenState();
}

class _IndustryReportScreenState extends State<IndustryReportScreen> {
  IndustryReport? _report;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate = DateTime.now();

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

    final response = await widget.service.getReport(
      startDate: DateFormat('yyyy-MM-dd').format(_startDate),
      endDate: DateFormat('yyyy-MM-dd').format(_endDate),
    );

    if (!mounted) return;

    if (response.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    if (response.isSuccess && response.data != null) {
      setState(() {
        _report = response.data;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate(DateTime current, void Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBody();
  }

  Widget _buildBody() {
    final report = _report;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: industryScrollPadding(context),
        children: [
          _panel(
            icon: Icons.calendar_today,
            title: 'Date Range',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _labeledDateField('From', _startDate, (d) => setState(() => _startDate = d))),
                    const SizedBox(width: 10),
                    Expanded(child: _labeledDateField('To', _endDate, (d) => setState(() => _endDate = d))),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Load Report'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Text(_errorMessage!, style: const TextStyle(color: Colors.red))
          else if (report == null)
            const Center(child: Text('No report data for this range.'))
          else ...[
            _panel(
              icon: Icons.person_outline,
              title: 'Casual Labourers -- Attendance & Earnings',
              child: _buildLabourersSection(report),
            ),
            const SizedBox(height: 16),
            _panel(icon: Icons.fiber_manual_record, title: 'Roller', child: _buildRollerSection(report.roller)),
            const SizedBox(height: 16),
            _panel(icon: Icons.grid_view, title: 'Mattress', child: _buildMattressSection(report.mattress)),
            const SizedBox(height: 16),
            _panel(
              icon: Icons.settings,
              title: 'Machine Production & Packing',
              child: _buildProductionSection(report.production),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabourersSection(IndustryReport report) {
    final totals = report.labourersTotals;
    final wagesPaid = report.wagesPaid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            stockStatTile('${totals.daysAttended}', 'DAYS ATTENDED'),
            stockStatTile(totals.amountEarned.toStringAsFixed(0), 'AMOUNT EARNED', accent: true),
            stockStatTile('${wagesPaid['total_paid'] ?? 0}', 'TOTAL PAID', accent: true),
            stockStatTile('${wagesPaid['count_paid'] ?? 0}', 'PAYMENTS MADE'),
          ],
        ),
        const SizedBox(height: 14),
        if (report.labourers.isEmpty)
          Text('No casual labourers yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
        else ...[
          Row(
            children: const [
              Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text('Days Attended', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text('Amount Earned', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
          const Divider(height: 16),
          for (final l in report.labourers)
            Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(l.name, style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text('${l.daysAttended}', style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text(l.amountEarned.toStringAsFixed(0), style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildRollerSection(Map<String, dynamic> roller) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        stockStatTile('${roller['bags_received'] ?? 0}', 'BAGS RECEIVED'),
        stockStatTile('${roller['bags_opened'] ?? 0}', 'BAGS OPENED'),
        stockStatTile('${roller['rollers_counted_big'] ?? 0}', 'COUNTED (BIG)', accent: true),
        stockStatTile('${roller['rollers_counted_small'] ?? 0}', 'COUNTED (SMALL)', accent: true),
        stockStatTile('${roller['rollers_used_big'] ?? 0}', 'USED (BIG)'),
        stockStatTile('${roller['rollers_used_small'] ?? 0}', 'USED (SMALL)'),
      ],
    );
  }

  Widget _buildMattressSection(Map<String, dynamic> mattress) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        stockStatTile('${mattress['mattresses_received'] ?? 0}', 'MATTRESSES RECEIVED'),
        stockStatTile('${mattress['mattresses_cut'] ?? 0}', 'MATTRESSES CUT'),
        stockStatTile('${mattress['straps_actual'] ?? 0}', 'STRAPS ACTUAL', accent: true),
        stockStatTile('${mattress['straps_damaged'] ?? 0}', 'STRAPS DAMAGED'),
        stockStatTile('${mattress['straps_used'] ?? 0}', 'STRAPS USED', accent: true),
      ],
    );
  }

  Widget _buildProductionSection(List<Map<String, dynamic>> production) {
    if (production.isEmpty) {
      return Text('No machines yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 13));
    }
    return HorizontalScrollTable(
      child: DataTable(
        columnSpacing: 20,
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columns: const [
          DataColumn(label: Text('Machine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Pcs Produced', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
          DataColumn(label: Text('Dozens Packed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
          DataColumn(label: Text('Cartons Packed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
          DataColumn(label: Text('Cartons Issued', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
          DataColumn(label: Text('Dozens Packed (Mbovu)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
          DataColumn(label: Text('Cartons Packed (Mbovu)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
          DataColumn(label: Text('Cartons Issued (Mbovu)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
        ],
        rows: production
            .map((m) => DataRow(cells: [
                  DataCell(Text(m['name']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${m['pcs_produced'] ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${m['dozens_packed'] ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${m['cartons_packed'] ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${m['cartons_issued'] ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${m['dozens_packed_reject'] ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${m['cartons_packed_reject'] ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${m['cartons_issued_reject'] ?? 0}', style: const TextStyle(fontSize: 12))),
                ]))
            .toList(),
      ),
    );
  }

  Widget _panel({required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.brandPrimary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  Widget _labeledDateField(String label, DateTime value, void Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDate(value, onPicked),
          child: InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            child: Text(DateFormat('yyyy-MM-dd').format(value), style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
