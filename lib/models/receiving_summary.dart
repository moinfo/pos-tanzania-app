/// Model for receiving summary item comparing mainstore vs Leruma data
class ReceivingSummaryItem {
  final int itemId;
  final String itemName;
  final double mainstoreQuantity;
  final double mainstorePrice;
  final double lerumaQuantity;
  final double lerumaReceiving;
  final double differentQuantity;
  final double differentPrice;

  ReceivingSummaryItem({
    required this.itemId,
    required this.itemName,
    required this.mainstoreQuantity,
    required this.mainstorePrice,
    required this.lerumaQuantity,
    required this.lerumaReceiving,
    required this.differentQuantity,
    required this.differentPrice,
  });

  factory ReceivingSummaryItem.fromJson(Map<String, dynamic> json) {
    return ReceivingSummaryItem(
      itemId: json['item_id'] is int ? json['item_id'] : int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      mainstoreQuantity: _parseDouble(json['mainstore_quantity']),
      mainstorePrice: _parseDouble(json['mainstore_price']),
      lerumaQuantity: _parseDouble(json['leruma_quantity']),
      lerumaReceiving: _parseDouble(json['leruma_receiving']),
      differentQuantity: _parseDouble(json['different_quantity']),
      differentPrice: _parseDouble(json['different_price']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_name': itemName,
      'mainstore_quantity': mainstoreQuantity,
      'mainstore_price': mainstorePrice,
      'leruma_quantity': lerumaQuantity,
      'leruma_receiving': lerumaReceiving,
      'different_quantity': differentQuantity,
      'different_price': differentPrice,
    };
  }
}

/// Model for receiving summary totals
class ReceivingSummaryTotals {
  final double totalDifferentPrice;
  final double totalDifferentQuantity;

  ReceivingSummaryTotals({
    required this.totalDifferentPrice,
    required this.totalDifferentQuantity,
  });

  factory ReceivingSummaryTotals.fromJson(Map<String, dynamic> json) {
    return ReceivingSummaryTotals(
      totalDifferentPrice: _parseDouble(json['total_different_price']),
      totalDifferentQuantity: _parseDouble(json['total_different_quantity']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

/// Model for the full receiving summary response
class ReceivingSummaryResponse {
  final int locationId;
  final String locationName;
  final String startDate;
  final String endDate;
  final List<ReceivingSummaryItem> items;
  final ReceivingSummaryTotals totals;
  final List<String> allowedEmployees;

  ReceivingSummaryResponse({
    required this.locationId,
    required this.locationName,
    required this.startDate,
    required this.endDate,
    required this.items,
    required this.totals,
    required this.allowedEmployees,
  });

  factory ReceivingSummaryResponse.fromJson(Map<String, dynamic> json) {
    return ReceivingSummaryResponse(
      locationId: json['location_id'] is int ? json['location_id'] : int.tryParse(json['location_id'].toString()) ?? 0,
      locationName: json['location_name']?.toString() ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => ReceivingSummaryItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      totals: ReceivingSummaryTotals.fromJson(json['totals'] as Map<String, dynamic>? ?? {}),
      allowedEmployees: (json['allowed_employees'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }
}