import 'package:flutter/material.dart';
import '../../widgets/horizontal_scroll_table.dart';

/// Shared stat-tile styling used by [IndustryStockSectionView] and the
/// standalone Roller/Mattress summary tiles below.
Widget stockStatTile(String value, String label, {bool accent = false}) {
  return Container(
    width: 150,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(6),
      border: Border(
        left: BorderSide(color: accent ? Colors.teal : Colors.black87, width: 3),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54), maxLines: 2),
      ],
    ),
  );
}

/// Roller-only stock tiles (matches the 3 roller tiles in the web's Stock
/// panel), for use in the Roller screen's own Summary section.
class RollerStockTiles extends StatelessWidget {
  final Map<String, dynamic> roller;
  const RollerStockTiles({super.key, required this.roller});

  @override
  Widget build(BuildContext context) {
    final big = (roller['big'] as Map<String, dynamic>?) ?? {};
    final small = (roller['small'] as Map<String, dynamic>?) ?? {};
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        stockStatTile('${roller['bags_in_store'] ?? 0}', 'ROLLER -- ROBA STORE'),
        stockStatTile('${big['loose_rollers_available'] ?? 0}', 'ROLLER -- KUBWA (BADO HAVIJAVISHWA)', accent: true),
        stockStatTile('${small['loose_rollers_available'] ?? 0}', 'ROLLER -- NDOGO (BADO HAVIJAVISHWA)', accent: true),
      ],
    );
  }
}

/// Mattress-only stock tiles (matches the 2 mattress tiles in the web's
/// Stock panel), for use in the Mattress screen's own Summary section.
class MattressStockTiles extends StatelessWidget {
  final Map<String, dynamic> mattress;
  const MattressStockTiles({super.key, required this.mattress});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        stockStatTile('${mattress['mattresses_in_store'] ?? 0}', 'MAGODORO STORE'),
        stockStatTile('${mattress['straps_available'] ?? 0}', 'MIKANDA ILIYOPO', accent: true),
      ],
    );
  }
}

/// Exact match for Industry::dashboard()'s 'stock' block, per
/// application/views/industry/general.php's JS:
///   s.roller.bags_in_store, s.roller.big/.small.loose_rollers_available,
///   s.mattress.mattresses_in_store, s.mattress.straps_available,
///   s.machines[] = {name, pcs_in_hand, dozens_in_hand, cartons_in_hand}
class IndustryStockSectionView extends StatelessWidget {
  final Map<String, dynamic> stock;

  const IndustryStockSectionView({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    final roller = (stock['roller'] as Map<String, dynamic>?) ?? {};
    final rollerBig = (roller['big'] as Map<String, dynamic>?) ?? {};
    final rollerSmall = (roller['small'] as Map<String, dynamic>?) ?? {};
    final mattress = (stock['mattress'] as Map<String, dynamic>?) ?? {};
    final machines = (stock['machines'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _statTile('${roller['bags_in_store'] ?? 0}', 'ROLLER -- ROBA STORE'),
            _statTile('${rollerBig['loose_rollers_available'] ?? 0}', 'ROLLER -- KUBWA (BADO HAVIJAVISHWA)', accent: true),
            _statTile('${rollerSmall['loose_rollers_available'] ?? 0}', 'ROLLER -- NDOGO (BADO HAVIJAVISHWA)', accent: true),
            _statTile('${mattress['mattresses_in_store'] ?? 0}', 'MAGODORO STORE'),
            _statTile('${mattress['straps_available'] ?? 0}', 'MIKANDA ILIYOPO', accent: true),
          ],
        ),
        const SizedBox(height: 20),
        Text('Mashine -- Stock (Pcs / Dazeni / Katoni)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 8),
        if (machines.isEmpty)
          const Text('No machines configured.', style: TextStyle(color: Colors.black54))
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: HorizontalScrollTable(
              child: DataTable(
                columnSpacing: 24,
                headingRowHeight: 36,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 44,
                columns: const [
                  DataColumn(label: Text('Machine', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                  DataColumn(
                      label: Text('Pcs in Hand', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      numeric: true),
                  DataColumn(
                      label: Text('Dozens in Hand', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      numeric: true),
                  DataColumn(
                      label: Text('Cartons in Hand', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      numeric: true),
                ],
                rows: machines
                    .map((m) => DataRow(cells: [
                          DataCell(Text(m['name']?.toString() ?? '', style: const TextStyle(color: Colors.black87))),
                          DataCell(Text('${m['pcs_in_hand'] ?? 0}', style: const TextStyle(color: Colors.black87))),
                          DataCell(Text('${m['dozens_in_hand'] ?? 0}', style: const TextStyle(color: Colors.black87))),
                          DataCell(Text('${m['cartons_in_hand'] ?? 0}', style: const TextStyle(color: Colors.black87))),
                        ]))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _statTile(String value, String label, {bool accent = false}) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: accent ? Colors.teal : Colors.black87, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54), maxLines: 2),
        ],
      ),
    );
  }
}
