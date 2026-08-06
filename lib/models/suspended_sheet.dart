/// Model for suspended sheet sale item
class SuspendedSheetItem {
  final int itemId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double lineTotal;

  SuspendedSheetItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
  });

  factory SuspendedSheetItem.fromJson(Map<String, dynamic> json) {
    return SuspendedSheetItem(
      itemId: json['item_id'] is int ? json['item_id'] : int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      quantity: _parseDouble(json['quantity']),
      unitPrice: _parseDouble(json['unit_price']),
      discount: _parseDouble(json['discount']),
      lineTotal: _parseDouble(json['line_total']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

/// Model for suspended sale with items (for sheet display)
class SuspendedSheetSale {
  final int saleId;
  final String saleTime;
  final int employeeId;
  final String? employeeName;
  final int? customerId;
  final String customerName;
  final String? customerPhone;
  final String? comment;
  final List<SuspendedSheetItem> items;
  final double saleTotal;

  /// Resume claim held by another seller. The server only reports a claim
  /// while it is fresh (15 minutes), so a stale one reads as unlocked here.
  final bool isLocked;
  final int? lockedBy;
  final String? lockedByName;

  SuspendedSheetSale({
    required this.saleId,
    required this.saleTime,
    required this.employeeId,
    this.employeeName,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.comment,
    required this.items,
    required this.saleTotal,
    this.isLocked = false,
    this.lockedBy,
    this.lockedByName,
  });

  factory SuspendedSheetSale.fromJson(Map<String, dynamic> json) {
    return SuspendedSheetSale(
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
          ?.map((item) => SuspendedSheetItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      saleTotal: _parseDouble(json['sale_total']),
      // Absent on servers without the suspended-sale lock, so default unlocked.
      isLocked: json['is_locked'] == true || json['is_locked'] == 1,
      lockedBy: json['locked_by'] != null
          ? (json['locked_by'] is int
              ? json['locked_by']
              : int.tryParse(json['locked_by'].toString()))
          : null,
      lockedByName: json['locked_by_name']?.toString(),
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
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return saleTime;
    }
  }

  /// Get total quantity of all items
  double get totalQuantity {
    return items.fold(0.0, (sum, item) => sum + item.quantity);
  }
}