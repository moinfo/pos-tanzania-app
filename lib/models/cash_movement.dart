// Direct Deposit / Direct Withdraw entries.
//
// Backend: application/controllers/api/Cash_movements.php over the shared
// ospos_cash_movements table -- the same rows the web Cash Submit screen
// reads, so an entry made here feeds its Cash Amount formula and vice versa.

class CashMovement {
  final int id;

  /// 'deposit' | 'withdraw' -- the API rejects anything else with a 400.
  final String type;
  final double amount;

  /// Y-m-d. The API validates the format with a regex and 400s on a mismatch.
  final String date;
  final String? comment;
  final int? supervisorId;
  final String? createdAt;

  CashMovement({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.comment,
    this.supervisorId,
    this.createdAt,
  });

  factory CashMovement.fromJson(Map<String, dynamic> json) {
    return CashMovement(
      id: _toInt(json['id']),
      type: json['type']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      date: json['date']?.toString() ?? '',
      comment: (json['comment']?.toString().isEmpty ?? true)
          ? null
          : json['comment'].toString(),
      supervisorId:
          json['supervisor_id'] == null ? null : _toInt(json['supervisor_id']),
      createdAt: json['created_at']?.toString(),
    );
  }

  bool get isDeposit => type == 'deposit';

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static double _toDouble(dynamic v, {double fallback = 0.0}) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fallback;
  }
}

class CashMovementListResponse {
  final List<CashMovement> movements;
  final int total;

  CashMovementListResponse({required this.movements, required this.total});

  factory CashMovementListResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['movements'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(CashMovement.fromJson)
            .toList() ??
        [];
    return CashMovementListResponse(
      movements: list,
      total: json['total'] == null
          ? list.length
          : CashMovement._toInt(json['total'], fallback: list.length),
    );
  }

  double get totalAmount =>
      movements.fold(0.0, (sum, m) => sum + m.amount);
}
