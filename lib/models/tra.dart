// TRA (TRADE) models for Tanzania Revenue Authority tax reporting

/// EFD Device model
class EFDDevice {
  final int id;
  final String name;

  EFDDevice({
    required this.id,
    required this.name,
  });

  factory EFDDevice.fromJson(Map<String, dynamic> json) {
    return EFDDevice(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      name: json['name']?.toString() ?? '',
    );
  }
}

/// TRA Dashboard Summary model
class TRADashboard {
  // Sales - Leruma
  final double salesLeruma;
  final double turnoverLeruma;
  final double taxesLeruma;
  final double exemptSalesLeruma;

  // Sales - Financial
  final double salesFinancial;
  final double turnoverFinancial;
  final double taxesFinancial;
  final double exemptSalesFinancial;

  // Purchases
  final double purchasesLeruma;
  final double purchasesTurnover;
  final double purchasesTaxes;
  final double purchasesExempt;
  final double totalPurchases;

  // Expenses
  final double expensesLeruma;
  final double expensesTurnover;
  final double expensesTaxes;
  final double expensesExempt;
  final double totalExpenses;

  // Filter info
  final String fromDate;
  final String toDate;
  final int? efdId;

  TRADashboard({
    required this.salesLeruma,
    required this.turnoverLeruma,
    required this.taxesLeruma,
    required this.exemptSalesLeruma,
    required this.salesFinancial,
    required this.turnoverFinancial,
    required this.taxesFinancial,
    required this.exemptSalesFinancial,
    required this.purchasesLeruma,
    required this.purchasesTurnover,
    required this.purchasesTaxes,
    required this.purchasesExempt,
    required this.totalPurchases,
    required this.expensesLeruma,
    required this.expensesTurnover,
    required this.expensesTaxes,
    required this.expensesExempt,
    required this.totalExpenses,
    required this.fromDate,
    required this.toDate,
    this.efdId,
  });

  factory TRADashboard.fromJson(Map<String, dynamic> json) {
    return TRADashboard(
      salesLeruma: _parseDouble(json['sales_leruma']),
      turnoverLeruma: _parseDouble(json['turnover_leruma']),
      taxesLeruma: _parseDouble(json['taxes_leruma']),
      exemptSalesLeruma: _parseDouble(json['exempt_sales_leruma']),
      salesFinancial: _parseDouble(json['sales_financial']),
      turnoverFinancial: _parseDouble(json['turnover_financial']),
      taxesFinancial: _parseDouble(json['taxes_financial']),
      exemptSalesFinancial: _parseDouble(json['exempt_sales_financial']),
      purchasesLeruma: _parseDouble(json['purchases_leruma']),
      purchasesTurnover: _parseDouble(json['purchases_turnover']),
      purchasesTaxes: _parseDouble(json['purchases_taxes']),
      purchasesExempt: _parseDouble(json['purchases_exempt']),
      totalPurchases: _parseDouble(json['total_purchases']),
      expensesLeruma: _parseDouble(json['expenses_leruma']),
      expensesTurnover: _parseDouble(json['expenses_turnover']),
      expensesTaxes: _parseDouble(json['expenses_taxes']),
      expensesExempt: _parseDouble(json['expenses_exempt']),
      totalExpenses: _parseDouble(json['total_expenses']),
      fromDate: json['from_date']?.toString() ?? '',
      toDate: json['to_date']?.toString() ?? '',
      efdId: json['efd_id'] != null
          ? (json['efd_id'] is String
              ? int.tryParse(json['efd_id'])
              : json['efd_id'] as int?)
          : null,
    );
  }
}

/// TRA Sale (Z-Report) model
class TRASale {
  final int id;
  final int efdId;
  final String efdName;
  final int efdNumber; // Z-Report number
  final int? lastZNumber;
  final String date;
  final double turnOver;
  final double amount; // Net amount
  final double tax;
  final double vat;
  final String? fileName;
  final String? createdAt;
  final int? createdBy;

