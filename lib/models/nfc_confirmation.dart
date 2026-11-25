/// What the server returns after logging a tap of the customer's NFC card
/// (confirm_credit / confirm_cash / confirm_payment).
class NfcConfirmationResult {
  final int confirmationId;
  final int customerId;
  final String customerName;
  final double amount;

  NfcConfirmationResult({
    required this.confirmationId,
    required this.customerId,
    required this.customerName,
    required this.amount,
  });

  factory NfcConfirmationResult.fromJson(Map<String, dynamic> json) {
    return NfcConfirmationResult(
      confirmationId: _asInt(json['confirmation_id']),
      customerId: _asInt(json['customer_id']),
      customerName: json['customer_name']?.toString() ?? '',
      amount: _asDouble(json['amount']),
    );
  }
}

/// A customer's NFC settings. [nfcEnabled] is the only flag: when true, a
/// credit sale, a cash sale or a payment must be confirmed by tapping the
/// customer's card.
class NfcCustomerSettings {
  final int customerId;
  final String customerName;
  final bool nfcEnabled;

  /// Set for a child customer, which taps its parent's card.
  final int? parentId;

  NfcCustomerSettings({
    required this.customerId,
    required this.customerName,
    required this.nfcEnabled,
    this.parentId,
  });

  factory NfcCustomerSettings.fromJson(Map<String, dynamic> json) {
    final flag = json['nfc_enabled'] ?? json['nfc_payment_enabled'];
    return NfcCustomerSettings(
      customerId: _asInt(json['customer_id']),
      customerName: json['customer_name']?.toString() ?? '',
      nfcEnabled: flag == true || flag == 1 || flag == '1',
      parentId: json['parent_id'] == null ? null : _asInt(json['parent_id']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}
