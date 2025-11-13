class CreditTransaction {
  final int? id;
  final String date;
  final double credit;
  final double debit;
  final int? saleId;
  final String? description;
  final double balance;

  CreditTransaction({
    this.id,
    required this.date,
    required this.credit,
    required this.debit,
    this.saleId,
    this.description,
    required this.balance,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    // Handle sale_id which can be a string or int from API
    int? parsedSaleId;
    if (json['sale_id'] != null) {
      if (json['sale_id'] is int) {
        parsedSaleId = json['sale_id'];
      } else if (json['sale_id'] is String) {
        parsedSaleId = int.tryParse(json['sale_id']);
      }
    }

    return CreditTransaction(
      id: json['id'],
      date: json['date'] ?? '',
      credit: (json['credit'] ?? 0).toDouble(),
      debit: (json['debit'] ?? 0).toDouble(),
      saleId: parsedSaleId,
      description: json['description'],
      balance: (json['balance'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'credit': credit,
      'debit': debit,
      'sale_id': saleId,
      'description': description,
      'balance': balance,
    };
  }
}

class CreditStatement {
  final int customerId;
  final String customerName;
  final String startDate;
  final String endDate;
  final double openingBalance;
  final double closingBalance;
  final double currentBalance;
  final List<CreditTransaction> transactions;

  CreditStatement({
    required this.customerId,
    required this.customerName,
    required this.startDate,
    required this.endDate,
    required this.openingBalance,
    required this.closingBalance,
    required this.currentBalance,
    required this.transactions,
  });

  factory CreditStatement.fromJson(Map<String, dynamic> json) {
    var transactionsJson = json['transactions'] as List? ?? [];
    List<CreditTransaction> transactionsList = transactionsJson
        .map((t) => CreditTransaction.fromJson(t))
        .toList();

    return CreditStatement(
      customerId: json['customer_id'] ?? 0,
      customerName: json['customer_name'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      openingBalance: (json['opening_balance'] ?? 0).toDouble(),
      closingBalance: (json['closing_balance'] ?? 0).toDouble(),
      currentBalance: (json['current_balance'] ?? 0).toDouble(),
      transactions: transactionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'customer_name': customerName,
      'start_date': startDate,
      'end_date': endDate,
      'opening_balance': openingBalance,
      'closing_balance': closingBalance,
      'current_balance': currentBalance,
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
  }
}

class CreditBalance {
  final int customerId;
  final String customerName;
  final double balance;
  final double deposit;
  final double netBalance;

  CreditBalance({
    required this.customerId,
    required this.customerName,
    required this.balance,
    required this.deposit,
    required this.netBalance,
  });

  factory CreditBalance.fromJson(Map<String, dynamic> json) {
    return CreditBalance(
      customerId: json['customer_id'] ?? 0,
      customerName: json['customer_name'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      deposit: (json['deposit'] ?? 0).toDouble(),
      netBalance: (json['net_balance'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'customer_name': customerName,
      'balance': balance,
      'deposit': deposit,
      'net_balance': netBalance,
    };
  }
}

class PaymentFormData {
  final int customerId;
  final double amount;
  final int? saleId;
  final int? paymentId;
  final int? stockLocationId;
  final int? paymentMode;
  final int? paidPaymentType;
  final double? balance;
  final String? description;
  final String? date;

  PaymentFormData({
    required this.customerId,
    required this.amount,
    this.saleId,
    this.paymentId,
    this.stockLocationId,
    this.paymentMode,
    this.paidPaymentType,
    this.balance,
    this.description,
    this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'amount': amount,
      'sale_id': saleId,
      'payment_id': paymentId,
      'stock_location_id': stockLocationId,
      'payment_mode': paymentMode,
      'paid_payment_type': paidPaymentType,
      'balance': balance,
      'description': description,
      'date': date,
    };
  }
}

class SaleItem {
  final int itemId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double total;

  SaleItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.total,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      itemId: json['item_id'] ?? 0,
      itemName: json['item_name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

class SaleDetails {
  final int saleId;
  final String saleDate;
  final int customerId;
  final List<SaleItem> items;
  final double subtotal;
  final double total;

  SaleDetails({
    required this.saleId,
    required this.saleDate,
    required this.customerId,
    required this.items,
    required this.subtotal,
    required this.total,
  });

  factory SaleDetails.fromJson(Map<String, dynamic> json) {
    var itemsJson = json['items'] as List? ?? [];
    List<SaleItem> itemsList = itemsJson
        .map((i) => SaleItem.fromJson(i))
        .toList();

    return SaleDetails(
      saleId: json['sale_id'] ?? 0,
      saleDate: json['sale_date'] ?? '',
      customerId: json['customer_id'] ?? 0,
      items: itemsList,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}
