/// Model for one-time discount in sales
class OneTimeDiscount {
  final int discountId;
  final String documentNumber;
  final int customerId;
  final String? customerName;
  final int itemId;
  final String? itemName;
  final String? itemNumber;
  final int stockLocationId;
  final String? locationName;
  final double quantity;
  final double discountAmount;
  final String validDate;
  final String status;
  final String? reason;
  final String? createdAt;

  OneTimeDiscount({
    required this.discountId,
    required this.documentNumber,
    required this.customerId,
    this.customerName,
    required this.itemId,
    this.itemName,
    this.itemNumber,
    required this.stockLocationId,
    this.locationName,
    required this.quantity,
    required this.discountAmount,
    required this.validDate,
    required this.status,
    this.reason,
    this.createdAt,
  });

  factory OneTimeDiscount.fromJson(Map<String, dynamic> json) {
    return OneTimeDiscount(
      discountId: json['discount_id'] is int
          ? json['discount_id']
          : int.tryParse(json['discount_id']?.toString() ?? '') ?? 0,
      documentNumber: json['document_number']?.toString() ?? '',
      customerId: json['customer_id'] is int
          ? json['customer_id']
          : int.tryParse(json['customer_id']?.toString() ?? '') ?? 0,
      customerName: json['customer_name']?.toString(),
      itemId: json['item_id'] is int
          ? json['item_id']
          : int.tryParse(json['item_id']?.toString() ?? '') ?? 0,
      itemName: json['item_name']?.toString(),
      itemNumber: json['item_number']?.toString(),
      stockLocationId: json['stock_location_id'] is int
          ? json['stock_location_id']
          : int.tryParse(json['stock_location_id']?.toString() ?? '') ?? 0,
      locationName: json['location_name']?.toString(),
      quantity: (json['quantity'] is num)
          ? (json['quantity'] as num).toDouble()
          : double.tryParse(json['quantity']?.toString() ?? '') ?? 0.0,
      discountAmount: (json['discount_amount'] is num)
          ? (json['discount_amount'] as num).toDouble()
          : double.tryParse(json['discount_amount']?.toString() ?? '') ?? 0.0,
      validDate: json['valid_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      reason: json['reason']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'discount_id': discountId,
      'document_number': documentNumber,
      'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      'item_id': itemId,
      if (itemName != null) 'item_name': itemName,
      if (itemNumber != null) 'item_number': itemNumber,
      'stock_location_id': stockLocationId,
      if (locationName != null) 'location_name': locationName,
      'quantity': quantity,
      'discount_amount': discountAmount,
      'valid_date': validDate,
      'status': status,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  /// Helper to check if discount is valid for a given item quantity
  /// Discount only applies when quantity EXACTLY matches the required quantity
  bool isValidForQuantity(double itemQuantity) {
    return itemQuantity == quantity;
  }

  /// Helper to get the total discount amount for a given quantity
  /// Only returns discount if quantity exactly matches
  double getTotalDiscountAmount(double itemQuantity) {
    if (itemQuantity != quantity) {
      return 0;
    }
    return discountAmount * quantity;
  }

  @override
  String toString() {
    return 'OneTimeDiscount{discountId: $discountId, documentNumber: $documentNumber, '
        'itemName: $itemName, discountAmount: $discountAmount, quantity: $quantity, '
        'validDate: $validDate, status: $status}';
  }
}

/// Response from check discount API
class CheckDiscountResponse {
  final bool available;
  final OneTimeDiscount? discount;

  CheckDiscountResponse({
    required this.available,
    this.discount,
  });

  factory CheckDiscountResponse.fromJson(Map<String, dynamic> json) {
    return CheckDiscountResponse(
      available: json['available'] == true,
      discount: json['discount'] != null
          ? OneTimeDiscount.fromJson(json['discount'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Response from customer discounts API
class CustomerDiscountsResponse {
  final List<OneTimeDiscount> discounts;
  final int count;

  CustomerDiscountsResponse({
    required this.discounts,
    required this.count,
  });

  factory CustomerDiscountsResponse.fromJson(Map<String, dynamic> json) {
    return CustomerDiscountsResponse(
      discounts: (json['discounts'] as List<dynamic>?)
              ?.map((item) =>
                  OneTimeDiscount.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      count: json['count'] is int
          ? json['count']
          : int.tryParse(json['count']?.toString() ?? '') ?? 0,
    );
  }
}