/// Model for map route data (delivery route planning)
class MapRouteCustomer {
  final int personId;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? phoneNumber;
  final String? address1;
  final String? address2;
  final int sortOrder;
  final int? daysSinceLastSale;

  MapRouteCustomer({
    required this.personId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.phoneNumber,
    this.address1,
    this.address2,
    required this.sortOrder,
    this.daysSinceLastSale,
  });

  factory MapRouteCustomer.fromJson(Map<String, dynamic> json) {
    return MapRouteCustomer(
      personId: json['person_id'] is int
          ? json['person_id']
          : int.tryParse(json['person_id'].toString()) ?? 0,
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString(),
      address1: json['address_1']?.toString(),
      address2: json['address_2']?.toString(),
      sortOrder: json['sort_order'] is int
          ? json['sort_order']
          : int.tryParse(json['sort_order'].toString()) ?? 0,
      daysSinceLastSale: json['days_since_last_sale'] != null
          ? (json['days_since_last_sale'] is int
              ? json['days_since_last_sale']
              : int.tryParse(json['days_since_last_sale'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'person_id': personId,
      'sort_order': sortOrder,
    };
  }
}

/// Map route response
class MapRouteResponse {
  final List<MapRouteCustomer> customers;
  final int customerCount;

  MapRouteResponse({
    required this.customers,
    required this.customerCount,
  });

  factory MapRouteResponse.fromJson(Map<String, dynamic> json) {
    return MapRouteResponse(
      customers: (json['customers'] as List<dynamic>?)
              ?.map((c) => MapRouteCustomer.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      customerCount: json['customer_count'] is int
          ? json['customer_count']
          : int.tryParse(json['customer_count'].toString()) ?? 0,
    );
  }
}