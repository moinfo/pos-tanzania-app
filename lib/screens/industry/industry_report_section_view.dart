import 'package:flutter/material.dart';
import '../../widgets/horizontal_scroll_table.dart';
import 'sw_labels.dart';

/// Generic renderer for the loosely-typed report/stock sections - the
/// backend shapes these ad-hoc per section, so rather than hand-write a
/// model per field we render whatever keys/values come back:
///  - scalar top-level entries -> a row of stat tiles (matches the web's
///    "Current Stock" tile row)
///  - list-of-records entries -> a table (matches the web's per-machine
///    stock table), falling back to a bullet list for non-uniform rows
///  - nested map entries -> a labeled sub-card of key/value rows
class IndustryReportSectionView extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accentColor;

  const IndustryReportSectionView({
    super.key,
    required this.data,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scalarEntries = data.entries.where((e) => e.value is! Map && e.value is! List).toList();
    final mapEntries = data.entries.where((e) => e.value is Map).toList();
    final listEntries = data.entries.where((e) => e.value is List).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scalarEntries.isNotEmpty) _buildStatTiles(scalarEntries),
        ...mapEntries.map((e) => _buildMapEntry(e.key, e.value as Map)),
        ...listEntries.map((e) => _buildListEntry(e.key, e.value as List)),
      ],
    );
  }

  Widget _buildStatTiles(List<MapEntry<String, dynamic>> entries) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: entries.map((e) {
          return Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border(left: BorderSide(color: accentColor, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.value?.toString() ?? '-',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: accentColor),
                ),
                const SizedBox(height: 4),
                Text(
                  _titleize(e.key).toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMapEntry(String key, Map value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titleize(key), style: TextStyle(fontWeight: FontWeight.bold, color: accentColor)),
            const SizedBox(height: 8),
            ...value.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_titleize(e.key.toString())),
                      Text(e.value?.toString() ?? '-'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildListEntry(String key, List value) {
    if (value.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(title: Text('${_titleize(key)} (0)')),
      );
    }

    // Uniform list of records (e.g. per-machine stock rows) -> a real table.
    if (value.every((row) => row is Map)) {
      final columns = <String>{};
      for (final row in value) {
        columns.addAll((row as Map).keys.map((k) => k.toString()));
      }
      final columnList = columns.toList();

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_titleize(key)} (${value.length})',
                  style: TextStyle(fontWeight: FontWeight.bold, color: accentColor)),
              const SizedBox(height: 8),
              HorizontalScrollTable(
                child: DataTable(
                  columnSpacing: 20,
                  headingRowHeight: 32,
                  dataRowMinHeight: 32,
                  dataRowMaxHeight: 40,
                  columns: columnList
                      .map((c) => DataColumn(label: Text(_titleize(c), style: const TextStyle(fontWeight: FontWeight.bold))))
                      .toList(),
                  rows: value.map((row) {
                    final map = row as Map;
                    return DataRow(
                      cells: columnList
                          .map((c) => DataCell(Text(map[c]?.toString() ?? '-')))
                          .toList(),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Non-uniform list -> fall back to a simple bullet list.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text('${_titleize(key)} (${value.length})'),
        children: value.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(row.toString()),
          );
        }).toList(),
      ),
    );
  }

  String _titleize(String key) => swLabel(key);
}
