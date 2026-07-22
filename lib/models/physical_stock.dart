/// Models for the Physical Stock Count feature (mirrors web /items/physical_stock).
///
/// A month is split into 4 fixed weeks (1-7, 8-14, 15-21, 22-end). Counters
/// record the physically counted quantity per item per location per week; the
/// backend snapshots the system quantity on the first save and computes the
/// difference (surplus/shortage) from that snapshot.
library;

double _toDouble(dynamic v) => double.tryParse((v ?? 0).toString()) ?? 0;
int _toInt(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;

/// A stock location option (id + name).
class PhysicalStockLocation {
  final int locationId;
  final String locationName;

  PhysicalStockLocation({required this.locationId, required this.locationName});

  factory PhysicalStockLocation.fromJson(Map<String, dynamic> json) {
    return PhysicalStockLocation(
      locationId: _toInt(json['location_id']),
      locationName: json['location_name']?.toString() ?? '',
    );
  }
}

/// An item row on the count screen with its current system quantity.
class PhysicalStockItem {
  final int itemId;
  final String name;
  final String? itemNumber;
  final String category;
  final double systemQty;

  /// Hierarchy depth from the parent->child ordering (0 = root/parent,
  /// 1+ = child levels). Used to indent child rows like the web screen.
  final int hierDepth;

  PhysicalStockItem({
    required this.itemId,
    required this.name,
    this.itemNumber,
    required this.category,
    required this.systemQty,
    this.hierDepth = 0,
  });

  factory PhysicalStockItem.fromJson(Map<String, dynamic> json) {
    return PhysicalStockItem(
      itemId: _toInt(json['item_id']),
      name: json['name']?.toString() ?? '',
      itemNumber: json['item_number']?.toString(),
      category: json['category']?.toString() ?? '',
      systemQty: _toDouble(json['system_qty']),
      hierDepth: _toInt(json['hier_depth']),
    );
  }
}

/// A saved count for one item in one week.
class PhysicalStockCount {
  final double systemQty;
  final double physicalQty;
  final double difference;
  final String? countDate;

  PhysicalStockCount({
    required this.systemQty,
    required this.physicalQty,
    required this.difference,
    this.countDate,
  });

  factory PhysicalStockCount.fromJson(Map<String, dynamic> json) {
    return PhysicalStockCount(
      systemQty: _toDouble(json['system_qty']),
      physicalQty: _toDouble(json['physical_qty']),
      difference: _toDouble(json['difference']),
      countDate: json['count_date']?.toString(),
    );
  }
}

/// Full payload of GET /api/items/physical_stock.
class PhysicalStockData {
  final String month; // YYYY-MM
  final String monthName; // e.g. "July 2026"
  final int currentWeek; // 1-4
  final Map<int, String> weekRanges; // week -> "1-7" day-range label
  final int locationId;
  final List<PhysicalStockLocation> locations;
  final List<PhysicalStockItem> items;
  final Map<int, Map<int, PhysicalStockCount>> counts; // week -> itemId -> count

  PhysicalStockData({
    required this.month,
    required this.monthName,
    required this.currentWeek,
    required this.weekRanges,
    required this.locationId,
    required this.locations,
    required this.items,
    required this.counts,
  });

  factory PhysicalStockData.fromJson(Map<String, dynamic> json) {
    final weekRanges = <int, String>{};
    (json['week_ranges'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      final wn = int.tryParse(k);
      if (wn != null && v is Map) {
        weekRanges[wn] = v['days']?.toString() ?? '';
      }
    });

    final counts = <int, Map<int, PhysicalStockCount>>{};
    final rawCounts = json['counts'];
    if (rawCounts is Map) {
      rawCounts.forEach((week, itemMap) {
        final wn = int.tryParse(week.toString());
        // PHP serializes an empty week as [] instead of {}
        if (wn == null || itemMap is! Map) return;
        counts[wn] = {};
        itemMap.forEach((itemId, count) {
          final iid = int.tryParse(itemId.toString());
          if (iid != null && count is Map) {
            counts[wn]![iid] =
                PhysicalStockCount.fromJson(Map<String, dynamic>.from(count));
          }
        });
      });
    }

    return PhysicalStockData(
      month: json['month']?.toString() ?? '',
      monthName: json['month_name']?.toString() ?? '',
      currentWeek: _toInt(json['current_week']),
      weekRanges: weekRanges,
      locationId: _toInt(json['location_id']),
      locations: (json['locations'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PhysicalStockLocation.fromJson)
          .toList(),
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PhysicalStockItem.fromJson)
          .toList(),
      counts: counts,
    );
  }
}

/// One row of the physical stock report.
class PhysicalStockReportRecord {
  final int weekNumber;
  final int itemId;
  final int locationId;
  final double systemQty;
  final double physicalQty;
  final double difference;
  final String? countDate;
  final String itemName;
  final String category;
  final String? itemNumber;
  final String locationName;

  PhysicalStockReportRecord({
    required this.weekNumber,
    required this.itemId,
    required this.locationId,
    required this.systemQty,
    required this.physicalQty,
    required this.difference,
    this.countDate,
    required this.itemName,
    required this.category,
    this.itemNumber,
    required this.locationName,
  });

  factory PhysicalStockReportRecord.fromJson(Map<String, dynamic> json) {
    return PhysicalStockReportRecord(
      weekNumber: _toInt(json['week_number']),
      itemId: _toInt(json['item_id']),
      locationId: _toInt(json['location_id']),
      systemQty: _toDouble(json['system_qty']),
      physicalQty: _toDouble(json['physical_qty']),
      difference: _toDouble(json['difference']),
      countDate: json['count_date']?.toString(),
      itemName: json['item_name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      itemNumber: json['item_number']?.toString(),
      locationName: json['location_name']?.toString() ?? '',
    );
  }
}

/// Summary stats of a physical stock report.
class PhysicalStockSummary {
  final int totalCounted;
  final int surplusCount;
  final int shortageCount;
  final int matchedCount;
  final double totalSurplus;
  final double totalShortage;

  PhysicalStockSummary({
    required this.totalCounted,
    required this.surplusCount,
    required this.shortageCount,
    required this.matchedCount,
    required this.totalSurplus,
    required this.totalShortage,
  });

  factory PhysicalStockSummary.fromJson(Map<String, dynamic> json) {
    return PhysicalStockSummary(
      totalCounted: _toInt(json['total_counted']),
      surplusCount: _toInt(json['surplus_count']),
      shortageCount: _toInt(json['shortage_count']),
      matchedCount: _toInt(json['matched_count']),
      totalSurplus: _toDouble(json['total_surplus']),
      totalShortage: _toDouble(json['total_shortage']),
    );
  }
}

/// Full payload of GET /api/items/physical_stock/report.
class PhysicalStockReport {
  final String month;
  final String monthName;
  final Map<int, String> weekRanges; // week -> "01-07 Jul 2026"
  final List<String> months; // available YYYY-MM filter options
  final List<PhysicalStockLocation> locations;
  final List<PhysicalStockReportRecord> records;
  final PhysicalStockSummary summary;

  PhysicalStockReport({
    required this.month,
    required this.monthName,
    required this.weekRanges,
    required this.months,
    required this.locations,
    required this.records,
    required this.summary,
  });

  factory PhysicalStockReport.fromJson(Map<String, dynamic> json) {
    final weekRanges = <int, String>{};
    (json['week_ranges'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      final wn = int.tryParse(k);
      if (wn != null) weekRanges[wn] = v.toString();
    });

    return PhysicalStockReport(
      month: json['month']?.toString() ?? '',
      monthName: json['month_name']?.toString() ?? '',
      weekRanges: weekRanges,
      months: (json['months'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      locations: (json['locations'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PhysicalStockLocation.fromJson)
          .toList(),
      records: (json['records'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PhysicalStockReportRecord.fromJson)
          .toList(),
      summary: PhysicalStockSummary.fromJson(
          json['summary'] as Map<String, dynamic>? ?? {}),
    );
  }
}
