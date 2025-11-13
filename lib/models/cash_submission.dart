import 'supervisor.dart';

class CashSubmission {
  final String id;
  final double amount;
  final String date;
  final Supervisor? supervisor;
  final String? createdAt;

  CashSubmission({
    required this.id,
    required this.amount,
    required this.date,
    this.supervisor,
    this.createdAt,
  });

  factory CashSubmission.fromJson(Map<String, dynamic> json) {
    return CashSubmission(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] is String)
          ? double.tryParse(json['amount']) ?? 0.0
          : (json['amount']?.toDouble() ?? 0.0),
      date: json['date'] ?? '',
      supervisor: json['supervisor'] != null
          ? Supervisor.fromJson(json['supervisor'])
          : null,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'date': date,
      'supervisor': supervisor?.toJson(),
      'created_at': createdAt,
    };
  }
}
