class StockLocation {
  final int locationId;
  final String locationName;
  final bool deleted;

  StockLocation({
    required this.locationId,
    required this.locationName,
    this.deleted = false,
  });

  factory StockLocation.fromJson(Map<String, dynamic> json) {
    return StockLocation(
      locationId: json['location_id'] is int
          ? json['location_id']
          : int.parse(json['location_id'].toString()),
      locationName: json['location_name'] ?? '',
      deleted: json['deleted'] == 1 || json['deleted'] == '1' || json['deleted'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location_id': locationId,
      'location_name': locationName,
      'deleted': deleted ? 1 : 0,
    };
  }

  @override
  String toString() => 'StockLocation(id: $locationId, name: $locationName)';
}

/// Item quantity at a specific location
class ItemQuantityLocation {
  final int locationId;
  final String locationName;
  final double quantity;

  ItemQuantityLocation({
    required this.locationId,
    required this.locationName,
    required this.quantity,
  });

  factory ItemQuantityLocation.fromJson(Map<String, dynamic> json) {
    return ItemQuantityLocation(
      locationId: json['location_id'] is int
          ? json['location_id']
          : int.parse(json['location_id'].toString()),
      locationName: json['location_name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location_id': locationId,
      'location_name': locationName,
      'quantity': quantity,
    };
  }

  @override
  String toString() => '$locationName: $quantity';
}
