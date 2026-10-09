import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/horizontal_scroll_table.dart';

/// One row of the location sales ledger: a sale that has a known location,
/// with its items combined and its payment amount placed under whichever
/// payment type it was paid with (Cash / Lipa Namba / Bank) - per sale,
/// not per item.
class _LedgerRow {
  final String location;
  final String items;
  final double quantity;
  final double cash;
  final double lipaNamba;
  final double bank;
  final double? lat;
  final double? lng;

  _LedgerRow({
    required this.location,
    required this.items,
    required this.quantity,
    required this.cash,
    required this.lipaNamba,
    required this.bank,
    this.lat,
    this.lng,
  });

  double get total => cash + lipaNamba + bank;
}

class SalesLocationReportScreen extends StatefulWidget {
  const SalesLocationReportScreen({super.key});

  @override
  State<SalesLocationReportScreen> createState() =>
      _SalesLocationReportScreenState();
}

class _SalesLocationReportScreenState extends State<SalesLocationReportScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String? _errorMessage;
  DateTime _date = DateTime.now();
  int? _stockLocationId;

  List<_LedgerRow> _rows = [];
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

    final dateStr = DateFormat('yyyy-MM-dd').format(_date);

    try {
      final rows = <_LedgerRow>[];
      const pageSize = 200;
      int offset = 0;
      int total = 0;

      do {
        final response = await _apiService.getSales(
          startDate: dateStr,
          endDate: dateStr,
          limit: pageSize,
          offset: offset,
          locationId: _stockLocationId,
        );

        if (!response.isSuccess || response.data == null) {
          setState(() {
            _errorMessage = response.message;
            _isLoading = false;
          });
          return;
        }

        final data = response.data!;
        total = (data['total'] as num?)?.toInt() ?? 0;
        final sales = (data['sales'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        for (final sale in sales) {
          final city = (sale['sale_city'] as String?)?.trim();
          // Only sales with a known location belong in this ledger.
          if (city == null || city.isEmpty) continue;

          final saleId = sale['sale_id'] as int;
          final locationParts = [
            city,
            (sale['sale_district'] as String?)?.trim(),
          ].where((p) => p != null && p.isNotEmpty).toList();

          final itemsResponse = await _apiService.getSaleItems(saleId);
          String itemsLabel = 'Could not load items';
          double quantity = 0;
          if (itemsResponse.isSuccess && itemsResponse.data != null) {
            final items = itemsResponse.data!;
            quantity = items.fold<double>(0, (sum, i) => sum + i.quantity);
            itemsLabel = items
                .map((i) => '${i.itemName} x${_formatQty(i.quantity)}')
                .join(', ');
          }

          final saleTotal = (sale['total_amount'] as num?)?.toDouble() ?? 0;
          // Mixed-payment sales are treated as a single payment type, per
          // whichever type the server lists first for that sale.
          final paymentTypeRaw =
              (sale['payment_type'] as String? ?? '').split(',').first.trim();
          final paymentType = paymentTypeRaw
              .replaceAll(RegExp(r'[0-9.,\s]+$'), '')
              .trim()
              .toUpperCase();

          double cash = 0, lipaNamba = 0, bank = 0;
          if (paymentType.contains('LIPA')) {
            lipaNamba = saleTotal;
          } else if (paymentType.contains('BANK') ||
              paymentType.contains('CREDIT CARD')) {
            bank = saleTotal;
          } else {
            // Cash, or anything unrecognized, defaults to Cash.
            cash = saleTotal;
          }

          rows.add(_LedgerRow(
            location: locationParts.join(', '),
            lat: (sale['sale_lat'] as num?)?.toDouble(),
            lng: (sale['sale_lng'] as num?)?.toDouble(),
            items: itemsLabel,
            quantity: quantity,
            cash: cash,
            lipaNamba: lipaNamba,
            bank: bank,
          ));
        }

        offset += pageSize;
        if (rows.length > 5000) break;
      } while (offset < total);

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cashTotal = _rows.fold<double>(0, (s, r) => s + r.cash);
    final lipaTotal = _rows.fold<double>(0, (s, r) => s + r.lipaNamba);
    final bankTotal = _rows.fold<double>(0, (s, r) => s + r.bank);
    final grandTotal = cashTotal + lipaTotal + bankTotal;
    final fmt = NumberFormat('#,##0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales by Location'),
        backgroundColor: AppColors.brandPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      const Text('Date',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(), isDense: true),
                            child: Text(DateFormat('yyyy-MM-dd').format(_date)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Stock',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: _stockLocationId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(), isDense: true),
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null, child: Text('All stocks')),
                            ...context
                                .watch<LocationProvider>()
                                .allowedLocations
                                .map(
                                  (loc) => DropdownMenuItem<int?>(
                                    value: loc.locationId,
                                    child: Text(loc.locationName,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                          ],
                          onChanged: (value) {
                            setState(() => _stockLocationId = value);
                            _load();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  if (_rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child:
                          Center(child: Text('No located sales on this date.')),
                    )
                  else ...[
                    _buildTable(fmt),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.brandPrimary
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            _summaryRow('Cash', fmt.format(cashTotal)),
                            _summaryRow('Lipa Namba', fmt.format(lipaTotal)),
                            _summaryRow('Bank', fmt.format(bankTotal)),
                            const Divider(height: 20),
                            _summaryRow('Total Sales', fmt.format(grandTotal),
                                bold: true),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTable(NumberFormat fmt) {
    return HorizontalScrollTable(child: _buildDataTable(fmt));
  }

  Widget _buildDataTable(NumberFormat fmt) {
    return DataTable(
      columnSpacing: 20,
      headingRowHeight: 36,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 48,
      border: TableBorder.all(color: Colors.grey.shade400, width: 1),
      dividerThickness: 1,
      columns: const [
        DataColumn(
            label: Text('No.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        DataColumn(
            label: Text('Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        DataColumn(
            label: Text('Item',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        DataColumn(
            label: Text('Qty',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            numeric: true),
        DataColumn(
            label: Text('Cash',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            numeric: true),
        DataColumn(
            label: Text('Lipa Namba',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            numeric: true),
        DataColumn(
            label: Text('Bank',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            numeric: true),
      ],
      rows: List.generate(_rows.length, (i) {
        final r = _rows[i];
        return DataRow(cells: [
          DataCell(Text('${i + 1}', style: const TextStyle(fontSize: 12))),
          DataCell(SizedBox(
            width: 180,
            child: Row(
              children: [
                Expanded(
                    child:
                        Text(r.location, style: const TextStyle(fontSize: 12))),
                if (r.lat != null && r.lng != null)
                  IconButton(
                    icon: Icon(Icons.visibility_outlined,
                        size: 18, color: AppColors.brandPrimary),
                    tooltip: 'Show on map',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openMap(r.lat!, r.lng!),
                  ),
              ],
            ),
          )),
          DataCell(SizedBox(
              width: 200,
              child: Text(r.items, style: const TextStyle(fontSize: 12)))),
          DataCell(Text(_formatQty(r.quantity),
              style: const TextStyle(fontSize: 12))),
          DataCell(Text(r.cash > 0 ? fmt.format(r.cash) : '-',
              style: const TextStyle(fontSize: 12))),
          DataCell(Text(r.lipaNamba > 0 ? fmt.format(r.lipaNamba) : '-',
              style: const TextStyle(fontSize: 12))),
          DataCell(Text(r.bank > 0 ? fmt.format(r.bank) : '-',
              style: const TextStyle(fontSize: 12))),
        ]);
      }),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: bold ? AppColors.brandPrimary : Colors.black87,
              )),
        ],
      ),
    );
  }
}