  TRASale({
    required this.id,
    required this.efdId,
    required this.efdName,
    required this.efdNumber,
    this.lastZNumber,
    required this.date,
    required this.turnOver,
    required this.amount,
    required this.tax,
    required this.vat,
    this.fileName,
    this.createdAt,
    this.createdBy,
  });

  factory TRASale.fromJson(Map<String, dynamic> json) {
    return TRASale(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      efdId: json['efd_id'] is String
          ? int.parse(json['efd_id'])
          : json['efd_id'] as int,
      efdName: json['efd_name']?.toString() ?? '',
      efdNumber: json['efd_number'] is String
          ? int.parse(json['efd_number'])
          : json['efd_number'] as int,
      lastZNumber: json['last_z_number'] != null
          ? (json['last_z_number'] is String
              ? int.tryParse(json['last_z_number'])
              : json['last_z_number'] as int?)
          : null,
      date: json['date']?.toString() ?? '',
      turnOver: _parseDouble(json['turn_over']),
      amount: _parseDouble(json['amount']),
      tax: _parseDouble(json['tax']),
      vat: _parseDouble(json['vat']),
      fileName: json['file_name']?.toString(),
      createdAt: json['created_at']?.toString(),
      createdBy: json['created_by'] != null
          ? (json['created_by'] is String
              ? int.tryParse(json['created_by'])
              : json['created_by'] as int?)
          : null,
    );
  }
}

/// TRA Sale create/update model
class TRASaleCreate {
  final int efdId;
  final int? lastZNumber;
  final int currentZNumber;
  final double turnover;
  final double netAmount;
  final double tax;
  final double? turnoverExSr;
  final String? saleDate;
  final String? file; // Base64 encoded file

  TRASaleCreate({
    required this.efdId,
    this.lastZNumber,
    required this.currentZNumber,
    required this.turnover,
    required this.netAmount,
    required this.tax,
    this.turnoverExSr,
    this.saleDate,
    this.file,
  });

  Map<String, dynamic> toJson() {
    return {
      'efd_id': efdId,
      if (lastZNumber != null) 'last_z_number': lastZNumber,
      'current_z_number': currentZNumber,
      'turnover': turnover,
      'net_amount': netAmount,
      'tax': tax,
      if (turnoverExSr != null) 'turnover_ex_sr': turnoverExSr,
      if (saleDate != null) 'sale_date': saleDate,
      if (file != null) 'file': file,
    };
  }
}

/// TRA Sales Summary model
class TRASalesSummary {
  final double totalSales;
  final double totalTurnover;
  final double totalTaxes;
  final double totalExempt;

  TRASalesSummary({
    required this.totalSales,
    required this.totalTurnover,
    required this.totalTaxes,
    required this.totalExempt,
  });

  factory TRASalesSummary.fromJson(Map<String, dynamic> json) {
    return TRASalesSummary(
      totalSales: _parseDouble(json['total_sales']),
      totalTurnover: _parseDouble(json['total_turnover']),
      totalTaxes: _parseDouble(json['total_taxes']),
      totalExempt: _parseDouble(json['total_exempt']),
    );
  }
}

/// TRA Purchase model
class TRAPurchase {
  final int id;
  final int efdId;
  final int supplierId;
  final String supplierName;
  final int itemId;
  final String itemName;
  final String purchaseType;
  final double amountVatExc;
  final double vatAmount;
  final double totalAmount;
  final String taxInvoice;
  final String? invoiceDate;
  final String date;
  final String isExpense;
  final String? file;
  final String? createdAt;

  TRAPurchase({
    required this.id,
    required this.efdId,
    required this.supplierId,
    required this.supplierName,
    required this.itemId,
    required this.itemName,
    required this.purchaseType,
    required this.amountVatExc,
    required this.vatAmount,
    required this.totalAmount,
    required this.taxInvoice,
    this.invoiceDate,
    required this.date,
    required this.isExpense,
    this.file,
    this.createdAt,
  });

