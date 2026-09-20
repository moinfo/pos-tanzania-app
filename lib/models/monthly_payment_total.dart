/// One month's total paid, across all of a customer's contracts --
/// backs the portal Dashboard's payment-history chart
/// (api/Portal::payment_history()). Every month in the requested window
/// is present even if its total is 0, so the chart's x-axis is a
/// continuous timeline.
class MonthlyPaymentTotal {
  /// 'YYYY-MM'.
  final String month;
  final double total;

  const MonthlyPaymentTotal({required this.month, required this.total});

  factory MonthlyPaymentTotal.fromJson(Map<String, dynamic> json) {
    return MonthlyPaymentTotal(
      month: json['month'] as String? ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}
