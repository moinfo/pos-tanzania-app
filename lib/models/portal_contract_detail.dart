import 'contract.dart';

/// One payment on the customer statement, with its running "ahead/behind"
/// balance -- the same ledger web's portal contract page shows
/// (Contract::get_payment_ledger() on the backend). Positive
/// runningBalance = still owed at that point, negative = paid ahead.
class PortalPayment {
  final int id;
  final String date;
  final String description;
  final double amount;
  final double runningBalance;

  /// Null when staff entered this payment directly without one -- the
  /// customer can still attach one after the fact (see
  /// CustomerApiService.attachPaymentReceipt()), but can't change the
  /// amount/date of the already-applied payment.
  final String? receiptUrl;

  const PortalPayment({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.runningBalance,
    this.receiptUrl,
  });

  factory PortalPayment.fromJson(Map<String, dynamic> json) {
    return PortalPayment(
      id: json['id'] as int? ?? 0,
      date: json['date'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      runningBalance: (json['running_balance'] as num?)?.toDouble() ?? 0,
      receiptUrl: json['receipt_url'] as String?,
    );
  }
}

/// Full customer-portal contract detail -- [contract] carries the same
/// fields/metrics the plain contract list does, plus the stat-card and
/// payment-ledger numbers only the detail endpoint computes.
class PortalContractDetail {
  final Contract contract;
  final double owedToDate;
  final int progressPct;
  final List<PortalPayment> paymentsList;
  final double undatedTotal;

  const PortalContractDetail({
    required this.contract,
    required this.owedToDate,
    required this.progressPct,
    required this.paymentsList,
    required this.undatedTotal,
  });

  factory PortalContractDetail.fromJson(Map<String, dynamic> json) {
    final list = (json['payments_list'] as List?) ?? [];
    return PortalContractDetail(
      contract: Contract.fromJson(json),
      owedToDate: (json['owed_to_date'] as num?)?.toDouble() ?? 0,
      progressPct: (json['progress_pct'] as num?)?.toInt() ?? 0,
      paymentsList: list
          .map((e) => PortalPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
      undatedTotal: (json['undated_total'] as num?)?.toDouble() ?? 0,
    );
  }
}
