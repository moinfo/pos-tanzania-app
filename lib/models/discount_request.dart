/// Model for customer discount requests (SADA only)
class DiscountRequest {
  final int id;
  final int customerId;
  final String? customerName;
  final String? customerPhone;
  final int itemId;
  final String? itemName;
  final double quantity;
  final double discount;
  final int discountType; // 0=percent, 1=fixed (always 1)
  final String status; // pending, approved, rejected, used
  final int requestedBy;
  final String? requestedByName;
  final int? approvedBy;
  final String? approvedByName;
  final String? createdAt;
  final String? approvedAt;
  final String? usedAt;
  final int? saleId;
  final String? notes;

  DiscountRequest({
    required this.id,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    required this.itemId,
    this.itemName,
    required this.quantity,
    required this.discount,
    this.discountType = 1,
    required this.status,
    required this.requestedBy,
    this.requestedByName,
    this.approvedBy,
    this.approvedByName,
    this.createdAt,
    this.approvedAt,
    this.usedAt,
    this.saleId,
    this.notes,
  });

  factory DiscountRequest.fromJson(Map<String, dynamic> json) {
    return DiscountRequest(
      id: _parseInt(json['id']),
      customerId: _parseInt(json['customer_id']),
      customerName: json['customer_name']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      itemId: _parseInt(json['item_id']),
      itemName: json['item_name']?.toString(),
      quantity: _parseDouble(json['quantity']),
      discount: _parseDouble(json['discount']),
      discountType: _parseInt(json['discount_type'], fallback: 1),
      status: json['status']?.toString() ?? 'pending',
      requestedBy: _parseInt(json['requested_by']),
      requestedByName: json['requested_by_name']?.toString(),
      approvedBy: json['approved_by'] != null ? _parseInt(json['approved_by']) : null,
      approvedByName: json['approved_by_name']?.toString(),
      createdAt: json['created_at']?.toString(),
      approvedAt: json['approved_at']?.toString(),
      usedAt: json['used_at']?.toString(),
      saleId: json['sale_id'] != null ? _parseInt(json['sale_id']) : null,
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'item_id': itemId,
      'quantity': quantity,
      'discount': discount,
      'discount_type': discountType,
      'status': status,
      'requested_by': requestedBy,
      if (notes != null) 'notes': notes,
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isUsed => status == 'used';

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  String toString() {
    return 'DiscountRequest{id: $id, customer: $customerName, item: $itemName, '
        'discount: $discount, status: $status}';
  }
}

/// Response for discount request list
class DiscountRequestListResponse {
  final List<DiscountRequest> requests;
  final int total;

  DiscountRequestListResponse({
    required this.requests,
    required this.total,
  });

  factory DiscountRequestListResponse.fromJson(Map<String, dynamic> json) {
    return DiscountRequestListResponse(
      requests: (json['requests'] as List<dynamic>?)
              ?.map((item) => DiscountRequest.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] is int
          ? json['total']
          : int.tryParse(json['total']?.toString() ?? '') ?? 0,
    );
  }
}

/// Response for check approved discount
class CheckApprovedDiscountResponse {
  final bool hasApproved;
  final int? requestId;
  final double? discount;
  final int? discountType;
  final double? quantity;

  CheckApprovedDiscountResponse({
    required this.hasApproved,
    this.requestId,
    this.discount,
    this.discountType,
    this.quantity,
  });

  factory CheckApprovedDiscountResponse.fromJson(Map<String, dynamic> json) {
    return CheckApprovedDiscountResponse(
      hasApproved: json['has_approved'] == true,
      requestId: json['request_id'] != null
          ? (json['request_id'] is int ? json['request_id'] : int.tryParse(json['request_id'].toString()))
          : null,
      discount: json['discount'] != null
          ? (json['discount'] is num ? (json['discount'] as num).toDouble() : double.tryParse(json['discount'].toString()))
          : null,
      discountType: json['discount_type'] != null
          ? (json['discount_type'] is int ? json['discount_type'] : int.tryParse(json['discount_type'].toString()))
          : null,
      quantity: json['quantity'] != null
          ? (json['quantity'] is num ? (json['quantity'] as num).toDouble() : double.tryParse(json['quantity'].toString()))
          : null,
    );
  }
}

/// Response for item prices (discount validation)
class ItemPricesResponse {
  final int itemId;
  final String? itemName;
  final double sellingPrice;
  final double costPrice;
  final double profitMargin;
  final double maxDiscount;
  final String category;
  final bool isSembe;

  ItemPricesResponse({
    required this.itemId,
    this.itemName,
    required this.sellingPrice,
    required this.costPrice,
    required this.profitMargin,
    required this.maxDiscount,
    required this.category,
    required this.isSembe,
  });

  factory ItemPricesResponse.fromJson(Map<String, dynamic> json) {
    return ItemPricesResponse(
      itemId: json['item_id'] is int ? json['item_id'] : int.tryParse(json['item_id']?.toString() ?? '') ?? 0,
      itemName: json['item_name']?.toString(),
      sellingPrice: (json['selling_price'] is num) ? (json['selling_price'] as num).toDouble() : double.tryParse(json['selling_price']?.toString() ?? '') ?? 0,
      costPrice: (json['cost_price'] is num) ? (json['cost_price'] as num).toDouble() : double.tryParse(json['cost_price']?.toString() ?? '') ?? 0,
      profitMargin: (json['profit_margin'] is num) ? (json['profit_margin'] as num).toDouble() : double.tryParse(json['profit_margin']?.toString() ?? '') ?? 0,
      maxDiscount: (json['max_discount'] is num) ? (json['max_discount'] as num).toDouble() : double.tryParse(json['max_discount']?.toString() ?? '') ?? 0,
      category: json['category']?.toString() ?? '',
      isSembe: json['is_sembe'] == true,
    );
  }
}
