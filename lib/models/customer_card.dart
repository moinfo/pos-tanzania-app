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
  });

  factory CustomerCard.fromJson(Map<String, dynamic> json) {
    // Helper to parse int from string or int
    int? parseId(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
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
    );
  }

  @override
  String toString() {
    return 'CustomerCard(id: $id, customerId: $customerId, cardUid: $cardUid, customerName: $customerName)';
  }
}
