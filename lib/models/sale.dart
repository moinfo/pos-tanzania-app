class Sale {
  final int? saleId;
  final String saleTime;
  final int? customerId;
  final String? customerName;
  final int employeeId;
  final String? employeeName;
  final String? comment;
  final String? invoiceNumber;
  final int saleStatus; // 0=completed, 2=suspended
  final int saleType; // 0=POS, 1=Invoice, 2=Return
  final double subtotal;
  final double taxTotal;
  final double total;
  final String? paymentType;
  final List<SaleItem>? items;
  final List<SalePayment>? payments;
  final bool? hasOfferItems; // True if sale has quantity offer free items

  Sale({
    this.saleId,
    required this.saleTime,
    this.customerId,
    this.customerName,
    required this.employeeId,
    this.employeeName,
    this.comment,
    this.invoiceNumber,
    this.saleStatus = 0,
    this.saleType = 0,
    this.subtotal = 0,
    this.taxTotal = 0,
    this.total = 0,
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
      employeeId: json['employee_id'] as int,
      employeeName: json['employee_name'] as String?,
      comment: json['comment'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      saleStatus: json['sale_status'] as int? ?? 0,
      saleType: json['sale_type'] as int? ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      taxTotal: (json['tax_total'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? (json['total_amount'] as num?)?.toDouble() ?? 0,
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
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      discountType: json['discount_type'] as int? ?? 0,
      discountLimit: json['discount_limit'] as int? ?? 0,
      description: json['description'] as String?,
      serialNumber: json['serial_number'] as String?,
      stockLocationId: json['stock_location_id'] as int?,
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      lineTotal: (json['line_total'] as num?)?.toDouble(),
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
    );
  }
}