/// Model representing an NFC card linked to a customer
class CustomerCard {
  final int? id;
  final int customerId;
  final String cardUid;
  final String cardType;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Customer info (populated when fetching)
  final String? customerName;
  final String? customerPhone;
  final String? companyName;

  // Wallet balance fields
  final double balance;
  final double totalDeposited;
  final double totalSpent;
  final bool nfcConfirmRequired;
  final bool nfcPaymentEnabled;

  CustomerCard({
    this.id,
    required this.customerId,
    required this.cardUid,
    this.cardType = 'nfc',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.customerName,
    this.customerPhone,
    this.companyName,
    this.balance = 0.0,
    this.totalDeposited = 0.0,
    this.totalSpent = 0.0,
    this.nfcConfirmRequired = false,
    this.nfcPaymentEnabled = false,
  });

  factory CustomerCard.fromJson(Map<String, dynamic> json) {
    // Helper to parse int from string or int
    int? parseId(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Helper to parse double from string or number
    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    // Helper to parse bool from various types
    bool parseBool(dynamic value, [bool defaultValue = false]) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value == '1' || value.toLowerCase() == 'true';
      return defaultValue;
    }

    return CustomerCard(
      id: parseId(json['id'] ?? json['card_id']),
      customerId: parseId(json['customer_id'] ?? json['person_id']) ?? 0,
      cardUid: json['card_uid']?.toString() ?? '',
      cardType: json['card_type']?.toString() ?? 'nfc',
      isActive: json['is_active'] == 1 || json['is_active'] == true || json['is_active'] == '1',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      customerName: json['customer_name']?.toString() ??
          '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
      customerPhone: json['phone_number']?.toString(),
      companyName: json['company_name']?.toString(),
      balance: parseDouble(json['balance']),
      totalDeposited: parseDouble(json['total_deposited']),
      totalSpent: parseDouble(json['total_spent']),
      nfcConfirmRequired: parseBool(json['nfc_confirm_required']),
      nfcPaymentEnabled: parseBool(json['nfc_payment_enabled']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'card_uid': cardUid,
      'card_type': cardType,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'customer_id': customerId,
      'card_uid': cardUid,
      'card_type': cardType,
    };
  }

  CustomerCard copyWith({
    int? id,
    int? customerId,
    String? cardUid,
    String? cardType,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
    String? customerPhone,
    String? companyName,
    double? balance,
    double? totalDeposited,
    double? totalSpent,
    bool? nfcConfirmRequired,
    bool? nfcPaymentEnabled,
  }) {
    return CustomerCard(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      cardUid: cardUid ?? this.cardUid,
      cardType: cardType ?? this.cardType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      companyName: companyName ?? this.companyName,
      balance: balance ?? this.balance,
      totalDeposited: totalDeposited ?? this.totalDeposited,
      totalSpent: totalSpent ?? this.totalSpent,
      nfcConfirmRequired: nfcConfirmRequired ?? this.nfcConfirmRequired,
      nfcPaymentEnabled: nfcPaymentEnabled ?? this.nfcPaymentEnabled,
    );
  }

  @override
  String toString() {
    return 'CustomerCard(id: $id, customerId: $customerId, cardUid: $cardUid, customerName: $customerName)';
  }
}
