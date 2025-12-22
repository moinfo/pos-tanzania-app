/// Model for suspended sheet2 item (delivery sheet - no prices)
class SuspendedSheet2Item {
  final int itemId;
  final String itemName;
  final double quantity;
  final int freeQuantity;

  SuspendedSheet2Item({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.freeQuantity,
  });

  factory SuspendedSheet2Item.fromJson(Map<String, dynamic> json) {
    return SuspendedSheet2Item(
      itemId: json['item_id'] is int ? json['item_id'] : int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      quantity: _parseDouble(json['quantity']),
      freeQuantity: json['free_quantity'] is int ? json['free_quantity'] : int.tryParse(json['free_quantity'].toString()) ?? 0,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

/// Model for suspended sale sheet2 (delivery sheet format - no prices)
class SuspendedSheet2Sale {
  final int saleId;
  final String saleTime;
  final int employeeId;
  final String? employeeName;
  final int? customerId;
  final String customerName;
  final String? customerPhone;
  final String? comment;
  final List<SuspendedSheet2Item> items;
  final double totalQuantity;

  SuspendedSheet2Sale({
    required this.saleId,
    required this.saleTime,
    required this.employeeId,
    this.employeeName,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.comment,
    required this.items,
    required this.totalQuantity,
  });

  factory SuspendedSheet2Sale.fromJson(Map<String, dynamic> json) {
    return SuspendedSheet2Sale(
      saleId: json['sale_id'] is int ? json['sale_id'] : int.tryParse(json['sale_id'].toString()) ?? 0,
      saleTime: json['sale_time']?.toString() ?? '',
      employeeId: json['employee_id'] is int ? json['employee_id'] : int.tryParse(json['employee_id'].toString()) ?? 0,
      employeeName: json['employee_name']?.toString(),
      customerId: json['customer_id'] != null
          ? (json['customer_id'] is int ? json['customer_id'] : int.tryParse(json['customer_id'].toString()))
          : null,
      customerName: json['customer_name']?.toString() ?? 'Walk-in Customer',
      customerPhone: json['customer_phone']?.toString(),
      comment: json['comment']?.toString(),
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => SuspendedSheet2Item.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      totalQuantity: _parseDouble(json['total_quantity']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  /// Get formatted sale time
  String get formattedTime {
    try {
      final dt = DateTime.parse(saleTime);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return saleTime;
    }
  }

  /// Check if any item has free quantity
  bool get hasFreeItems {
    return items.any((item) => item.freeQuantity > 0);
  }
}