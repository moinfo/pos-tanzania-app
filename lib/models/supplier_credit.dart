/// Supplier credit data for the suppliers creditors list screen
class SupplierCredit {
  final int supplierId;
  final String firstName;
  final String lastName;
  final String companyName;
  final String phone;
  final double credit;
  final double debit;
  final double balance;

  SupplierCredit({
    required this.supplierId,
    required this.firstName,
    required this.lastName,
    required this.companyName,
    required this.phone,
    required this.credit,
    required this.debit,
    required this.balance,
  });

  String get displayName {
    final fullName = '$firstName $lastName'.trim();
    if (companyName.isNotEmpty) {
      return fullName.isNotEmpty ? '$fullName - $companyName' : companyName;
    }
    return fullName;
  }

  factory SupplierCredit.fromJson(Map<String, dynamic> json) {
    return SupplierCredit(
      supplierId: json['supplier_id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      companyName: json['company_name'] ?? '',
      phone: json['phone'] ?? '',
      credit: (json['credit'] ?? 0).toDouble(),
      debit: (json['debit'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
    );
  }
}

/// Summary for supplier credits
class SupplierCreditsSummary {
  final double totalCredit;
  final double totalDebit;
  final double totalBalance;
  final int supplierCount;

  SupplierCreditsSummary({
    required this.totalCredit,
    required this.totalDebit,
    required this.totalBalance,
    required this.supplierCount,
  });

  factory SupplierCreditsSummary.fromJson(Map<String, dynamic> json) {
    return SupplierCreditsSummary(
      totalCredit: (json['total_credit'] ?? 0).toDouble(),
      totalDebit: (json['total_debit'] ?? 0).toDouble(),
      totalBalance: (json['total_balance'] ?? 0).toDouble(),
      supplierCount: json['supplier_count'] ?? 0,
    );
  }
}

/// Response from GET /api/suppliers_creditors
class SupplierCreditsResponse {
  final List<SupplierCredit> suppliers;
  final SupplierCreditsSummary summary;

  SupplierCreditsResponse({
    required this.suppliers,
    required this.summary,
  });

  factory SupplierCreditsResponse.fromJson(Map<String, dynamic> json) {
    var suppliersJson = json['suppliers'] as List? ?? [];
    List<SupplierCredit> suppliersList = suppliersJson
        .map((s) => SupplierCredit.fromJson(s))
        .toList();

    return SupplierCreditsResponse(
      suppliers: suppliersList,
      summary: SupplierCreditsSummary.fromJson(json['summary'] ?? {}),
    );
  }
}

/// Supplier account transaction
class SupplierTransaction {
  final int? id;
  final String date;
  final double credit;
  final double debit;
  final int? receivingId;
  final String? description;
  final double balance;

  SupplierTransaction({
    this.id,
    required this.date,
    required this.credit,
    required this.debit,
    this.receivingId,
    this.description,
    required this.balance,
  });

  factory SupplierTransaction.fromJson(Map<String, dynamic> json) {
    return SupplierTransaction(
      id: json['id'],
      date: json['date'] ?? '',
      credit: (json['credit'] ?? 0).toDouble(),
      debit: (json['debit'] ?? 0).toDouble(),
      receivingId: json['receiving_id'],
      description: json['description'],
      balance: (json['balance'] ?? 0).toDouble(),
    );
  }
}

/// Credit transaction (receiving on credit)
class SupplierCreditTransaction {
  final int receivingId;
  final String date;
  final double credit;
  final double paid;
  final double balance;
  final String? dueDate;
  final String? paymentDueDate;
  final String employeeName;
  final bool isBadDebtor;

  SupplierCreditTransaction({
    required this.receivingId,
    required this.date,
    required this.credit,
    required this.paid,
    required this.balance,
    this.dueDate,
    this.paymentDueDate,
    required this.employeeName,
    required this.isBadDebtor,
  });

  factory SupplierCreditTransaction.fromJson(Map<String, dynamic> json) {
    return SupplierCreditTransaction(
      receivingId: json['receiving_id'] ?? 0,
      date: json['date'] ?? '',
      credit: (json['credit'] ?? 0).toDouble(),
      paid: (json['paid'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
      dueDate: json['due_date'],
      paymentDueDate: json['payment_due_date'],
      employeeName: json['employee_name'] ?? '',
      isBadDebtor: json['is_bad_debtor'] ?? false,
    );
  }
}

/// Response from GET /api/suppliers_creditors/account/:supplier_id
class SupplierAccountResponse {
  final int supplierId;
  final String supplierName;
  final String companyName;
  final String phone;
  final String startDate;
  final String endDate;
  final double openingBalance;
  final double currentBalance;
  final double totalCredit;
  final double totalDebit;
  final List<SupplierTransaction> transactions;
  final List<SupplierCreditTransaction> creditTransactions;

  SupplierAccountResponse({
    required this.supplierId,
    required this.supplierName,
    required this.companyName,
    required this.phone,
    required this.startDate,
    required this.endDate,
    required this.openingBalance,
    required this.currentBalance,
    required this.totalCredit,
    required this.totalDebit,
    required this.transactions,
    required this.creditTransactions,
  });

  factory SupplierAccountResponse.fromJson(Map<String, dynamic> json) {
    var transactionsJson = json['transactions'] as List? ?? [];
    List<SupplierTransaction> transactionsList = transactionsJson
        .map((t) => SupplierTransaction.fromJson(t))
        .toList();

    var creditTransactionsJson = json['credit_transactions'] as List? ?? [];
    List<SupplierCreditTransaction> creditTransactionsList = creditTransactionsJson
        .map((c) => SupplierCreditTransaction.fromJson(c))
        .toList();

    return SupplierAccountResponse(
      supplierId: json['supplier_id'] ?? 0,
      supplierName: json['supplier_name'] ?? '',
      companyName: json['company_name'] ?? '',
      phone: json['phone'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      openingBalance: (json['opening_balance'] ?? 0).toDouble(),
      currentBalance: (json['current_balance'] ?? 0).toDouble(),
      totalCredit: (json['total_credit'] ?? 0).toDouble(),
      totalDebit: (json['total_debit'] ?? 0).toDouble(),
      transactions: transactionsList,
      creditTransactions: creditTransactionsList,
    );
  }
}

/// Daily credit entry (credit purchase from supplier)
class SupplierDailyCreditEntry {
  final int receivingId;
  final String date;
  final String supplierName;
  final String companyName;
  final int supplierId;
  final double amount;
  final String employeeName;
  final int employeeId;
  final String reference;

  SupplierDailyCreditEntry({
    required this.receivingId,
    required this.date,
    required this.supplierName,
    required this.companyName,
    required this.supplierId,
    required this.amount,
    required this.employeeName,
    required this.employeeId,
    required this.reference,
  });

  String get displayName {
    if (companyName.isNotEmpty) {
      return supplierName.isNotEmpty ? '$supplierName - $companyName' : companyName;
    }
    return supplierName;
  }

  factory SupplierDailyCreditEntry.fromJson(Map<String, dynamic> json) {
    return SupplierDailyCreditEntry(
      receivingId: json['receiving_id'] ?? 0,
      date: json['date'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      companyName: json['company_name'] ?? '',
      supplierId: json['supplier_id'] ?? 0,
      amount: (json['amount'] ?? 0).toDouble(),
      employeeName: json['employee_name'] ?? '',
      employeeId: json['employee_id'] ?? 0,
      reference: json['reference'] ?? '',
    );
  }
}

/// Summary for daily reports
class SupplierDailyReportSummary {
  final double totalAmount;
  final int count;

  SupplierDailyReportSummary({
    required this.totalAmount,
    required this.count,
  });

  factory SupplierDailyReportSummary.fromJson(Map<String, dynamic> json) {
    return SupplierDailyReportSummary(
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      count: json['count'] ?? 0,
    );
  }
}

/// Response from GET /api/suppliers_creditors/daily_credit_report
class SupplierDailyCreditResponse {
  final String startDate;
  final String endDate;
  final List<SupplierDailyCreditEntry> credits;
  final SupplierDailyReportSummary summary;

  SupplierDailyCreditResponse({
    required this.startDate,
    required this.endDate,
    required this.credits,
    required this.summary,
  });

  factory SupplierDailyCreditResponse.fromJson(Map<String, dynamic> json) {
    var creditsJson = json['credits'] as List? ?? [];
    List<SupplierDailyCreditEntry> creditsList = creditsJson
        .map((c) => SupplierDailyCreditEntry.fromJson(c))
        .toList();

    return SupplierDailyCreditResponse(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      credits: creditsList,
      summary: SupplierDailyReportSummary.fromJson(json['summary'] ?? {}),
    );
  }
}

/// Daily debt entry (payment made to supplier)
class SupplierDailyDebtEntry {
  final int id;
  final String date;
  final String supplierName;
  final int supplierId;
  final double amount;
  final String employeeName;
  final int employeeId;
  final String description;
  final int paymentId;

  SupplierDailyDebtEntry({
    required this.id,
    required this.date,
    required this.supplierName,
    required this.supplierId,
    required this.amount,
    required this.employeeName,
    required this.employeeId,
    required this.description,
    required this.paymentId,
  });

  factory SupplierDailyDebtEntry.fromJson(Map<String, dynamic> json) {
    return SupplierDailyDebtEntry(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      supplierId: json['supplier_id'] ?? 0,
      amount: (json['amount'] ?? 0).toDouble(),
      employeeName: json['employee_name'] ?? '',
      employeeId: json['employee_id'] ?? 0,
      description: json['description'] ?? '',
      paymentId: json['payment_id'] ?? 0,
    );
  }
}

/// Response from GET /api/suppliers_creditors/daily_debt_report
class SupplierDailyDebtResponse {
  final String startDate;
  final String endDate;
  final List<SupplierDailyDebtEntry> debts;
  final SupplierDailyReportSummary summary;

  SupplierDailyDebtResponse({
    required this.startDate,
    required this.endDate,
    required this.debts,
    required this.summary,
  });

  factory SupplierDailyDebtResponse.fromJson(Map<String, dynamic> json) {
    var debtsJson = json['debts'] as List? ?? [];
    List<SupplierDailyDebtEntry> debtsList = debtsJson
        .map((d) => SupplierDailyDebtEntry.fromJson(d))
        .toList();

    return SupplierDailyDebtResponse(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      debts: debtsList,
      summary: SupplierDailyReportSummary.fromJson(json['summary'] ?? {}),
    );
  }
}
