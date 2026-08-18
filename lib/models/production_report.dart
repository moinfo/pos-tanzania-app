// Generic container for the production reports.
//
// Backend: application/controllers/api/Production_reports.php returns the raw
// getData()/getSummaryData()/getDataColumns() output of the same report models
// the web uses (application/models/reports/*.php) rather than pre-rendered
// HTML -- so one renderer here can serve all seven tabular reports.

/// One column definition.
///
/// The server sends each column as a single-entry map of field -> label, with
/// an optional sibling 'sorter' key: {"bags_used": "Bags Used", "sorter":
/// "number_sorter"}. The field is therefore "whichever key isn't 'sorter'".
class ReportColumn {
  final String field;
  final String label;

  /// Derived from sorter == 'number_sorter'. Drives right-alignment and
  /// thousands formatting; the server has already localised the label.
  final bool isNumeric;

  ReportColumn({required this.field, required this.label, required this.isNumeric});

  static ReportColumn? fromJson(Map<String, dynamic> json) {
    String? field;
    String? label;
    json.forEach((key, value) {
      if (key != 'sorter' && field == null) {
        field = key;
        label = value?.toString() ?? key;
      }
    });
    if (field == null) return null;
    return ReportColumn(
      field: field!,
      label: label ?? field!,
      isNumeric: json['sorter']?.toString() == 'number_sorter',
    );
  }
}

class ProductionReport {
  final List<ReportColumn> columns;
  final List<Map<String, dynamic>> rows;

  /// Flat key -> value; the keys differ per report, so it is rendered
  /// generically rather than modelled per report type.
  final Map<String, dynamic> summary;

  ProductionReport({
    required this.columns,
    required this.rows,
    required this.summary,
  });

  factory ProductionReport.fromJson(Map<String, dynamic> json) {
    return ProductionReport(
      columns: (json['columns'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ReportColumn.fromJson)
              .whereType<ReportColumn>()
              .toList() ??
          [],
      rows: (json['data'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [],
      summary: (json['summary'] is Map<String, dynamic>)
          ? json['summary'] as Map<String, dynamic>
          : <String, dynamic>{},
    );
  }

  bool get isEmpty => rows.isEmpty;
}

/// A raw material, for the Material Journey report's item picker.
class RawMaterial {
  final int itemId;
  final String name;

  RawMaterial({required this.itemId, required this.name});

  factory RawMaterial.fromJson(Map<String, dynamic> json) {
    return RawMaterial(
      itemId: json['item_id'] is int
          ? json['item_id']
          : int.tryParse(json['item_id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}
