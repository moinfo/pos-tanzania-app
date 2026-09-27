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

  /// The most this line may return, when it came from a past receiving.
  /// 50 received is 50 returnable; 51 is stock that was never delivered.
  /// Null on an ordinary line, which has no receiving to be measured against.
  final double? returnLimit;

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
    this.returnLimit,
  });

  /// Quantity held to what this line is allowed to return.
  double clampToReturnLimit(double value) {
    if (returnLimit == null) return value;
    final floor = -returnLimit!.abs();
    return value < floor ? floor : value;
  }

  bool get exceedsReturnLimit =>
      returnLimit != null && quantity < -returnLimit!.abs();

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
    double? returnLimit,
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
      returnLimit: returnLimit ?? this.returnLimit,
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

  /// This receiving IS a return -- it was booked with negative quantities.
  /// Returning it again would put the stock back, and again, and again.
  final bool isReturn;

  /// Units still returnable across the whole receiving, and whether nothing
  /// is left. Zero and false from a server that predates them.
  final double returnableTotal;
  final bool fullyReturned;

  /// The receiving that already returned this one, if any. Only a return
  /// made from the app records the link (reference "RECV <id>"); the web's
  /// return_entire_receiving records none, so null means "none known", not
  /// "definitely not returned".
  final int? returnedBy;

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
    this.isReturn = false,
    this.returnedBy,
    this.returnableTotal = 0,
    this.fullyReturned = false,
  });

  /// Something is still returnable. Being returned once does not close a
  /// receiving: 50 received and 30 returned leaves 20 that may still go
  /// back. What closes it is having nothing left.
  bool get canBeReturned => !isReturn && !fullyReturned && totalCost >= 0;

  /// Some of it has gone back, but not all.
  bool get partlyReturned => returnedBy != null && !fullyReturned;

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
      isReturn: json['is_return'] == true || json['is_return'] == 1,
      returnedBy: json['returned_by'] == null
          ? null
          : int.tryParse(json['returned_by'].toString()),
      returnableTotal: (json['returnable_total'] ?? 0).toDouble(),
      fullyReturned: json['fully_returned'] == true || json['fully_returned'] == 1,
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
  /// Which store this line's stock went into. A return has to take it back
  /// out of that same store. Null from a server that predates the field.
  final int? itemLocation;
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
    this.itemLocation,
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
      itemLocation: json['item_location'] == null ? null : int.tryParse(json['item_location'].toString()),
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

/// What is still returnable from a receiving, per item and store.
///
/// Not per line: a receiving can hold the same item and store on two lines,
/// and the balance is one number across them.
class ReceivingReturnable {
  final int itemId;
  final int itemLocation;
  final String itemName;
  final double costPrice;
  final double unitPrice;

  /// What the receiving brought in.
  final double received;

  /// What earlier returns have already taken back out.
  final double returned;

  /// What is left: received minus returned, never below zero.
  final double returnable;

  ReceivingReturnable({
    required this.itemId,
    required this.itemLocation,
    required this.itemName,
    required this.costPrice,
    required this.unitPrice,
    required this.received,
    required this.returned,
    required this.returnable,
  });

  factory ReceivingReturnable.fromJson(Map<String, dynamic> json) {
    return ReceivingReturnable(
      itemId: json['item_id'] ?? 0,
      itemLocation: json['item_location'] ?? 0,
      itemName: json['item_name'] ?? '',
      costPrice: (json['cost_price'] ?? 0).toDouble(),
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      received: (json['received'] ?? 0).toDouble(),
      returned: (json['returned'] ?? 0).toDouble(),
      returnable: (json['returnable'] ?? 0).toDouble(),
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

  /// See ReceivingListItem: this receiving is itself a return, and the
  /// receiving that already returned it.
  final bool isReturn;
  final int? returnedBy;

  /// What is still returnable, per item and store. Empty from a server that
  /// predates it, in which case the items themselves are the fallback.
  final List<ReceivingReturnable> returnable;

  /// Every item has been returned already; there is nothing left to take.
  final bool fullyReturned;

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
    this.isReturn = false,
    this.returnedBy,
    this.returnable = const [],
    this.fullyReturned = false,
    required this.items,
  });

  /// Something is still returnable. A return itself is never returnable; a
  /// delivery is, until its last unit has been taken back -- a second return
  /// of what remains is legitimate, a second return of the whole thing is not.
  bool get canBeReturned => !isReturn && !fullyReturned && total >= 0;

  /// Units still returnable across the whole receiving.
  double get returnableTotal =>
      returnable.fold(0.0, (sum, row) => sum + row.returnable);

  /// Some, but not all, has already been returned.
  bool get partlyReturned =>
      returnable.any((row) => row.returned > 0) && !fullyReturned;

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
      isReturn: json['is_return'] == true || json['is_return'] == 1,
      returnedBy: json['returned_by'] == null
          ? null
          : int.tryParse(json['returned_by'].toString()),
      returnable: (json['returnable'] as List? ?? [])
          .map((row) => ReceivingReturnable.fromJson(row))
          .toList(),
      fullyReturned: json['fully_returned'] == true || json['fully_returned'] == 1,
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

  /// The receiving being returned, when this is a return of one. The server
  /// caps the return against it; the reference says the same thing but a
  /// clerk can type over a reference.
  final int? returnOf;

  Receiving({
    required this.supplierId,
    this.employeeId,
    this.comment,
    this.reference,
    this.returnOf,
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
      if (returnOf != null) 'return_of': returnOf,
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

  /// Leruma's cost price -- what the web receives at (add_ms_to_cart). Null
  /// only from a server that predates the field.
  final double? lerumaCostPrice;
  final String status; // 'match' or 'mismatch'
  final double total;

  MainStoreSaleItem({
    required this.itemId,
    required this.itemNumber,
    required this.itemName,
    required this.quantity,
    required this.mainstoreUnitPrice,
    required this.lerumaUnitPrice,
    this.lerumaCostPrice,
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
      lerumaCostPrice: json['leruma_cost_price'] == null
          ? null
          : double.tryParse(json['leruma_cost_price'].toString()),
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
