double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class LipaNambaAccount {
  final int id;
  final String name;
  final String number;
  final String description;
  final double totalDeposits;
  final double totalWithdraws;
  final double totalFees;
  final double float;

  LipaNambaAccount({
    required this.id,
    required this.name,
    required this.number,
    required this.description,
    required this.totalDeposits,
    required this.totalWithdraws,
    required this.totalFees,
    required this.float,
  });

  factory LipaNambaAccount.fromJson(Map<String, dynamic> json) {
    return LipaNambaAccount(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      number: json['number'] ?? '',
      description: json['description'] ?? '',
      totalDeposits: _toDouble(json['total_deposits']),
      totalWithdraws: _toDouble(json['total_withdraws']),
      totalFees: _toDouble(json['total_fees']),
      float: _toDouble(json['float']),
    );
  }
}

class LipaNambaTransaction {
  final int id;
  final int lipaNambaId;
  final String lipaNambaName;
  final String lipaNambaNumber;
  final String type;
  final double amount;
  final double fee;
  final String clientName;
  final String clientPhone;
  final String notes;
  final String transactionDate;

  LipaNambaTransaction({
    required this.id,
    required this.lipaNambaId,
    required this.lipaNambaName,
    required this.lipaNambaNumber,
    required this.type,
    required this.amount,
    required this.fee,
    required this.clientName,
    required this.clientPhone,
    required this.notes,
    required this.transactionDate,
  });

  bool get isDeposit => type == 'deposit';

  factory LipaNambaTransaction.fromJson(Map<String, dynamic> json) {
    return LipaNambaTransaction(
      id: json['id'] ?? 0,
      lipaNambaId: json['lipa_namba_id'] ?? 0,
      lipaNambaName: json['lipa_namba_name'] ?? '',
      lipaNambaNumber: json['lipa_namba_number'] ?? '',
      type: json['type'] ?? '',
      amount: _toDouble(json['amount']),
      fee: _toDouble(json['fee']),
      clientName: json['client_name'] ?? '',
      clientPhone: json['client_phone'] ?? '',
      notes: json['notes'] ?? '',
      transactionDate: json['transaction_date'] ?? '',
    );
  }
}

class LipaNambaTransactionsSummary {
  final double totalDeposits;
  final double totalWithdraws;
  final double totalFees;
  final int depositCount;
  final int withdrawCount;
  final double net;

  LipaNambaTransactionsSummary({
    required this.totalDeposits,
    required this.totalWithdraws,
    required this.totalFees,
    required this.depositCount,
    required this.withdrawCount,
    required this.net,
  });

  factory LipaNambaTransactionsSummary.fromJson(Map<String, dynamic> json) {
    return LipaNambaTransactionsSummary(
      totalDeposits: _toDouble(json['total_deposits']),
      totalWithdraws: _toDouble(json['total_withdraws']),
      totalFees: _toDouble(json['total_fees']),
      depositCount: json['deposit_count'] ?? 0,
      withdrawCount: json['withdraw_count'] ?? 0,
      net: _toDouble(json['net']),
    );
  }
}

class LipaNambaTransactionsResponse {
  final String startDate;
  final String endDate;
  final int? lipaNambaId;
  final List<LipaNambaTransaction> transactions;
  final LipaNambaTransactionsSummary summary;

  LipaNambaTransactionsResponse({
    required this.startDate,
    required this.endDate,
    required this.lipaNambaId,
    required this.transactions,
    required this.summary,
  });

  factory LipaNambaTransactionsResponse.fromJson(Map<String, dynamic> json) {
    return LipaNambaTransactionsResponse(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      lipaNambaId: json['lipa_namba_id'],
      transactions: (json['transactions'] as List? ?? [])
          .map((t) => LipaNambaTransaction.fromJson(t))
          .toList(),
      summary: LipaNambaTransactionsSummary.fromJson(json['summary'] ?? {}),
    );
  }
}

class LipaNambaFeeTier {
  final int id;
  final double minAmount;
  final double maxAmount;
  final double fee;

  LipaNambaFeeTier({
    required this.id,
    required this.minAmount,
    required this.maxAmount,
    required this.fee,
  });

  factory LipaNambaFeeTier.fromJson(Map<String, dynamic> json) {
    return LipaNambaFeeTier(
      id: json['id'] ?? 0,
      minAmount: _toDouble(json['min_amount']),
      maxAmount: _toDouble(json['max_amount']),
      fee: _toDouble(json['fee']),
    );
  }
}