  factory TRAPurchase.fromJson(Map<String, dynamic> json) {
    return TRAPurchase(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      efdId: json['efd_id'] is String
          ? int.parse(json['efd_id'])
          : json['efd_id'] as int,
      supplierId: json['supplier_id'] is String
          ? int.parse(json['supplier_id'])
          : json['supplier_id'] as int,
      supplierName: json['supplier_name']?.toString() ?? '',
      itemId: json['item_id'] is String
          ? int.parse(json['item_id'])
          : json['item_id'] as int,
      itemName: json['item_name']?.toString() ?? '',
      purchaseType: json['purchase_type']?.toString() ?? '',
      amountVatExc: _parseDouble(json['amount_vat_exc']),
      vatAmount: _parseDouble(json['vat_amount']),
      totalAmount: _parseDouble(json['total_amount']),
      taxInvoice: json['tax_invoice']?.toString() ?? '',
      invoiceDate: json['invoice_date']?.toString(),
      date: json['date']?.toString() ?? '',
      isExpense: json['is_expense']?.toString() ?? 'NO',
      file: json['file']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

/// TRA Purchase create/update model
class TRAPurchaseCreate {
  final int efdId;
  final int supplierId;
  final int itemId;
  final String purchaseType;
  final double amountVatExc;
  final double vatAmount;
  final double totalAmount;
  final String taxInvoice;
  final String? invoiceDate;
  final String? date;
  final String isExpense;
  final String? file; // Base64 encoded file

  TRAPurchaseCreate({
    required this.efdId,
    required this.supplierId,
    required this.itemId,
    required this.purchaseType,
    required this.amountVatExc,
    required this.vatAmount,
    required this.totalAmount,
    required this.taxInvoice,
    this.invoiceDate,
    this.date,
    this.isExpense = 'NO',
    this.file,
  });

  Map<String, dynamic> toJson() {
    return {
      'efd_id': efdId,
      'supplier_id': supplierId,
      'item_id': itemId,
      'purchase_type': purchaseType,
      'amount_vat_exc': amountVatExc,
      'vat_amount': vatAmount,
      'total_amount': totalAmount,
      'tax_invoice': taxInvoice,
      if (invoiceDate != null) 'invoice_date': invoiceDate,
      if (date != null) 'date': date,
      'is_expense': isExpense,
      if (file != null) 'file': file,
    };
  }
}

/// TRA Purchases Summary model
class TRAPurchasesSummary {
  final double totalPurchases;
  final double totalTurnover;
  final double totalTaxes;
  final double totalExempt;

  TRAPurchasesSummary({
    required this.totalPurchases,
    required this.totalTurnover,
    required this.totalTaxes,
    required this.totalExempt,
  });

  factory TRAPurchasesSummary.fromJson(Map<String, dynamic> json) {
    return TRAPurchasesSummary(
      totalPurchases: _parseDouble(json['total_purchases'] ?? json['total_expenses']),
      totalTurnover: _parseDouble(json['total_turnover']),
      totalTaxes: _parseDouble(json['total_taxes']),
      totalExempt: _parseDouble(json['total_exempt']),
    );
  }
}

/// TRA Supplier model (for dropdown)
class TRASupplier {
  final int id;
  final String name;
  final String? email;
  final String? phone;

  TRASupplier({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });

  factory TRASupplier.fromJson(Map<String, dynamic> json) {
    return TRASupplier(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}

/// TRA Item model (for dropdown)
class TRAItem {
  final int id;
  final String name;
  final String? category;

  TRAItem({
    required this.id,
    required this.name,
    this.category,
  });

  factory TRAItem.fromJson(Map<String, dynamic> json) {
    return TRAItem(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString(),
    );
  }
}

/// Purchase types
class TRAPurchaseTypes {
  static const List<String> types = [
    'Standard Rate',
    'Zero Rate',
    'Exempt',
    'Special Relief',
  ];
}

// Helper function to parse double values safely
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}
