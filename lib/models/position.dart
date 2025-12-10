// Position model for daily financial position report

class DailyPosition {
  final String date;
  final double openingStock;
  final double receiving;
  final double salesCost;
  final double closingStock;
  final double changes;
  final double stockFrustration;
  final double bankBalance;
  final double creditCustomer;
  final double creditSupplier;
  final double cashSubmitted;
  final double expenses;
  final double profit;
  final double capital;

  DailyPosition({
    required this.date,
    required this.openingStock,
    required this.receiving,
    required this.salesCost,
    required this.closingStock,
    required this.changes,
    required this.stockFrustration,
    required this.bankBalance,
    required this.creditCustomer,
    required this.creditSupplier,
    required this.cashSubmitted,
    required this.expenses,
    required this.profit,
    required this.capital,
  });

  factory DailyPosition.fromJson(Map<String, dynamic> json) {
    return DailyPosition(
      date: json['date'] ?? '',
      openingStock: _parseDouble(json['opening_stock']),
      receiving: _parseDouble(json['receiving']),
      salesCost: _parseDouble(json['sales_cost']),
      closingStock: _parseDouble(json['closing_stock']),
      changes: _parseDouble(json['changes']),
      stockFrustration: _parseDouble(json['stock_frustration']),
      bankBalance: _parseDouble(json['bank_balance']),
      creditCustomer: _parseDouble(json['credit_customer']),
      creditSupplier: _parseDouble(json['credit_supplier']),
      cashSubmitted: _parseDouble(json['cash_submitted']),
      expenses: _parseDouble(json['expenses']),
      profit: _parseDouble(json['profit']),
      capital: _parseDouble(json['capital']),
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

class PositionTotals {
  final double openingStock;
  final double receiving;
  final double salesCost;
  final double closingStock;
  final double changes;
  final double stockFrustration;
  final double bankBalance;
  final double creditCustomer;
  final double creditSupplier;
  final double cashSubmitted;
  final double expenses;
  final double profit;
  final double capital;

  PositionTotals({
    required this.openingStock,
    required this.receiving,
    required this.salesCost,
    required this.closingStock,
    required this.changes,
    required this.stockFrustration,
    required this.bankBalance,
    required this.creditCustomer,
    required this.creditSupplier,
    required this.cashSubmitted,
    required this.expenses,
    required this.profit,
    required this.capital,
  });

  factory PositionTotals.fromJson(Map<String, dynamic> json) {
    return PositionTotals(
      openingStock: _parseDouble(json['opening_stock']),
      receiving: _parseDouble(json['receiving']),
      salesCost: _parseDouble(json['sales_cost']),
      closingStock: _parseDouble(json['closing_stock']),
      changes: _parseDouble(json['changes']),
      stockFrustration: _parseDouble(json['stock_frustration']),
      bankBalance: _parseDouble(json['bank_balance']),
      creditCustomer: _parseDouble(json['credit_customer']),
      creditSupplier: _parseDouble(json['credit_supplier']),
      cashSubmitted: _parseDouble(json['cash_submitted']),
      expenses: _parseDouble(json['expenses']),
      profit: _parseDouble(json['profit']),
      capital: _parseDouble(json['capital']),
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

class PositionsReport {
  final String startDate;
  final String endDate;
  final int? stockLocationId;
  final List<DailyPosition> positions;
  final PositionTotals totals;

  PositionsReport({
    required this.startDate,
    required this.endDate,
    this.stockLocationId,
    required this.positions,
    required this.totals,
  });

  factory PositionsReport.fromJson(Map<String, dynamic> json) {
    final filters = json['filters'] as Map<String, dynamic>? ?? {};
    final positionsList = (json['positions'] as List? ?? [])
        .map((item) => DailyPosition.fromJson(item))
        .toList();

    return PositionsReport(
      startDate: filters['start_date'] ?? '',
      endDate: filters['end_date'] ?? '',
      stockLocationId: filters['stock_location_id'] != null
          ? int.tryParse(filters['stock_location_id'].toString())
          : null,
      positions: positionsList,
      totals: PositionTotals.fromJson(json['totals'] ?? {}),
    );
  }
}
