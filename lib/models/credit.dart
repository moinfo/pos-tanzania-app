class CreditTransaction {
  final int? id;
  final String date;
  final double credit;
  final double debit;
  final int? saleId;
  final String? description;
  final double balance;
  final int? stockLocationId;

  CreditTransaction({
    this.id,
    required this.date,
    required this.credit,
    required this.debit,
    this.saleId,
    this.description,
    required this.balance,
    this.stockLocationId,
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
      stockLocationId: json['stock_location_id'],
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
      'stock_location_id': stockLocationId,
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
    final map = <String, dynamic>{
      'customer_id': customerId,
      'amount': amount,
    };

    // Only include optional fields if they have values
    if (saleId != null) map['sale_id'] = saleId;
    if (paymentId != null) map['payment_id'] = paymentId;
    if (stockLocationId != null) map['stock_location_id'] = stockLocationId;
    if (paymentMode != null) map['payment_mode'] = paymentMode;
    if (paidPaymentType != null) map['paid_payment_type'] = paidPaymentType;
    if (balance != null) map['balance'] = balance;
    if (description != null && description!.isNotEmpty) map['description'] = description;
    if (date != null) map['date'] = date;

    return map;
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

/// Supervisor credit data for the credits list screen
class SupervisorCredit {
  final int supervisorId;
  final String name;
  final String phone;
  final double credit;
  final double debit;
  final double balance;

  SupervisorCredit({
    required this.supervisorId,
    required this.name,
    required this.phone,
    required this.credit,
    required this.debit,
    required this.balance,
  });

  factory SupervisorCredit.fromJson(Map<String, dynamic> json) {
    return SupervisorCredit(
      supervisorId: json['supervisor_id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      credit: (json['credit'] ?? 0).toDouble(),
      debit: (json['debit'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
    );
  }
}

/// Summary for supervisor credits
class CreditsSummary {
  final double totalCredit;
  final double totalDebit;
  final double totalBalance;
  final int supervisorCount;

  CreditsSummary({
    required this.totalCredit,
    required this.totalDebit,
    required this.totalBalance,
    required this.supervisorCount,
  });

  factory CreditsSummary.fromJson(Map<String, dynamic> json) {
    return CreditsSummary(
      totalCredit: (json['total_credit'] ?? 0).toDouble(),
      totalDebit: (json['total_debit'] ?? 0).toDouble(),
      totalBalance: (json['total_balance'] ?? 0).toDouble(),
      supervisorCount: json['supervisor_count'] ?? 0,
    );
  }
}

/// Response from GET /api/credits/supervisors
class SupervisorCreditsResponse {
  final List<SupervisorCredit> supervisors;
  final CreditsSummary summary;

  SupervisorCreditsResponse({
    required this.supervisors,
    required this.summary,
  });

  factory SupervisorCreditsResponse.fromJson(Map<String, dynamic> json) {
    var supervisorsJson = json['supervisors'] as List? ?? [];
    List<SupervisorCredit> supervisorsList = supervisorsJson
        .map((s) => SupervisorCredit.fromJson(s))
        .toList();

    return SupervisorCreditsResponse(
      supervisors: supervisorsList,
      summary: CreditsSummary.fromJson(json['summary'] ?? {}),
    );
  }
}

/// Customer credit data for supervisor's customer list
class CustomerCredit {
  final int customerId;
  final String firstName;
  final String lastName;
  final String phone;
  final double credit;
  final double debit;
  final double balance;

  CustomerCredit({
    required this.customerId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.credit,
    required this.debit,
    required this.balance,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory CustomerCredit.fromJson(Map<String, dynamic> json) {
    return CustomerCredit(
      customerId: json['customer_id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phone: json['phone'] ?? '',
      credit: (json['credit'] ?? 0).toDouble(),
      debit: (json['debit'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
    );
  }
}

/// Customer summary for supervisor
class CustomerCreditsSummary {
  final double totalCredit;
  final double totalDebit;
  final double totalBalance;
  final int customerCount;

  CustomerCreditsSummary({
    required this.totalCredit,
    required this.totalDebit,
    required this.totalBalance,
    required this.customerCount,
  });

  factory CustomerCreditsSummary.fromJson(Map<String, dynamic> json) {
    return CustomerCreditsSummary(
      totalCredit: (json['total_credit'] ?? 0).toDouble(),
      totalDebit: (json['total_debit'] ?? 0).toDouble(),
      totalBalance: (json['total_balance'] ?? 0).toDouble(),
      customerCount: json['customer_count'] ?? 0,
    );
  }
}

/// Response from GET /api/credits/supervisor/:id/customers
class SupervisorCustomersResponse {
  final int supervisorId;
  final String supervisorName;
  final List<CustomerCredit> customers;
  final CustomerCreditsSummary summary;

  SupervisorCustomersResponse({
    required this.supervisorId,
    required this.supervisorName,
    required this.customers,
    required this.summary,
  });

  factory SupervisorCustomersResponse.fromJson(Map<String, dynamic> json) {
    var customersJson = json['customers'] as List? ?? [];
    List<CustomerCredit> customersList = customersJson
        .map((c) => CustomerCredit.fromJson(c))
        .toList();

    return SupervisorCustomersResponse(
      supervisorId: json['supervisor_id'] ?? 0,
      supervisorName: json['supervisor_name'] ?? '',
      customers: customersList,
      summary: CustomerCreditsSummary.fromJson(json['summary'] ?? {}),
    );
  }
}

/// Daily debt collection entry
class DailyDebtEntry {
  final int id;
  final String date;
  final String customerName;
  final int customerId;
  final double amount;
  final String supervisorName;
  final int supervisorId;
  final String locationName;
  final String employeeName;
  final int employeeId;
  final String description;
  final int paymentId;

  DailyDebtEntry({
    required this.id,
    required this.date,
    required this.customerName,
    required this.customerId,
    required this.amount,
    required this.supervisorName,
    required this.supervisorId,
    required this.locationName,
    required this.employeeName,
    required this.employeeId,
    required this.description,
    required this.paymentId,
  });

  factory DailyDebtEntry.fromJson(Map<String, dynamic> json) {
    return DailyDebtEntry(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerId: json['customer_id'] ?? 0,
      amount: (json['amount'] ?? 0).toDouble(),
      supervisorName: json['supervisor_name'] ?? '',
      supervisorId: json['supervisor_id'] ?? 0,
      locationName: json['location_name'] ?? '',
      employeeName: json['employee_name'] ?? '',
      employeeId: json['employee_id'] ?? 0,
      description: json['description'] ?? '',
      paymentId: json['payment_id'] ?? 0,
    );
  }
}

/// Summary for daily debt report
class DailyDebtSummary {
  final double totalAmount;
  final int count;

  DailyDebtSummary({
    required this.totalAmount,
    required this.count,
  });

  factory DailyDebtSummary.fromJson(Map<String, dynamic> json) {
    return DailyDebtSummary(
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      count: json['count'] ?? 0,
    );
  }
}

/// Response from GET /api/credits/daily_debt_report
class DailyDebtReportResponse {
  final String startDate;
  final String endDate;
  final List<DailyDebtEntry> debts;
  final DailyDebtSummary summary;

  DailyDebtReportResponse({
    required this.startDate,
    required this.endDate,
    required this.debts,
    required this.summary,
  });

  factory DailyDebtReportResponse.fromJson(Map<String, dynamic> json) {
    var debtsJson = json['debts'] as List? ?? [];
    List<DailyDebtEntry> debtsList = debtsJson
        .map((d) => DailyDebtEntry.fromJson(d))
        .toList();

    return DailyDebtReportResponse(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      debts: debtsList,
      summary: DailyDebtSummary.fromJson(json['summary'] ?? {}),
    );
  }
}
