import 'package:flutter/material.dart';
import '../../widgets/horizontal_scroll_table.dart';
import '../../services/industry_service.dart';
import '../../utils/constants.dart';
import 'industry_stock_section_view.dart';

/// Full carbon-copy of application/views/industry/stock.php: 3 separate
/// panels (Roller/Mattress/Machine), each with its own heading - distinct
/// from the General tab's flat "Stock ya Sasa Hivi" block
/// (IndustryStockSectionView), which this intentionally does not reuse for
/// layout (only for the shared stockStatTile() styling).
class IndustryStockScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryStockScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryStockScreen> createState() => _IndustryStockScreenState();
}

class _IndustryStockScreenState extends State<IndustryStockScreen> {
  Map<String, dynamic>? _stock;
  bool _isLoading = false;
  String? _errorMessage;

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

    final response = await widget.service.getDashboard();

    if (!mounted) return;

    if (response.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    if (response.isSuccess && response.data != null) {
      setState(() {
        _stock = (response.data!.data['stock'] as Map<String, dynamic>?) ?? {};
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: industryScrollPadding(context),
        children: [
          if (_errorMessage != null)
            Text(_errorMessage!, style: const TextStyle(color: Colors.red))
          else if (_stock == null || _stock!.isEmpty)
            const Center(child: Text('No stock data.'))
          else
            _buildBody(_stock!),
        ],
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> stock) {
    final roller = (stock['roller'] as Map<String, dynamic>?) ?? {};
    final rollerBig = (roller['big'] as Map<String, dynamic>?) ?? {};
    final rollerSmall = (roller['small'] as Map<String, dynamic>?) ?? {};
    final mattress = (stock['mattress'] as Map<String, dynamic>?) ?? {};
    final machines = (stock['machines'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          icon: Icons.fiber_manual_record,
          title: 'Roller',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              stockStatTile('${roller['bags_in_store'] ?? 0}', 'BAGS IN STORE'),
              stockStatTile('${rollerBig['loose_rollers_available'] ?? 0}', 'BIG ROLLER — LOOSE ROLLERS AVAILABLE',
                  accent: true),
              stockStatTile(
                  '${rollerSmall['loose_rollers_available'] ?? 0}', 'SMALL ROLLER — LOOSE ROLLERS AVAILABLE',
                  accent: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _panel(
          icon: Icons.grid_view,
          title: 'Mattress',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              stockStatTile('${mattress['mattresses_in_store'] ?? 0}', 'MATTRESSES IN STORE'),
              stockStatTile('${mattress['straps_available'] ?? 0}', 'STRAPS AVAILABLE', accent: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _panel(
          icon: Icons.settings,
          title: 'Machine',
          child: machines.isEmpty
              ? Text('No machines configured.', style: TextStyle(color: Colors.grey.shade500))
              : HorizontalScrollTable(
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowHeight: 36,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 44,
                    columns: const [
                      DataColumn(label: Text('Machine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(
                          label: Text('Pcs in Hand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          numeric: true),
                      DataColumn(
                          label: Text('Dozens in Hand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          numeric: true),
                      DataColumn(
                          label: Text('Cartons in Hand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          numeric: true),
                      DataColumn(
                          label: Text('Dozens in Hand (Mbovu)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          numeric: true),
                      DataColumn(
                          label: Text('Cartons in Hand (Mbovu)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          numeric: true),
                    ],
                    rows: machines
                        .map((m) => DataRow(cells: [
                              DataCell(Text(m['name']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${m['pcs_in_hand'] ?? 0}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${m['dozens_in_hand'] ?? 0}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${m['cartons_in_hand'] ?? 0}', style: const TextStyle(fontSize: 12))),
                              DataCell(
                                  Text('${m['dozens_in_hand_reject'] ?? 0}', style: const TextStyle(fontSize: 12))),
                              DataCell(
                                  Text('${m['cartons_in_hand_reject'] ?? 0}', style: const TextStyle(fontSize: 12))),
                            ]))
                        .toList(),
                  ),
                ),
        ),
      ],
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
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}
