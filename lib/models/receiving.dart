// Item in receiving cart (for creating receiving)
class ReceivingItem {
  final int itemId;
  final String itemName;
  final String? itemNumber;
  final int line;
  final double quantity;
  final double costPrice;
  final double unitPrice;
  final int itemLocation;
  final double? availableStock; // Current stock before receiving

  ReceivingItem({
    required this.itemId,
    required this.itemName,
    this.itemNumber,
    required this.line,
    required this.quantity,
    required this.costPrice,
    required this.unitPrice,
    this.itemLocation = 1,
    this.availableStock,
  });

  // Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'quantity': quantity,
      'cost_price': costPrice,
      'unit_price': unitPrice,
      'item_location': itemLocation,
    };
  }

  // Create copy with updated fields
  ReceivingItem copyWith({
    int? itemId,
    String? itemName,
    String? itemNumber,
    int? line,
    double? quantity,
    double? costPrice,
    double? unitPrice,
    int? itemLocation,
    double? availableStock,
  }) {
    return ReceivingItem(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      itemNumber: itemNumber ?? this.itemNumber,
      line: line ?? this.line,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      itemLocation: itemLocation ?? this.itemLocation,
      availableStock: availableStock ?? this.availableStock,
    );
  }

  // Calculate line total
  double calculateTotal() {
    return quantity * costPrice;
  }
}

// Receiving in list view
class ReceivingListItem {
  final int receivingId;
  final String receivingTime;
  final int supplierId;
  final String supplierName;
  final String employeeName;
  final String paymentType;
  final String reference;
  final int totalItems;
  final double totalCost;

  ReceivingListItem({
    required this.receivingId,
    required this.receivingTime,
    required this.supplierId,
    required this.supplierName,
    required this.employeeName,
    required this.paymentType,
    required this.reference,
    required this.totalItems,
    required this.totalCost,
  });

  factory ReceivingListItem.fromJson(Map<String, dynamic> json) {
    return ReceivingListItem(
      receivingId: json['receiving_id'] ?? 0,
      receivingTime: json['receiving_time'] ?? '',
      supplierId: json['supplier_id'] ?? 0,
      supplierName: json['supplier_name'] ?? '',
      employeeName: json['employee_name'] ?? '',
      paymentType: json['payment_type'] ?? '',
      reference: json['reference'] ?? '',
      totalItems: json['total_items'] ?? 0,
      totalCost: (json['total_cost'] ?? 0).toDouble(),
    );
  }
}

// Receiving item for details view
class ReceivingDetailItem {
  final int itemId;
  final String itemName;
  final String itemNumber;
  final String description;
  final String serialNumber;
  final double quantity;
  final double receivingQuantity;
  final double costPrice;
  final double unitPrice;
  final double discount;
  final int discountType;
  final double lineTotal;

  ReceivingDetailItem({
    required this.itemId,
    required this.itemName,
    required this.itemNumber,
    required this.description,
    required this.serialNumber,
    required this.quantity,
    required this.receivingQuantity,
    required this.costPrice,
    required this.unitPrice,
    required this.discount,
    required this.discountType,
    required this.lineTotal,
  });

  factory ReceivingDetailItem.fromJson(Map<String, dynamic> json) {
    return ReceivingDetailItem(
      itemId: json['item_id'] ?? 0,
      itemName: json['item_name'] ?? '',
      itemNumber: json['item_number'] ?? '',
      description: json['description'] ?? '',
      serialNumber: json['serial_number'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      receivingQuantity: (json['receiving_quantity'] ?? 0).toDouble(),
      costPrice: (json['cost_price'] ?? 0).toDouble(),
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      discountType: json['discount_type'] ?? 0,
      lineTotal: (json['line_total'] ?? 0).toDouble(),
    );
  }
}

// Receiving details (for viewing completed receiving)
class ReceivingDetails {
  final int receivingId;
  final int supplierId;
  final String supplierName;
  final int employeeId;
  final String receivingTime;
  final String paymentType;
  final String comment;
  final String reference;
  final double total;
  final List<ReceivingDetailItem> items;

  ReceivingDetails({
    required this.receivingId,
    required this.supplierId,
    required this.supplierName,
    required this.employeeId,
    required this.receivingTime,
    required this.paymentType,
    required this.comment,
    required this.reference,
    required this.total,
    required this.items,
  });

  factory ReceivingDetails.fromJson(Map<String, dynamic> json) {
    var itemsJson = json['items'] as List? ?? [];
    List<ReceivingDetailItem> itemsList = itemsJson
        .map((item) => ReceivingDetailItem.fromJson(item))
        .toList();

    return ReceivingDetails(
      receivingId: json['receiving_id'] ?? 0,
      supplierId: json['supplier_id'] ?? 0,
      supplierName: json['supplier_name'] ?? '',
      employeeId: json['employee_id'] ?? 0,
      receivingTime: json['receiving_time'] ?? '',
      paymentType: json['payment_type'] ?? '',
      comment: json['comment'] ?? '',
      reference: json['reference'] ?? '',
      total: (json['total'] ?? 0).toDouble(),
      items: itemsList,
    );
  }
}

// Receiving to create (sent to API)
class Receiving {
  final int supplierId;
  final int? employeeId;
  final String? comment;
  final String? reference;
  final String paymentType;
  final int stockLocation;
  final List<ReceivingItem> items;

