// Cash Submit models for daily cash reconciliation

class CashSubmitListItem {
  final int id;
  final double amount;
  final String date;
  final int supervisorId;
  final String supervisorName;
  final int? stockLocationId;
  final String createdAt;

  CashSubmitListItem({
    required this.id,
    required this.amount,
    required this.date,
    required this.supervisorId,
    required this.supervisorName,
    this.stockLocationId,
    required this.createdAt,
  });

  factory CashSubmitListItem.fromJson(Map<String, dynamic> json) {
    return CashSubmitListItem(
      id: json['id'] as int,
      amount: (json['amount'] is int)
          ? (json['amount'] as int).toDouble()
          : json['amount'] as double,
      date: json['date'] as String,
      supervisorId: json['supervisor_id'] as int,
      supervisorName: json['supervisor_name'] as String? ?? '',
      stockLocationId: json['stock_location_id'] as int?,
      createdAt: json['created_at'] as String,
    );
  }
}

class CashSubmitDetails {
  final int id;
  final double amount;
  final String date;
  final int supervisorId;
  final String supervisorName;
  final int? stockLocationId;
  final String createdAt;

  CashSubmitDetails({
    required this.id,
    required this.amount,
    required this.date,
    required this.supervisorId,
    required this.supervisorName,
    this.stockLocationId,
    required this.createdAt,
  });

  factory CashSubmitDetails.fromJson(Map<String, dynamic> json) {
    return CashSubmitDetails(
      id: json['id'] as int,
      amount: (json['amount'] is int)
          ? (json['amount'] as int).toDouble()
          : json['amount'] as double,
      date: json['date'] as String,
      supervisorId: json['supervisor_id'] as int,
      supervisorName: json['supervisor_name'] as String? ?? '',
      stockLocationId: json['stock_location_id'] as int?,
      createdAt: json['created_at'] as String,
    );
  }
}

class CashSubmitCreate {
  final double amount;
  final String date;
  final int supervisorId;

  CashSubmitCreate({
    required this.amount,
    required this.date,
    required this.supervisorId,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'date': date,
      'supervisor_id': supervisorId,
    };
  }
}

class TodaySummary {
  final double opening;
  final double turnover;
  final double allSales;
  final double cashSales;
  final double creditCardSales;
  final double customerCredit;
  final double salesReturn;
  final double customerDebit;
  final double supplierDebitCash;
  final double supplierDebitBank;
  final double expenses;
  final double transportCostCash;
  final double transportCostCC;
  final double bank;
  final double cashSubmitted;
  final double profitSubmitted;
  final double cashAmount;
  final double gainLoss;
  final double profit;

  TodaySummary({
    required this.opening,
    required this.turnover,
    required this.allSales,
    required this.cashSales,
    required this.creditCardSales,
    required this.customerCredit,
    required this.salesReturn,
    required this.customerDebit,
    required this.supplierDebitCash,
    required this.supplierDebitBank,
    required this.expenses,
    required this.transportCostCash,
    required this.transportCostCC,
    required this.bank,
    required this.cashSubmitted,
    required this.profitSubmitted,
    required this.cashAmount,
    required this.gainLoss,
    required this.profit,
  });

  factory TodaySummary.fromJson(Map<String, dynamic> json) {
    return TodaySummary(
      opening: _toDouble(json['opening']),
      turnover: _toDouble(json['turnover']),
      allSales: _toDouble(json['all_sales']),
      cashSales: _toDouble(json['cash_sales']),
      creditCardSales: _toDouble(json['credit_card_sales']),
      customerCredit: _toDouble(json['customer_credit']),
      salesReturn: _toDouble(json['sales_return']),
      customerDebit: _toDouble(json['customer_debit']),
      supplierDebitCash: _toDouble(json['supplier_debit_cash']),
      supplierDebitBank: _toDouble(json['supplier_debit_bank']),
      expenses: _toDouble(json['expenses']),
      transportCostCash: _toDouble(json['transport_cost_cash']),
      transportCostCC: _toDouble(json['transport_cost_cc']),
      bank: _toDouble(json['bank']),
      cashSubmitted: _toDouble(json['cash_submitted']),
      profitSubmitted: _toDouble(json['profit_submitted']),
      cashAmount: _toDouble(json['cash_amount']),
      gainLoss: _toDouble(json['gain_loss']),
      profit: _toDouble(json['profit']),
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
