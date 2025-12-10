// Stock Tracking models for inventory management

/// Single item in stock tracking report
class StockTrackingItem {
  final int itemId;
  final String name;
  final double opening;
  final double purchased;
  final double total;
  final double sold;
  final double closing;
  final double actual;
  final bool isBalanced;
  final double unitPrice;
  final double costPrice;
  final double stockValue;
  final double sales;
  final double discount;
  final double netSales;

  StockTrackingItem({
    required this.itemId,
    required this.name,
    required this.opening,
    required this.purchased,
    required this.total,
    required this.sold,
    required this.closing,
    required this.actual,
    required this.isBalanced,
    required this.unitPrice,
    required this.costPrice,
    required this.stockValue,
    required this.sales,
    required this.discount,
    required this.netSales,
  });

  factory StockTrackingItem.fromJson(Map<String, dynamic> json) {
    return StockTrackingItem(
      itemId: json['item_id'] ?? 0,
      name: json['name'] ?? '',
      opening: _parseDouble(json['opening']),
      purchased: _parseDouble(json['purchased']),
      total: _parseDouble(json['total']),
      sold: _parseDouble(json['sold']),
      closing: _parseDouble(json['closing']),
      actual: _parseDouble(json['actual']),
      isBalanced: json['is_balanced'] == true,
      unitPrice: _parseDouble(json['unit_price']),
      costPrice: _parseDouble(json['cost_price']),
      stockValue: _parseDouble(json['stock_value']),
      sales: _parseDouble(json['sales']),
      discount: _parseDouble(json['discount']),
      netSales: _parseDouble(json['net_sales']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Stock tracking totals
class StockTrackingTotals {
  final double stockValue;
  final double totalSales;
  final double totalDiscount;
  final double totalNetSales;

  StockTrackingTotals({
    required this.stockValue,
    required this.totalSales,
    required this.totalDiscount,
    required this.totalNetSales,
  });

  factory StockTrackingTotals.fromJson(Map<String, dynamic> json) {
    return StockTrackingTotals(
      stockValue: _parseDouble(json['stock_value']),
      totalSales: _parseDouble(json['total_sales']),
      totalDiscount: _parseDouble(json['total_discount']),
      totalNetSales: _parseDouble(json['total_net_sales']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Cash flow summary
class CashFlowSummary {
  final double netSales;
  final double customerCredit;
  final double cashSales;
  final double customerPayments;
  final double totalCash;
  final double expenses;
  final double cashAfterExpenses;
  final double bankDeposits;
  final double netCash;

  CashFlowSummary({
    required this.netSales,
    required this.customerCredit,
    required this.cashSales,
    required this.customerPayments,
    required this.totalCash,
    required this.expenses,
    required this.cashAfterExpenses,
    required this.bankDeposits,
    required this.netCash,
  });

  factory CashFlowSummary.fromJson(Map<String, dynamic> json) {
    return CashFlowSummary(
      netSales: _parseDouble(json['net_sales']),
      customerCredit: _parseDouble(json['customer_credit']),
      cashSales: _parseDouble(json['cash_sales']),
      customerPayments: _parseDouble(json['customer_payments']),
      totalCash: _parseDouble(json['total_cash']),
      expenses: _parseDouble(json['expenses']),
      cashAfterExpenses: _parseDouble(json['cash_after_expenses']),
      bankDeposits: _parseDouble(json['bank_deposits']),
      netCash: _parseDouble(json['net_cash']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Customer credit entry
class CustomerCreditEntry {
  final int saleId;
  final String customerName;
  final String items;
  final double amount;

  CustomerCreditEntry({
    required this.saleId,
    required this.customerName,
    required this.items,
    required this.amount,
  });

  factory CustomerCreditEntry.fromJson(Map<String, dynamic> json) {
    return CustomerCreditEntry(
      saleId: json['sale_id'] ?? 0,
      customerName: json['customer_name'] ?? '',
      items: json['items'] ?? '',
      amount: _parseDouble(json['amount']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Customer payment entry
class CustomerPaymentEntry {
  final String customerName;
  final double amount;

  CustomerPaymentEntry({
    required this.customerName,
    required this.amount,
  });

  factory CustomerPaymentEntry.fromJson(Map<String, dynamic> json) {
    return CustomerPaymentEntry(
      customerName: json['customer_name'] ?? '',
      amount: _parseDouble(json['amount']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Supplier bank payment entry
class SupplierBankPaymentEntry {
  final String supplierName;
  final double amount;

  SupplierBankPaymentEntry({
    required this.supplierName,
    required this.amount,
  });

  factory SupplierBankPaymentEntry.fromJson(Map<String, dynamic> json) {
    return SupplierBankPaymentEntry(
      supplierName: json['supplier_name'] ?? '',
      amount: _parseDouble(json['amount']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Complete stock tracking report
class StockTrackingReport {
  final String date;
  final int stockLocationId;
  final List<StockTrackingItem> items;
  final StockTrackingTotals totals;
  final CashFlowSummary cashFlow;
  final double customerCreditsTotal;
  final List<CustomerCreditEntry> customerCreditsList;
  final double customerPaymentsTotal;
  final List<CustomerPaymentEntry> customerPaymentsList;
  final double supplierBankPaymentsTotal;
  final List<SupplierBankPaymentEntry> supplierBankPaymentsList;

  StockTrackingReport({
    required this.date,
    required this.stockLocationId,
    required this.items,
    required this.totals,
    required this.cashFlow,
    required this.customerCreditsTotal,
    required this.customerCreditsList,
    required this.customerPaymentsTotal,
    required this.customerPaymentsList,
    required this.supplierBankPaymentsTotal,
    required this.supplierBankPaymentsList,
  });

  factory StockTrackingReport.fromJson(Map<String, dynamic> json) {
    // Parse items
    final itemsList = (json['items'] as List? ?? [])
        .map((item) => StockTrackingItem.fromJson(item))
        .toList();

    // Parse customer credits
    final customerCredits = json['customer_credits'] as Map<String, dynamic>? ?? {};
    final customerCreditsList = (customerCredits['list'] as List? ?? [])
        .map((item) => CustomerCreditEntry.fromJson(item))
        .toList();

    // Parse customer payments
    final customerPayments = json['customer_payments'] as Map<String, dynamic>? ?? {};
    final customerPaymentsList = (customerPayments['list'] as List? ?? [])
        .map((item) => CustomerPaymentEntry.fromJson(item))
        .toList();

    // Parse supplier bank payments
    final supplierBankPayments = json['supplier_bank_payments'] as Map<String, dynamic>? ?? {};
    final supplierBankPaymentsList = (supplierBankPayments['list'] as List? ?? [])
        .map((item) => SupplierBankPaymentEntry.fromJson(item))
        .toList();

    return StockTrackingReport(
      date: json['date'] ?? '',
      stockLocationId: json['stock_location_id'] ?? 0,
      items: itemsList,
      totals: StockTrackingTotals.fromJson(json['totals'] ?? {}),
      cashFlow: CashFlowSummary.fromJson(json['cash_flow'] ?? {}),
      customerCreditsTotal: _parseDouble(customerCredits['total']),
      customerCreditsList: customerCreditsList,
      customerPaymentsTotal: _parseDouble(customerPayments['total']),
      customerPaymentsList: customerPaymentsList,
      supplierBankPaymentsTotal: _parseDouble(supplierBankPayments['total']),
      supplierBankPaymentsList: supplierBankPaymentsList,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

// ============================================
// Advanced Item Tracking Models
// ============================================

/// Item details for tracking
class ItemTrackingDetails {
  final int id;
  final String name;
  final String? itemNumber;
  final String? category;
  final double costPrice;
  final double unitPrice;

  ItemTrackingDetails({
    required this.id,
    required this.name,
    this.itemNumber,
    this.category,
    required this.costPrice,
    required this.unitPrice,
  });

  factory ItemTrackingDetails.fromJson(Map<String, dynamic> json) {
    return ItemTrackingDetails(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      itemNumber: json['item_number'],
      category: json['category'],
      costPrice: _parseDouble(json['cost_price']),
      unitPrice: _parseDouble(json['unit_price']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Item balances
class ItemTrackingBalances {
  final double opening;
  final double closing;
  final double available;

  ItemTrackingBalances({
    required this.opening,
    required this.closing,
    required this.available,
  });

  factory ItemTrackingBalances.fromJson(Map<String, dynamic> json) {
    return ItemTrackingBalances(
      opening: _parseDouble(json['opening']),
      closing: _parseDouble(json['closing']),
      available: _parseDouble(json['available']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Single transaction for item tracking
class ItemTransaction {
  final String date;
  final String employee;
  final double inQuantity;
  final double outQuantity;
  final double balance;
  final String event;
  final String customerSupplier;

  ItemTransaction({
    required this.date,
    required this.employee,
    required this.inQuantity,
    required this.outQuantity,
    required this.balance,
    required this.event,
    required this.customerSupplier,
  });

  factory ItemTransaction.fromJson(Map<String, dynamic> json) {
    return ItemTransaction(
      date: json['date'] ?? '',
      employee: json['employee'] ?? '',
      inQuantity: _parseDouble(json['in_quantity']),
      outQuantity: _parseDouble(json['out_quantity']),
      balance: _parseDouble(json['balance']),
      event: json['event'] ?? '',
      customerSupplier: json['customer_supplier'] ?? '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Returns true if this is an incoming (receiving) transaction
  bool get isIncoming => inQuantity > 0;

  /// Returns true if this is an outgoing (sale) transaction
  bool get isOutgoing => outQuantity > 0;
}

/// Complete item tracking report
class ItemTrackingReport {
  final ItemTrackingDetails item;
  final String startDate;
  final String endDate;
  final int stockLocationId;
  final ItemTrackingBalances balances;
  final List<ItemTransaction> transactions;

  ItemTrackingReport({
    required this.item,
    required this.startDate,
    required this.endDate,
    required this.stockLocationId,
    required this.balances,
    required this.transactions,
  });

  factory ItemTrackingReport.fromJson(Map<String, dynamic> json) {
    final filters = json['filters'] as Map<String, dynamic>? ?? {};
    final transactionsList = (json['transactions'] as List? ?? [])
        .map((item) => ItemTransaction.fromJson(item))
        .toList();

    return ItemTrackingReport(
      item: ItemTrackingDetails.fromJson(json['item'] ?? {}),
      startDate: filters['start_date'] ?? '',
      endDate: filters['end_date'] ?? '',
      stockLocationId: filters['stock_location_id'] ?? 0,
      balances: ItemTrackingBalances.fromJson(json['balances'] ?? {}),
      transactions: transactionsList,
    );
  }
}

/// Simple item for dropdown selection
class SimpleItem {
  final int itemId;
  final String name;
  final String? itemNumber;
  final String? category;

  SimpleItem({
    required this.itemId,
    required this.name,
    this.itemNumber,
    this.category,
  });

  factory SimpleItem.fromJson(Map<String, dynamic> json) {
    return SimpleItem(
      itemId: json['item_id'] ?? 0,
      name: json['name'] ?? '',
      itemNumber: json['item_number'],
      category: json['category'],
    );
  }

  String get displayName {
    if (itemNumber != null && itemNumber!.isNotEmpty) {
      return '$name ($itemNumber)';
    }
    return name;
  }
}
