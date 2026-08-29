class Sale {
  final int? saleId;
  final String saleTime;
  final int? customerId;
  final String? customerName;

  /// Where the receipt SMS goes, when the list endpoint supplies it.
  final String? customerPhone;
  final int employeeId;
  final String? employeeName;
  final String? comment;
  final String? invoiceNumber;
  final int saleStatus; // 0=completed, 2=suspended
  final int saleType; // 0=POS, 1=Invoice, 2=Return
  // Stock location the sale belongs to. The web writes this to sales.stock_location_id;
  // without it a sale created here lands with no location and drops out of the
  // location-filtered reports (Z-report, today summary, commission dashboard).
  final int? stockLocationId;
  final double subtotal;
  final double taxTotal;
  final double total;

  /// Sum of line discounts on this sale (stored line totals). Zero when the
  /// server does not report it.
  final double totalDiscount;
  final String? paymentType;
  final List<SaleItem>? items;
  final List<SalePayment>? payments;
  final bool? hasOfferItems; // True if sale has quantity offer free items

  Sale({
    this.saleId,
    required this.saleTime,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.employeeId,
    this.employeeName,
    this.comment,
    this.invoiceNumber,
    this.saleStatus = 0,
    this.saleType = 0,
    this.stockLocationId,
    this.subtotal = 0,
    this.taxTotal = 0,
    this.total = 0,
    this.totalDiscount = 0,
    this.paymentType,
    this.items,
    this.payments,
    this.hasOfferItems,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      saleId: json['sale_id'] as int?,
      saleTime: json['sale_time'] as String,
      customerId: json['customer_id'] as int?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      employeeId: json['employee_id'] as int,
      employeeName: json['employee_name'] as String?,
      comment: json['comment'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      saleStatus: json['sale_status'] as int? ?? 0,
      saleType: json['sale_type'] as int? ?? 0,
      stockLocationId: json['stock_location_id'] as int?,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      taxTotal: (json['tax_total'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? (json['total_amount'] as num?)?.toDouble() ?? 0,
      totalDiscount: (json['total_discount'] as num?)?.toDouble() ?? 0,
      paymentType: json['payment_type'] as String?,
      items: json['items'] != null
          ? (json['items'] as List).map((i) => SaleItem.fromJson(i)).toList()
          : null,
      payments: json['payments'] != null
          ? (json['payments'] as List).map((p) => SalePayment.fromJson(p)).toList()
          : null,
      hasOfferItems: json['has_offer_items'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (saleId != null) 'sale_id': saleId,
      'sale_time': saleTime,
      if (customerId != null) 'customer_id': customerId,
      'employee_id': employeeId,
      if (comment != null) 'comment': comment,
      'sale_status': saleStatus,
      'sale_type': saleType,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      'subtotal': subtotal,
      'tax_total': taxTotal,
      'total': total,
      if (items != null) 'items': items!.map((i) => i.toJson()).toList(),
      if (payments != null) 'payments': payments!.map((p) => p.toJson()).toList(),
    };
  }

  // For creating a new sale request
  Map<String, dynamic> toCreateJson() {
    return {
      if (customerId != null) 'customer_id': customerId,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
      'sale_type': saleType,
      'sale_date': saleTime,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      'items': items!.map((i) => i.toCreateJson()).toList(),
      'payments': payments!.map((p) => p.toJson()).toList(),
    };
  }
}

class SaleItem {
  final int itemId;
  final String itemName;
  final int line;
  final double quantity;
  final double costPrice;
  final double unitPrice;
  final double discount;
  final int discountType; // 0=percent, 1=fixed
  final int? discountLimit; // Maximum discount allowed
  final String? description;
  final String? serialNumber;
  final int? stockLocationId;
  final double subtotal;
  final double lineTotal;
  final List<SaleTax>? taxes;
  final double? availableStock; // Available stock quantity (for display in cart)

  // Quantity offer fields
  final bool quantityOfferFree; // True if this is a free item from an offer
  final int? parentLine; // Line number of parent item (for free items)
  final int? quantityOfferId; // Offer ID that generated this free item

  // One-time discount already applied to this line. Carried through suspend
  // and resume so the line keeps knowing where its discount came from -- the
  // discount is marked 'used' at first suspend, so it can never be re-earned
  // by a live availability check.
  final int? oneTimeDiscountId;

  /// Carried from the Item this line was added from so the cart can warn
  /// about Credit Card restrictions before checkout (see
  /// Customer.isCreditCardRestricted). Display-only -- the server holds its
  /// own copy and re-checks it independently, so this is never sent back.
  final bool noCreditCard;

  SaleItem({
    required this.itemId,
    required this.itemName,
    this.line = 0,
    required this.quantity,
    required this.costPrice,
    required this.unitPrice,
    this.discount = 0,
    this.discountType = 0,
    this.discountLimit,
    this.description,
    this.serialNumber,
    this.stockLocationId,
    double? subtotal,
    double? lineTotal,
    this.taxes,
    this.availableStock,
    this.quantityOfferFree = false,
    this.parentLine,
    this.quantityOfferId,
    this.oneTimeDiscountId,
    this.noCreditCard = false,
  })  : subtotal = subtotal ?? (quantity * unitPrice),
        lineTotal = lineTotal ?? (quantity * unitPrice);

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      itemId: json['item_id'] as int,
      itemName: json['item_name'] as String,
      line: json['line'] as int? ?? 0,
      quantity: (json['quantity'] as num).toDouble(),
      costPrice: (json['cost_price'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      // discount_raw is the stored line value (total for fixed, percent for
      // percent) that pairs with discount_type; plain 'discount' is a computed
      // total amount kept for older servers, only safe as a fixed amount.
      discount: ((json['discount_raw'] ?? json['discount']) as num?)?.toDouble() ?? 0,
      // Default fixed, not percent: a server that omits the type sent a
      // computed amount, and reading an amount as a percentage explodes.
      discountType: json['discount_type'] as int? ?? 1,
      oneTimeDiscountId: json['one_time_discount_id'] as int?,
      discountLimit: json['discount_limit'] as int? ?? 0,
      description: json['description'] as String?,
      serialNumber: json['serial_number'] as String?,
      stockLocationId: json['stock_location_id'] as int?,
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      lineTotal: (json['line_total'] as num?)?.toDouble(),
      // The other half of the toCreateJson() fix: the server now sends these
      // back on resume (_format_sale_item), but nothing here ever read them,
      // so a restored reward line always came back as an ordinary paid line
      // no matter how correct the server's answer was. That is what made the
      // group-offer sync unable to recognise it as already earned, and add a
      // second one on top.
      quantityOfferFree: json['quantity_offer_free'] == true,
      quantityOfferId: json['quantity_offer_id'] == null
          ? null
          : (json['quantity_offer_id'] as num).toInt(),
      taxes: json['taxes'] != null
          ? (json['taxes'] as List).map((t) => SaleTax.fromJson(t)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_name': itemName,
      'line': line,
      'quantity': quantity,
      'cost_price': costPrice,
      'unit_price': unitPrice,
      'discount': discount,
      'discount_type': discountType,
      if (description != null) 'description': description,
      if (serialNumber != null) 'serial_number': serialNumber,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      'subtotal': subtotal,
      'line_total': lineTotal,
      if (taxes != null) 'taxes': taxes!.map((t) => t.toJson()).toList(),
    };
  }

  // For creating a new sale item request
  // Note: Backend API multiplies FIXED discount by quantity, so send per-unit value
  Map<String, dynamic> toCreateJson() {
    // For FIXED discount (type=1), cart stores total (per_unit * qty),
    // but backend expects per-unit and handles multiplication
    double discountToSend = discount;
    if (discountType == 1 && discount > 0 && quantity > 0) {
      discountToSend = discount / quantity;
    }

    return {
      'item_id': itemId,
      'quantity': quantity,
      'cost_price': costPrice,
      'unit_price': unitPrice,
      if (discount > 0) 'discount': discountToSend,
      if (discount > 0) 'discount_type': discountType, // 0=percent, 1=fixed
      if (description != null) 'description': description,
      if (serialNumber != null) 'serial_number': serialNumber,
      if (stockLocationId != null) 'item_location': stockLocationId, // Include stock location
      // Suspend persists this on the row so a later resume still knows the
      // discount's origin; create() ignores it.
      if (oneTimeDiscountId != null) 'one_time_discount_id': oneTimeDiscountId,
      // Same reasoning as one_time_discount_id above, for quantity/group
      // offers: without this, a suspended sale's reward line comes back from
      // resume looking like an ordinary paid line, the app finds no existing
      // reward for the offer, and adds a second one on top of the first.
      if (quantityOfferFree) 'quantity_offer_free': true,
      if (quantityOfferId != null) 'quantity_offer_id': quantityOfferId,
      if (taxes != null && taxes!.isNotEmpty)
        'taxes': taxes!.map((t) => t.toJson()).toList(),
    };
  }

  // Calculate line total with discount
  double calculateTotal() {
    double total = quantity * unitPrice;
    if (discount > 0) {
      if (discountType == 0) {
        // Percentage discount
        total = total * (1 - discount / 100);
      } else {
        // Fixed discount
        total = total - discount;
      }
    }
    return total;
  }

  // Copy with method for updating cart items
  SaleItem copyWith({
    int? itemId,
    String? itemName,
    int? line,
    double? quantity,
    double? costPrice,
    double? unitPrice,
    double? discount,
    int? discountType,
    int? discountLimit,
    String? description,
    String? serialNumber,
    int? stockLocationId,
    List<SaleTax>? taxes,
    double? availableStock,
    bool? quantityOfferFree,
    int? parentLine,
    int? quantityOfferId,
    int? oneTimeDiscountId,
    bool? noCreditCard,
  }) {
    return SaleItem(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      line: line ?? this.line,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      discountType: discountType ?? this.discountType,
      discountLimit: discountLimit ?? this.discountLimit,
      description: description ?? this.description,
      serialNumber: serialNumber ?? this.serialNumber,
      stockLocationId: stockLocationId ?? this.stockLocationId,
      taxes: taxes ?? this.taxes,
      availableStock: availableStock ?? this.availableStock,
      quantityOfferFree: quantityOfferFree ?? this.quantityOfferFree,
      parentLine: parentLine ?? this.parentLine,
      quantityOfferId: quantityOfferId ?? this.quantityOfferId,
      oneTimeDiscountId: oneTimeDiscountId ?? this.oneTimeDiscountId,
      noCreditCard: noCreditCard ?? this.noCreditCard,
    );
  }
}

class SalePayment {
  final String paymentType; // 'Cash', 'Credit Card', 'Credit', 'Due', etc.
  final double amount;

  SalePayment({
    required this.paymentType,
    required this.amount,
  });

  factory SalePayment.fromJson(Map<String, dynamic> json) {
    return SalePayment(
      paymentType: json['payment_type'] as String,
      amount: (json['payment_amount'] as num?)?.toDouble() ??
          (json['amount'] as num?)?.toDouble() ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_type': paymentType,
      'amount': amount,
    };
  }
}

class SaleTax {
  final String name;
  final double percent;
  final int taxType; // 0=exclusive, 1=inclusive
  final double amount;

  SaleTax({
    required this.name,
    required this.percent,
    this.taxType = 0,
    required this.amount,
  });

  factory SaleTax.fromJson(Map<String, dynamic> json) {
    return SaleTax(
      name: json['name'] as String,
      percent: (json['percent'] as num).toDouble(),
      taxType: json['tax_type'] as int? ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ??
          (json['item_tax_amount'] as num?)?.toDouble() ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'percent': percent,
      'tax_type': taxType,
      'amount': amount,
    };
  }
}

class SaleSummary {
  final String date;
  final int salesCount;
  final double totalSales;
  final double totalAmount;
  final double cashAmount;
  final double cardAmount;
  final double creditAmount;

  SaleSummary({
    required this.date,
    required this.salesCount,
    required this.totalSales,
    required this.totalAmount,
    required this.cashAmount,
    required this.cardAmount,
    required this.creditAmount,
  });

  factory SaleSummary.fromJson(Map<String, dynamic> json) {
    return SaleSummary(
      date: json['date'] as String,
      salesCount: json['sales_count'] as int? ?? 0,
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      cashAmount: (json['cash_amount'] as num?)?.toDouble() ?? 0,
      cardAmount: (json['card_amount'] as num?)?.toDouble() ?? 0,
      creditAmount: (json['credit_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SuspendedSale {
  final int saleId;
  final String saleTime;
  final int employeeId;
  final String employeeName;
  final int? customerId;
  final String? customerName;
  final String? comment;
  final int itemCount;
  final double subtotal;
  final double totalDiscount;
  final double total;

  /// Resume claim held by another user. The server only reports a claim while
  /// it is fresh (15 minutes), so a stale one already reads as unlocked here.
  final bool isLocked;
  final int? lockedBy;
  final String? lockedByName;

  SuspendedSale({
    required this.saleId,
    required this.saleTime,
    required this.employeeId,
    required this.employeeName,
    this.customerId,
    this.customerName,
    this.comment,
    required this.itemCount,
    required this.subtotal,
    this.totalDiscount = 0,
    double? total,
    this.isLocked = false,
    this.lockedBy,
    this.lockedByName,
  }) : total = total ?? subtotal;

  factory SuspendedSale.fromJson(Map<String, dynamic> json) {
    final subtotal = (json['subtotal'] as num).toDouble();
    final totalDiscount = (json['total_discount'] as num?)?.toDouble() ?? 0;
    final total = (json['total'] as num?)?.toDouble() ?? (subtotal - totalDiscount);

    return SuspendedSale(
      saleId: json['sale_id'] as int,
      saleTime: json['sale_time'] as String,
      employeeId: json['employee_id'] as int,
      employeeName: json['employee_name'] as String,
      customerId: json['customer_id'] as int?,
      customerName: json['customer_name'] as String?,
      comment: json['comment'] as String?,
      itemCount: json['item_count'] as int,
      subtotal: subtotal,
      totalDiscount: totalDiscount,
      total: total,
      // Older servers omit these entirely, so absent means unlocked.
      isLocked: json['is_locked'] == true || json['is_locked'] == 1,
      lockedBy: (json['locked_by'] as num?)?.toInt(),
      lockedByName: json['locked_by_name'] as String?,
    );
  }
}

class ReturnableItem {
  final int line;
  final int itemId;
  final String name;
  final double quantity;       // original qty sold
  final double alreadyReturned;
  final double remainingQty;   // max returnable
  final double price;
  final double discount;
  final int discountType;
  final double lineTotal;
  final bool quantityOfferFree;
  final String? description;

  /// Which paid line earned this free one, and which lines can trigger it.
  ///
  /// The server computes both specifically so a client can claw the giveaway
  /// back when the line that earned it is returned. The app was discarding
  /// them and hiding free lines instead, so the paid item came back while the
  /// customer kept the free one and its stock never returned.
  ///
  /// [groupTriggerLines] is non-empty for group offers, where ANY member of
  /// the group being returned should take the reward with it.
  final int? parentLine;
  final int? quantityOfferId;
  final List<int> groupTriggerLines;

  /// A free line, including the ones the server did not flag.
  ///
  /// Older rows carry price 0 and a description like
  /// "FREE - Quantity Offer (Bought 100 Get 3 Free)" with quantity_offer_free
  /// false -- sales 81215, 81210 and 80575 are live examples. Without this
  /// they read as ordinary returnable lines offering units at zero refund.
  bool get isFreeLine =>
      quantityOfferFree ||
      (price == 0 && (description ?? '').trimLeft().toUpperCase().startsWith('FREE'));

  /// Whether this free line knows what earned it.
  ///
  /// Only a line with a trigger can be returned automatically. Sale 81215
  /// carries a free line with no parent_line and no group, and guessing which
  /// paid line earned it would be exactly the kind of inference that goes
  /// quietly wrong -- such a line stays selectable by the operator instead, as
  /// it is on the web, so its stock can still come back.
  bool get hasOfferTrigger => parentLine != null || groupTriggerLines.isNotEmpty;

  /// Comes back on its own, so it must not appear in the picker.
  ///
  /// Needs the sale's other lines, because "has a trigger" is not enough: if
  /// the line that earned this one has ALREADY been returned in full, nothing
  /// can ever trigger it again, and hiding it would strand its stock forever.
  /// The web makes the same distinction (views/sales/manage.php:133) --
  /// selectable when the parent is missing OR already at zero remaining.
  bool isAutoReturnedIn(List<ReturnableItem> all) {
    if (!isFreeLine || !hasOfferTrigger) return false;

    final triggers = <int>{
      if (parentLine != null) parentLine!,
      ...groupTriggerLines,
    };

    return all.any((i) => triggers.contains(i.line) && i.remainingQty > 0);
  }

  const ReturnableItem({
    required this.line,
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.alreadyReturned,
    required this.remainingQty,
    required this.price,
    required this.discount,
    required this.discountType,
    required this.lineTotal,
    required this.quantityOfferFree,
    this.description,
    this.parentLine,
    this.quantityOfferId,
    this.groupTriggerLines = const [],
  });

  /// Parse a returnable line.
  ///
  /// Every numeric field goes through a helper rather than a bare cast. The
  /// MySQL driver stringifies INT and DECIMAL, so `line` and `item_id` arrive
  /// as "2" and "513" while `quantity` arrives as a real number in the same
  /// response. The bare `as int` casts this replaced threw on every sale,
  /// which meant the return screen only ever showed
  /// "type 'String' is not a subtype of type 'int'".
  factory ReturnableItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    return ReturnableItem(
      line: asInt(json['line']),
      itemId: asInt(json['item_id']),
      name: json['name']?.toString() ?? '',
      quantity: asDouble(json['quantity']),
      alreadyReturned: asDouble(json['already_returned']),
      remainingQty: asDouble(json['remaining_qty']),
      price: asDouble(json['price']),
      discount: asDouble(json['discount']),
      discountType: asInt(json['discount_type']),
      lineTotal: asDouble(json['line_total']),
      quantityOfferFree: json['quantity_offer_free'] == true,
      description: json['description']?.toString(),
      // Nullable on purpose: an item with no offer has no parent, and 0 is a
      // real line number, so it cannot stand in for "none".
      parentLine: json['parent_line'] == null ? null : asInt(json['parent_line']),
      quantityOfferId:
          json['quantity_offer_id'] == null ? null : asInt(json['quantity_offer_id']),
      groupTriggerLines: ((json['group_trigger_lines'] as List?) ?? const [])
          .map(asInt)
          .toList(),
    );
  }
}

/// One tender on the original sale, and what was taken on it.
///
/// The refund is split across these in proportion, so an operator deciding
/// whether to return a part-credit sale needs to see them.
class ReturnPaymentType {
  const ReturnPaymentType({required this.paymentType, required this.paymentAmount});

  final String paymentType;
  final double paymentAmount;

  factory ReturnPaymentType.fromJson(Map<String, dynamic> json) {
    final raw = json['payment_amount'];
    return ReturnPaymentType(
      paymentType: json['payment_type']?.toString() ?? '',
      paymentAmount: raw is num
          ? raw.toDouble()
          : double.tryParse(raw?.toString() ?? '') ?? 0.0,
    );
  }
}

class ReturnModalData {
  final int saleId;
  final String customerName;
  final bool hasAnyReturn;
  final List<ReturnableItem> items;
  final List<ReturnPaymentType> paymentTypes;

  const ReturnModalData({
    required this.saleId,
    required this.customerName,
    required this.hasAnyReturn,
    required this.items,
    required this.paymentTypes,
  });

  factory ReturnModalData.fromJson(Map<String, dynamic> json) {
    return ReturnModalData(
      // Same driver-stringifies-numbers hazard as ReturnableItem above.
      saleId: json['sale_id'] is int
          ? json['sale_id'] as int
          : int.tryParse(json['sale_id']?.toString() ?? '') ?? 0,
      customerName: json['customer_name']?.toString() ?? '',
      hasAnyReturn: json['has_any_return'] == true,
      items: (json['items'] as List)
          .map((i) => ReturnableItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      // A list of {payment_type, payment_amount} objects, not strings. The
      // old cast<String>() survived only because Dart's cast is lazy and
      // nothing ever read an element; the first read would have thrown.
      paymentTypes: ((json['payment_types'] as List?) ?? const [])
          .whereType<Map>()
          .map((p) => ReturnPaymentType.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
    );
  }
}

class ReturnResult {
  final int returnSaleId;
  final int originalSaleId;
  final double refundTotal;
  final List<Map<String, dynamic>> refundPayments;
  final int itemsReturned;

  const ReturnResult({
    required this.returnSaleId,
    required this.originalSaleId,
    required this.refundTotal,
    required this.refundPayments,
    required this.itemsReturned,
  });

  factory ReturnResult.fromJson(Map<String, dynamic> json) {
    return ReturnResult(
      returnSaleId: json['return_sale_id'] as int,
      originalSaleId: json['original_sale_id'] as int,
      refundTotal: (json['refund_total'] as num).toDouble(),
      refundPayments: (json['refund_payments'] as List)
          .cast<Map<String, dynamic>>(),
      itemsReturned: json['items_returned'] as int,
    );
  }
}