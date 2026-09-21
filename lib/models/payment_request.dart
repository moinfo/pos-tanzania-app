/// A payment the customer submitted themselves (amount + receipt photo),
/// awaiting staff approval -- backs api/Portal::payment_requests(). Doesn't
/// touch the contract balance until status is 'approved'.
class PaymentRequest {
  final int id;
  final int contractId;
  final double amount;
  final String date;
  final String receiptUrl;

  /// 'pending' | 'approved' | 'rejected'.
  final String status;
  final String? rejectionReason;
  final String createdAt;

  const PaymentRequest({
    required this.id,
    required this.contractId,
    required this.amount,
    required this.date,
    required this.receiptUrl,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
  });

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    return PaymentRequest(
      id: json['id'] as int? ?? 0,
      contractId: json['contract_id'] as int? ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: json['date'] as String? ?? '',
      receiptUrl: json['receipt_url'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
