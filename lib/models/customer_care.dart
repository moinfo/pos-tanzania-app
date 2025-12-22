/// Model for customer care data (CRM view)
class CustomerCareItem {
  final int personId;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? phoneNumber;
  final String? address1;
  final String? address2;
  final double creditLimit;
  final double balance;
  final int? daysSinceLastSale;

  CustomerCareItem({
    required this.personId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.phoneNumber,
    this.address1,
    this.address2,
    required this.creditLimit,
    required this.balance,
    this.daysSinceLastSale,
  });

  factory CustomerCareItem.fromJson(Map<String, dynamic> json) {
    return CustomerCareItem(
      personId: json['person_id'] is int ? json['person_id'] : int.tryParse(json['person_id'].toString()) ?? 0,
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString(),
      address1: json['address_1']?.toString(),
      address2: json['address_2']?.toString(),
      creditLimit: _parseDouble(json['credit_limit']),
      balance: _parseDouble(json['balance']),
      daysSinceLastSale: json['days_since_last_sale'] != null
          ? (json['days_since_last_sale'] is int
              ? json['days_since_last_sale']
              : int.tryParse(json['days_since_last_sale'].toString()))
          : null,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  /// Returns status color based on days since last sale
  /// Green: <= 7 days (active)
  /// Yellow: 8-14 days (needs attention)
  /// Orange: 15-30 days (at risk)
  /// Red: > 30 days (inactive)
  String get activityStatus {
    if (daysSinceLastSale == null) return 'new';
    if (daysSinceLastSale! <= 7) return 'active';
    if (daysSinceLastSale! <= 14) return 'attention';
    if (daysSinceLastSale! <= 30) return 'at_risk';
    return 'inactive';
  }
}

/// Customer care totals
class CustomerCareTotals {
  final double creditLimit;
  final double balance;
  final int customerCount;

  CustomerCareTotals({
    required this.creditLimit,
    required this.balance,
    required this.customerCount,
  });

  factory CustomerCareTotals.fromJson(Map<String, dynamic> json) {
    return CustomerCareTotals(
      creditLimit: _parseDouble(json['credit_limit']),
      balance: _parseDouble(json['balance']),
      customerCount: json['customer_count'] is int
          ? json['customer_count']
          : int.tryParse(json['customer_count'].toString()) ?? 0,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

/// Customer care response
class CustomerCareResponse {
  final List<CustomerCareItem> customers;
  final CustomerCareTotals totals;

  CustomerCareResponse({
    required this.customers,
    required this.totals,
  });

  factory CustomerCareResponse.fromJson(Map<String, dynamic> json) {
    return CustomerCareResponse(
      customers: (json['customers'] as List<dynamic>?)
          ?.map((c) => CustomerCareItem.fromJson(c as Map<String, dynamic>))
          .toList() ?? [],
      totals: CustomerCareTotals.fromJson(json['totals'] as Map<String, dynamic>? ?? {}),
    );
  }
}