/// Models for NFC Wallet functionality

/// NFC Card with balance information
class NfcCardBalance {
  final int cardId;
  final String cardUid;
  final int customerId;
  final String customerName;
  final String? phoneNumber;
  final double balance;
  final double totalDeposited;
  final double totalSpent;
  final bool isActive;
  final bool nfcConfirmRequired;
  final bool nfcPaymentEnabled;

  NfcCardBalance({
    required this.cardId,
    required this.cardUid,
    required this.customerId,
    required this.customerName,
    this.phoneNumber,
    required this.balance,
    required this.totalDeposited,
    required this.totalSpent,
    required this.isActive,
    required this.nfcConfirmRequired,
    required this.nfcPaymentEnabled,
  });

  factory NfcCardBalance.fromJson(Map<String, dynamic> json) {
    return NfcCardBalance(
      cardId: _parseInt(json['card_id']),
      cardUid: json['card_uid']?.toString() ?? '',
      customerId: _parseInt(json['customer_id']),
      customerName: json['customer_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString(),
      balance: _parseDouble(json['balance']),
      totalDeposited: _parseDouble(json['total_deposited']),
      totalSpent: _parseDouble(json['total_spent']),
      isActive: _parseBool(json['is_active']),
      nfcConfirmRequired: _parseBool(json['nfc_confirm_required']),
      nfcPaymentEnabled: _parseBool(json['nfc_payment_enabled']),
    );
  }

  bool get canPay => nfcPaymentEnabled && balance > 0;

  static int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static bool _parseBool(dynamic value, [bool defaultValue = false]) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return defaultValue;
  }
}

/// NFC Card Transaction
class NfcCardTransaction {
  final int id;
  final String transactionType; // deposit, payment, refund, adjustment
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? referenceType;
  final int? referenceId;
  final String? description;
  final String? employeeName;
  final String? locationName;
  final DateTime createdAt;

  NfcCardTransaction({
    required this.id,
    required this.transactionType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.referenceType,
    this.referenceId,
    this.description,
    this.employeeName,
    this.locationName,
    required this.createdAt,
  });

