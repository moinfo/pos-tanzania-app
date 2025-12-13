class CustomerTransactionBalance {
  final int customerId;
  final String customerName;
  final double totalDeposited;
  final double totalWithdrawn;
  final double balance;
  final String startDate;
  final String endDate;

  CustomerTransactionBalance({
    required this.customerId,
    required this.customerName,
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.balance,
    required this.startDate,
    required this.endDate,
  });

  factory CustomerTransactionBalance.fromJson(Map<String, dynamic> json) {
    return CustomerTransactionBalance(
      customerId: json['customer_id'] ?? 0,
      customerName: json['customer_name'] ?? '',
      totalDeposited: (json['total_deposited'] ?? 0).toDouble(),
      totalWithdrawn: (json['total_withdrawn'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
    );
  }
}

class Deposit {
  final int id;
  final int customerId;
  final String customerName;
  final double amount;
  final String date;
  final String description;

  Deposit({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.date,
    required this.description,
  });

  factory Deposit.fromJson(Map<String, dynamic> json) {
    return Deposit(
      id: json['id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      customerName: json['customer_name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class Withdrawal {
  final int id;
  final int customerId;
  final String customerName;
  final double amount;
  final String date;
  final String description;

  Withdrawal({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.date,
    required this.description,
  });

  factory Withdrawal.fromJson(Map<String, dynamic> json) {
    return Withdrawal(
      id: json['id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      customerName: json['customer_name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class TransactionStatement {
  final int customerId;
  final String customerName;
  final String startDate;
  final String endDate;
  final double openingBalance;
  final double closingBalance;
  final List<StatementTransaction> transactions;

  TransactionStatement({
    required this.customerId,
    required this.customerName,
    required this.startDate,
    required this.endDate,
    required this.openingBalance,
    required this.closingBalance,
    required this.transactions,
  });

  factory TransactionStatement.fromJson(Map<String, dynamic> json) {
    var transactionsList = (json['transactions'] as List? ?? [])
        .map((t) => StatementTransaction.fromJson(t))
        .toList();

    return TransactionStatement(
      customerId: json['customer_id'] ?? 0,
      customerName: json['customer_name'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      openingBalance: (json['opening_balance'] ?? 0).toDouble(),
      closingBalance: (json['closing_balance'] ?? 0).toDouble(),
      transactions: transactionsList,
    );
  }
}

class StatementTransaction {
  final int id;
  final String date;
  final String type; // 'deposit' or 'withdrawal'
  final double deposit;
  final double withdrawal;
  final String description;
  final double balance;

  StatementTransaction({
    required this.id,
    required this.date,
    required this.type,
    required this.deposit,
    required this.withdrawal,
    required this.description,
    required this.balance,
  });

  factory StatementTransaction.fromJson(Map<String, dynamic> json) {
    return StatementTransaction(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      type: json['type'] ?? '',
      deposit: (json['deposit'] ?? 0).toDouble(),
      withdrawal: (json['withdrawal'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
    );
  }
}

class TransactionFormData {
  final int customerId;
  final double amount;
  final String? description;
  final String? date;

  TransactionFormData({
    required this.customerId,
    required this.amount,
    this.description,
    this.date,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'customer_id': customerId,
      'amount': amount,
    };

    if (description != null && description!.isNotEmpty) {
      map['description'] = description;
    }
    if (date != null) {
      map['date'] = date;
    }

    return map;
  }
}

// ============================================
// CASH BASIS MODELS
// ============================================

class CashBasisCategory {
  final int id;
  final String name;
  final String description;

  CashBasisCategory({
    required this.id,
    required this.name,
    required this.description,
  });

  factory CashBasisCategory.fromJson(Map<String, dynamic> json) {
    return CashBasisCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class CashBasisTransaction {
  final int id;
  final int cashBasisId;
  final String cashBasisName;
  final double amount;
  final String date;

  CashBasisTransaction({
    required this.id,
    required this.cashBasisId,
    required this.cashBasisName,
    required this.amount,
    required this.date,
  });

  factory CashBasisTransaction.fromJson(Map<String, dynamic> json) {
    return CashBasisTransaction(
      id: json['id'] ?? 0,
      cashBasisId: json['cash_basis_id'] ?? 0,
      cashBasisName: json['cash_basis_name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'] ?? '',
    );
  }
}

class CashBasisResponse {
  final String startDate;
  final String endDate;
  final List<CashBasisTransaction> transactions;
  final double total;

  CashBasisResponse({
    required this.startDate,
    required this.endDate,
    required this.transactions,
    required this.total,
  });

  factory CashBasisResponse.fromJson(Map<String, dynamic> json) {
    var transactionsList = (json['transactions'] as List? ?? [])
        .map((t) => CashBasisTransaction.fromJson(t))
        .toList();

    return CashBasisResponse(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      transactions: transactionsList,
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

// ============================================
// BANK BASIS MODELS
// ============================================

class BankBasisCategory {
  final int id;
  final String name;
  final String description;

  BankBasisCategory({
    required this.id,
    required this.name,
    required this.description,
  });

  factory BankBasisCategory.fromJson(Map<String, dynamic> json) {
    return BankBasisCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class BankBasisTransaction {
  final int id;
  final int bankBasisId;
  final String bankBasisName;
  final double amount;
  final String date;

  BankBasisTransaction({
    required this.id,
    required this.bankBasisId,
    required this.bankBasisName,
    required this.amount,
    required this.date,
  });

  factory BankBasisTransaction.fromJson(Map<String, dynamic> json) {
    return BankBasisTransaction(
      id: json['id'] ?? 0,
      bankBasisId: json['bank_basis_id'] ?? 0,
      bankBasisName: json['bank_basis_name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'] ?? '',
    );
  }
}

class BankBasisResponse {
  final String startDate;
  final String endDate;
  final List<BankBasisTransaction> transactions;
  final double total;

  BankBasisResponse({
    required this.startDate,
    required this.endDate,
    required this.transactions,
    required this.total,
  });

  factory BankBasisResponse.fromJson(Map<String, dynamic> json) {
    var transactionsList = (json['transactions'] as List? ?? [])
        .map((t) => BankBasisTransaction.fromJson(t))
        .toList();

    return BankBasisResponse(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      transactions: transactionsList,
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

// ============================================
// WAKALA/SIM MODELS
// ============================================

class Sim {
  final int id;
  final String name;
  final String description;

  Sim({
    required this.id,
    required this.name,
    required this.description,
  });

  factory Sim.fromJson(Map<String, dynamic> json) {
    return Sim(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class WakalaTransaction {
  final int id;
  final int simId;
  final String simName;
  final double amount;
  final String date;

  WakalaTransaction({
    required this.id,
    required this.simId,
    required this.simName,
    required this.amount,
    required this.date,
  });

  factory WakalaTransaction.fromJson(Map<String, dynamic> json) {
    return WakalaTransaction(
      id: json['id'] ?? 0,
      simId: json['sim_id'] ?? 0,
      simName: json['sim_name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'] ?? '',
    );
  }
}

class WakalaResponse {
  final String startDate;
  final String endDate;
  final List<WakalaTransaction> transactions;
  final double total;

  WakalaResponse({
    required this.startDate,
    required this.endDate,
    required this.transactions,
    required this.total,
  });

  factory WakalaResponse.fromJson(Map<String, dynamic> json) {
    var transactionsList = (json['transactions'] as List? ?? [])
        .map((t) => WakalaTransaction.fromJson(t))
        .toList();

    return WakalaResponse(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      transactions: transactionsList,
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

// ============================================
// WAKALA REPORT MODEL
// ============================================

class WakalaReportItem {
  final int id;
  final String name;
  final double amount;

  WakalaReportItem({
    required this.id,
    required this.name,
    required this.amount,
  });

  factory WakalaReportItem.fromJson(Map<String, dynamic> json) {
    return WakalaReportItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

class WakalaReportSection {
  final List<WakalaReportItem> list;
  final double total;

  WakalaReportSection({
    required this.list,
    required this.total,
  });

  factory WakalaReportSection.fromJson(Map<String, dynamic> json) {
    var itemsList = (json['list'] as List? ?? [])
        .map((item) => WakalaReportItem.fromJson(item))
        .toList();

    return WakalaReportSection(
      list: itemsList,
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

class WakalaExpenseReportItem {
  final int id;
  final String description;
  final double amount;
  final String date;

  WakalaExpenseReportItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
  });

  factory WakalaExpenseReportItem.fromJson(Map<String, dynamic> json) {
    return WakalaExpenseReportItem(
      id: json['id'] ?? 0,
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'] ?? '',
    );
  }
}

class WakalaExpensesSection {
  final List<WakalaExpenseReportItem> list;
  final double total;

  WakalaExpensesSection({
    required this.list,
    required this.total,
  });

  factory WakalaExpensesSection.fromJson(Map<String, dynamic> json) {
    var itemsList = (json['list'] as List? ?? [])
        .map((item) => WakalaExpenseReportItem.fromJson(item))
        .toList();

    return WakalaExpensesSection(
      list: itemsList,
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

class CreditorDebtorItem {
  final int id;
  final String customerName;
  final String description;
  final double amount;
  final String date;

  CreditorDebtorItem({
    required this.id,
    required this.customerName,
    required this.description,
    required this.amount,
    required this.date,
  });

  factory CreditorDebtorItem.fromJson(Map<String, dynamic> json) {
    return CreditorDebtorItem(
      id: json['id'] ?? 0,
      customerName: json['customer_name'] ?? '',
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'] ?? '',
    );
  }
}

class CreditorDebtorSection {
  final List<CreditorDebtorItem> list;
  final double total;

  CreditorDebtorSection({
    required this.list,
    required this.total,
  });

  factory CreditorDebtorSection.fromJson(Map<String, dynamic> json) {
    var itemsList = (json['list'] as List? ?? [])
        .map((item) => CreditorDebtorItem.fromJson(item))
        .toList();

    return CreditorDebtorSection(
      list: itemsList,
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

class WakalaReport {
  final String startDate;
  final String endDate;
  final WakalaReportSection sims;
  final WakalaReportSection bankBasis;
  final WakalaReportSection cashBasis;
  final WakalaExpensesSection wakalaExpenses;
  final double float;
  final double totalDeposited;
  final double totalWithdrawn;
  final double openingBalance;
  final double closingBalance;
  final double netTotal;
  final double actualCapital;
  final double calculatedCapital;
  final double gainLoss;
  final CreditorDebtorSection creditors;
  final CreditorDebtorSection debtors;

  WakalaReport({
    required this.startDate,
    required this.endDate,
    required this.sims,
    required this.bankBasis,
    required this.cashBasis,
    required this.wakalaExpenses,
    required this.float,
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.openingBalance,
    required this.closingBalance,
    required this.netTotal,
    required this.actualCapital,
    required this.calculatedCapital,
    required this.gainLoss,
    required this.creditors,
    required this.debtors,
  });

  factory WakalaReport.fromJson(Map<String, dynamic> json) {
    return WakalaReport(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      sims: WakalaReportSection.fromJson(json['sims'] ?? {}),
      bankBasis: WakalaReportSection.fromJson(json['bank_basis'] ?? {}),
      cashBasis: WakalaReportSection.fromJson(json['cash_basis'] ?? {}),
      wakalaExpenses: WakalaExpensesSection.fromJson(json['wakala_expenses'] ?? {}),
      float: _toDouble(json['float']),
      totalDeposited: _toDouble(json['total_deposited']),
      totalWithdrawn: _toDouble(json['total_withdrawn']),
      openingBalance: _toDouble(json['opening_balance']),
      closingBalance: _toDouble(json['closing_balance']),
      netTotal: _toDouble(json['net_total']),
      actualCapital: _toDouble(json['actual_capital'] ?? json['capital']),
      calculatedCapital: _toDouble(json['calculated_capital']),
      gainLoss: _toDouble(json['gain_loss']),
      creditors: CreditorDebtorSection.fromJson(json['creditors'] ?? {}),
      debtors: CreditorDebtorSection.fromJson(json['debtors'] ?? {}),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

// ============================================
// WAKALA EXPENSE MODELS
// ============================================

class WakalaExpense {
  final int id;
  final double amount;
  final String description;
  final String date;

  WakalaExpense({
    required this.id,
    required this.amount,
    required this.description,
    required this.date,
  });

  factory WakalaExpense.fromJson(Map<String, dynamic> json) {
    return WakalaExpense(
      id: json['id'] ?? 0,
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      date: json['date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'date': date,
    };
  }
}

class WakalaExpenseResponse {
  final String startDate;
  final String endDate;
  final List<WakalaExpense> expenses;
  final double total;

  WakalaExpenseResponse({
    required this.startDate,
    required this.endDate,
    required this.expenses,
    required this.total,
  });

  factory WakalaExpenseResponse.fromJson(Map<String, dynamic> json) {
    var expensesList = (json['expenses'] as List? ?? [])
        .map((e) => WakalaExpense.fromJson(e))
        .toList();

    return WakalaExpenseResponse(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      expenses: expensesList,
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

class WakalaExpenseFormData {
  final double amount;
  final String description;
  final String date;

  WakalaExpenseFormData({
    required this.amount,
    this.description = '',
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'description': description,
      'date': date,
    };
  }
}
