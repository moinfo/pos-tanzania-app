/// Model for suspended items summary
class SuspendedSummaryItem {
  final int itemId;
  final int locationId;
  final String itemName;
  final double suspendedQuantity;
  final double bongeQuantity;
  final double difference;
  final double totalAmount;
  final double weight;

  SuspendedSummaryItem({
    required this.itemId,
    required this.locationId,
    required this.itemName,
    required this.suspendedQuantity,
    required this.bongeQuantity,
    required this.difference,
    required this.totalAmount,
    required this.weight,
  });

  factory SuspendedSummaryItem.fromJson(Map<String, dynamic> json) {
    return SuspendedSummaryItem(
      itemId: json['item_id'] is int
          ? json['item_id']
          : int.tryParse(json['item_id'].toString()) ?? 0,
      locationId: json['location_id'] is int
          ? json['location_id']
          : int.tryParse(json['location_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      suspendedQuantity: _parseDouble(json['suspended_quantity']),
      bongeQuantity: _parseDouble(json['bonge_quantity']),
      difference: _parseDouble(json['difference']),
      totalAmount: _parseDouble(json['total_amount']),
      weight: _parseDouble(json['weight']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

/// Suspended summary totals
class SuspendedSummaryTotals {
  final double totalQuantity;
  final double grandTotal;
  final double totalWeight;
  final int itemCount;

  SuspendedSummaryTotals({
    required this.totalQuantity,
    required this.grandTotal,
    required this.totalWeight,
    required this.itemCount,
  });

  factory SuspendedSummaryTotals.fromJson(Map<String, dynamic> json) {
    return SuspendedSummaryTotals(
      totalQuantity: _parseDouble(json['total_quantity']),
      grandTotal: _parseDouble(json['grand_total']),
      totalWeight: _parseDouble(json['total_weight']),
      itemCount: json['item_count'] is int
          ? json['item_count']
          : int.tryParse(json['item_count'].toString()) ?? 0,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

/// Suspended summary response
class SuspendedSummaryResponse {
  final List<SuspendedSummaryItem> items;
  final SuspendedSummaryTotals totals;

  SuspendedSummaryResponse({
    required this.items,
    required this.totals,
  });

  factory SuspendedSummaryResponse.fromJson(Map<String, dynamic> json) {
    return SuspendedSummaryResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) =>
                  SuspendedSummaryItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      totals: SuspendedSummaryTotals.fromJson(
          json['totals'] as Map<String, dynamic>? ?? {}),
    );
  }
}