  factory NfcCardTransaction.fromJson(Map<String, dynamic> json) {
    return NfcCardTransaction(
      id: NfcCardBalance._parseInt(json['id']),
      transactionType: json['transaction_type']?.toString() ?? '',
      amount: NfcCardBalance._parseDouble(json['amount']),
      balanceBefore: NfcCardBalance._parseDouble(json['balance_before']),
      balanceAfter: NfcCardBalance._parseDouble(json['balance_after']),
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id'] != null ? NfcCardBalance._parseInt(json['reference_id']) : null,
      description: json['description']?.toString(),
      employeeName: json['employee_name']?.toString(),
      locationName: json['location_name']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool get isDeposit => amount > 0;
  bool get isPayment => amount < 0;
}

/// NFC Confirmation record
class NfcConfirmation {
  final int id;
  final String cardUid;
  final String confirmationType; // credit_sale, payment, deposit, withdrawal
  final double amount;
  final String? referenceType;
  final int? referenceId;
  final String status; // confirmed, rejected, expired
  final int customerId;
  final String customerName;
  final String? customerPhone;
  final String? employeeName;
  final String? locationName;
  final DateTime createdAt;

  NfcConfirmation({
    required this.id,
    required this.cardUid,
    required this.confirmationType,
    required this.amount,
    this.referenceType,
    this.referenceId,
    required this.status,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.employeeName,
    this.locationName,
    required this.createdAt,
  });

  factory NfcConfirmation.fromJson(Map<String, dynamic> json) {
    return NfcConfirmation(
      id: NfcCardBalance._parseInt(json['id']),
      cardUid: json['card_uid']?.toString() ?? '',
      confirmationType: json['confirmation_type']?.toString() ?? '',
      amount: NfcCardBalance._parseDouble(json['amount']),
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id'] != null ? NfcCardBalance._parseInt(json['reference_id']) : null,
      status: json['status']?.toString() ?? 'confirmed',
      customerId: NfcCardBalance._parseInt(json['customer_id']),
      customerName: json['customer_name']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString(),
      employeeName: json['employee_name']?.toString(),
      locationName: json['location_name']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String get confirmationTypeDisplay {
    switch (confirmationType) {
      case 'credit_sale':
        return 'Credit Sale';
      case 'payment':
        return 'Payment';
      case 'deposit':
        return 'Deposit';
      case 'withdrawal':
        return 'Withdrawal';
      default:
        return confirmationType;
    }
  }
}

/// NFC Statement with card info and transactions
class NfcStatement {
  final NfcCardBalance card;
  final double totalDeposits;
  final double totalPayments;
  final int totalTransactions;
  final List<NfcCardTransaction> transactions;

  NfcStatement({
    required this.card,
    required this.totalDeposits,
    required this.totalPayments,
    required this.totalTransactions,
    required this.transactions,
  });

  factory NfcStatement.fromJson(Map<String, dynamic> json) {
    final cardData = json['card'] as Map<String, dynamic>? ?? {};
    final summaryData = json['summary'] as Map<String, dynamic>? ?? {};
    final transactionsData = json['transactions'] as List<dynamic>? ?? [];

    return NfcStatement(
      card: NfcCardBalance.fromJson(cardData),
      totalDeposits: NfcCardBalance._parseDouble(summaryData['total_deposits']),
      totalPayments: NfcCardBalance._parseDouble(summaryData['total_payments']),
      totalTransactions: NfcCardBalance._parseInt(summaryData['total_transactions']),
      transactions: transactionsData
          .map((e) => NfcCardTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// NFC Customer Settings
class NfcCustomerSettings {
  final int customerId;
  final String customerName;
  final bool nfcConfirmRequired;
  final bool nfcPaymentEnabled;

  NfcCustomerSettings({
    required this.customerId,
    required this.customerName,
    required this.nfcConfirmRequired,
    required this.nfcPaymentEnabled,
  });

  factory NfcCustomerSettings.fromJson(Map<String, dynamic> json) {
    return NfcCustomerSettings(
      customerId: NfcCardBalance._parseInt(json['customer_id']),
      customerName: json['customer_name']?.toString() ?? '',
      nfcConfirmRequired: NfcCardBalance._parseBool(json['nfc_confirm_required']),
      nfcPaymentEnabled: NfcCardBalance._parseBool(json['nfc_payment_enabled']),
    );
  }
}

/// Deposit/Payment result
class NfcTransactionResult {
  final int transactionId;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;

  NfcTransactionResult({
    required this.transactionId,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
  });

  factory NfcTransactionResult.fromJson(Map<String, dynamic> json) {
    return NfcTransactionResult(
      transactionId: NfcCardBalance._parseInt(json['transaction_id']),
      amount: NfcCardBalance._parseDouble(json['amount']),
      balanceBefore: NfcCardBalance._parseDouble(json['balance_before']),
      balanceAfter: NfcCardBalance._parseDouble(json['balance_after']),
    );
  }
}

/// Confirmation result
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
      confirmationId: NfcCardBalance._parseInt(json['confirmation_id']),
      customerId: NfcCardBalance._parseInt(json['customer_id']),
      customerName: json['customer_name']?.toString() ?? '',
      amount: NfcCardBalance._parseDouble(json['amount']),
    );
  }
}

/// Insufficient balance error
class InsufficientBalanceError {
  final double required;
  final double available;
  final double shortage;

  InsufficientBalanceError({
    required this.required,
    required this.available,
    required this.shortage,
  });

  factory InsufficientBalanceError.fromJson(Map<String, dynamic> json) {
    return InsufficientBalanceError(
      required: NfcCardBalance._parseDouble(json['required']),
      available: NfcCardBalance._parseDouble(json['available']),
      shortage: NfcCardBalance._parseDouble(json['shortage']),
    );
  }
}
