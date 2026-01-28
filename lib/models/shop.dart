/// Shop model representing a physical shop location with GPS coordinates
class Shop {
  final int shopId;
  final int customerId;
  final String shopName;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime createdAt;
  final int employeeId;
  final String? registeredBy;
  final DateTime? lastServiceDate;
  final int? daysSinceService;
  final ShopCustomer? customer;

  Shop({
    required this.shopId,
    required this.customerId,
    required this.shopName,
    this.latitude,
    this.longitude,
    this.address,
    required this.createdAt,
    required this.employeeId,
    this.registeredBy,
    this.lastServiceDate,
    this.daysSinceService,
    this.customer,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      shopId: json['shop_id'] as int,
      customerId: json['customer_id'] as int,
      shopName: json['shop_name'] as String,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      address: json['address'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      employeeId: json['employee_id'] as int,
      registeredBy: json['registered_by'] as String?,
      lastServiceDate: json['last_service_date'] != null
          ? DateTime.parse(json['last_service_date'] as String)
          : null,
      daysSinceService: json['days_since_service'] as int?,
      customer: json['customer'] != null
          ? ShopCustomer.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'customer_id': customerId,
      'shop_name': shopName,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'created_at': createdAt.toIso8601String(),
      'employee_id': employeeId,
      'registered_by': registeredBy,
      'last_service_date': lastServiceDate?.toIso8601String(),
      'days_since_service': daysSinceService,
      if (customer != null) 'customer': customer!.toJson(),
    };
  }

  bool get hasLocation => latitude != null && longitude != null;

  /// Get service status text
  String get serviceStatusText {
    if (daysSinceService == null) return 'Never serviced';
    if (daysSinceService == 0) return 'Serviced today';
    if (daysSinceService == 1) return '1 day ago';
    return '$daysSinceService days ago';
  }
}

/// Simplified customer info embedded in shop response
class ShopCustomer {
  final int personId;
  final String name;
  final String? companyName;
  final String? phoneNumber;
  final String? email;

  ShopCustomer({
    required this.personId,
    required this.name,
    this.companyName,
    this.phoneNumber,
    this.email,
  });

  factory ShopCustomer.fromJson(Map<String, dynamic> json) {
    return ShopCustomer(
      personId: json['person_id'] as int,
      name: json['name'] as String,
      companyName: json['company_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'person_id': personId,
      'name': name,
      'company_name': companyName,
      'phone_number': phoneNumber,
      'email': email,
    };
  }

  String get displayName => companyName?.isNotEmpty == true ? companyName! : name;
}

/// Form data for creating a new shop
class ShopFormData {
  final int customerId;
  final String shopName;
  final double? latitude;
  final double? longitude;
  final String? address;

  ShopFormData({
    required this.customerId,
    required this.shopName,
    this.latitude,
    this.longitude,
    this.address,
  });

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'shop_name': shopName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null) 'address': address,
    };
  }
}

/// Service history item (sale item)
class ServiceHistoryItem {
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double discount;
  final int discountType; // 0 = percentage, 1 = fixed amount
  final double lineTotal;

  ServiceHistoryItem({
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.discountType,
    required this.lineTotal,
  });

  /// Returns human-readable discount text
  String get discountText {
    if (discount == 0) return '';
    return discountType == 0 ? '${discount.toStringAsFixed(0)}%' : 'TZS ${discount.toStringAsFixed(0)}';
  }

  factory ServiceHistoryItem.fromJson(Map<String, dynamic> json) {
    return ServiceHistoryItem(
      itemName: json['item_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      discountType: json['discount_type'] as int,
      lineTotal: (json['line_total'] as num).toDouble(),
    );
  }
}

/// Service history entry (sale)
class ServiceHistory {
  final int saleId;
  final DateTime saleTime;
  final double subTotal;
  final double tax;
  final double total;
  final String? paymentType;
  final String? servedBy;
  final List<ServiceHistoryItem> items;

  ServiceHistory({
    required this.saleId,
    required this.saleTime,
    required this.subTotal,
    required this.tax,
    required this.total,
    this.paymentType,
    this.servedBy,
    required this.items,
  });

  factory ServiceHistory.fromJson(Map<String, dynamic> json) {
    return ServiceHistory(
      saleId: json['sale_id'] as int,
      saleTime: DateTime.parse(json['sale_time'] as String),
      subTotal: (json['sub_total'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      paymentType: json['payment_type'] as String?,
      servedBy: json['served_by'] as String?,
      items: (json['items'] as List<dynamic>)
          .map((item) => ServiceHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