  Receiving({
    required this.supplierId,
    this.employeeId,
    this.comment,
    this.reference,
    this.paymentType = 'Cash',
    this.stockLocation = 1,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'supplier_id': supplierId,
      if (employeeId != null) 'employee_id': employeeId,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
      if (reference != null && reference!.isNotEmpty) 'reference': reference,
      'payment_type': paymentType,
      'stock_location': stockLocation,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

// ======== Main Store Models ========

/// Item in a mainstore sale
class MainStoreSaleItem {
  final int itemId;
  final String itemNumber;
  final String itemName;
  final double quantity;
  final double mainstoreUnitPrice;
  final double lerumaUnitPrice;
  final String status; // 'match' or 'mismatch'
  final double total;

  MainStoreSaleItem({
    required this.itemId,
    required this.itemNumber,
    required this.itemName,
    required this.quantity,
    required this.mainstoreUnitPrice,
    required this.lerumaUnitPrice,
    required this.status,
    required this.total,
  });

  factory MainStoreSaleItem.fromJson(Map<String, dynamic> json) {
    return MainStoreSaleItem(
      itemId: json['item_id'] ?? 0,
      itemNumber: json['item_number'] ?? '',
      itemName: json['item_name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      mainstoreUnitPrice: (json['mainstore_unit_price'] ?? 0).toDouble(),
      lerumaUnitPrice: (json['leruma_unit_price'] ?? 0).toDouble(),
      status: json['status'] ?? 'mismatch',
      total: (json['total'] ?? 0).toDouble(),
    );
  }

  bool get isMatch => status == 'match';
  bool get isMismatch => status == 'mismatch';
}

/// A sale from mainstore containing multiple items
class MainStoreSale {
  final int saleId;
  final String saleTime;
  final String customerName;
  final List<MainStoreSaleItem> items;
  final double saleTotal;

  MainStoreSale({
    required this.saleId,
    required this.saleTime,
    required this.customerName,
    required this.items,
    required this.saleTotal,
  });

  factory MainStoreSale.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List? ?? [];
    return MainStoreSale(
      saleId: json['sale_id'] ?? 0,
      saleTime: json['sale_time'] ?? '',
      customerName: json['customer_name'] ?? '',
      items: itemsJson.map((item) => MainStoreSaleItem.fromJson(item)).toList(),
      saleTotal: (json['sale_total'] ?? 0).toDouble(),
    );
  }

  /// Get all items for receiving cart
  List<Map<String, dynamic>> getItemsForReceiving() {
    return items.map((item) => {
      'item_id': item.itemId,
      'quantity': item.quantity,
    }).toList();
  }
}

/// Summary statistics for main store data
class MainStoreSummary {
  final int totalSales;
  final double totalQuantity;
  final double grandTotal;
  final int matchCount;
  final int mismatchCount;

  MainStoreSummary({
    required this.totalSales,
    required this.totalQuantity,
    required this.grandTotal,
    required this.matchCount,
    required this.mismatchCount,
  });

  factory MainStoreSummary.fromJson(Map<String, dynamic> json) {
    return MainStoreSummary(
      totalSales: json['total_sales'] ?? 0,
      totalQuantity: (json['total_quantity'] ?? 0).toDouble(),
      grandTotal: (json['grand_total'] ?? 0).toDouble(),
      matchCount: json['match_count'] ?? 0,
      mismatchCount: json['mismatch_count'] ?? 0,
    );
  }
}

/// Stock location for dropdown
class MainStoreLocation {
  final int locationId;
  final String locationName;

  MainStoreLocation({
    required this.locationId,
    required this.locationName,
  });

  factory MainStoreLocation.fromJson(Map<String, dynamic> json) {
    return MainStoreLocation(
      locationId: json['location_id'] ?? 0,
      locationName: json['location_name'] ?? '',
    );
  }
}

/// Complete main store response
class MainStoreData {
  final int locationId;
  final String locationName;
  final String date;
  final List<MainStoreSale> sales;
  final MainStoreSummary summary;
  final List<MainStoreLocation> stockLocations;

  MainStoreData({
    required this.locationId,
    required this.locationName,
    required this.date,
    required this.sales,
    required this.summary,
    required this.stockLocations,
  });

  factory MainStoreData.fromJson(Map<String, dynamic> json) {
    final salesJson = json['sales'] as List? ?? [];
    final locationsJson = json['stock_locations'] as List? ?? [];

    return MainStoreData(
      locationId: json['location_id'] ?? 0,
      locationName: json['location_name'] ?? '',
      date: json['date'] ?? '',
      sales: salesJson.map((s) => MainStoreSale.fromJson(s)).toList(),
      summary: MainStoreSummary.fromJson(json['summary'] ?? {}),
      stockLocations: locationsJson.map((l) => MainStoreLocation.fromJson(l)).toList(),
    );
  }

  /// Get all items from all sales for "Copy All" functionality
  List<Map<String, dynamic>> getAllItemsForReceiving() {
    List<Map<String, dynamic>> allItems = [];
    for (final sale in sales) {
      allItems.addAll(sale.getItemsForReceiving());
    }
    return allItems;
  }
}
