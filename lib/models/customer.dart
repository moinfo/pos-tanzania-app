import 'supervisor.dart';

/// Customer model representing a customer in the system
class Customer {
  final int personId;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String zip;
  final String country;
  final String comments;
  final int gender;
  final String? accountNumber;
  final String? companyName;
  final double discount;
  final String discountType;
  final bool taxable;
  final String taxId;
  final bool consent;
  final bool isBodaBoda;
  final bool oneTimeCredit;
  final bool isAllowedCredit;
  final double creditLimit;
  final double oneTimeCreditLimit;
  final int dueDate;
  final int badDebtor;
  final String dormant;
  final double balance;
  final int? days; // Days since last sale (Leruma feature)
  final Supervisor? supervisor;

  Customer({
    required this.personId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.address1,
    required this.address2,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
    required this.comments,
    required this.gender,
    this.accountNumber,
    this.companyName,
    required this.discount,
    required this.discountType,
    required this.taxable,
    required this.taxId,
    required this.consent,
    required this.isBodaBoda,
    required this.oneTimeCredit,
    required this.isAllowedCredit,
    required this.creditLimit,
    required this.oneTimeCreditLimit,
    required this.dueDate,
    required this.badDebtor,
    required this.dormant,
    required this.balance,
    this.days,
    this.supervisor,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    // Helper to parse int from string or int
    int parseIntValue(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    // Helper to parse double from string or num
    double parseDoubleValue(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    // Helper to parse bool from various formats
    bool parseBoolValue(dynamic value, [bool defaultValue = false]) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value == '1' || value.toLowerCase() == 'true' || value.toLowerCase() == 'active';
      return defaultValue;
    }

    return Customer(
      personId: parseIntValue(json['person_id']),
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      address1: json['address_1']?.toString() ?? '',
      address2: json['address_2']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      zip: json['zip']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      comments: json['comments']?.toString() ?? '',
      gender: parseIntValue(json['gender']),
      accountNumber: json['account_number']?.toString(),
      companyName: json['company_name']?.toString(),
      discount: parseDoubleValue(json['discount']),
      discountType: json['discount_type']?.toString() ?? '0',
      taxable: parseBoolValue(json['taxable']),
      taxId: json['tax_id']?.toString() ?? '',
      consent: parseBoolValue(json['consent']),
      isBodaBoda: parseBoolValue(json['is_boda_boda']),
      oneTimeCredit: parseBoolValue(json['one_time_credit']),
      isAllowedCredit: parseBoolValue(json['is_allowed_credit']),
      creditLimit: parseDoubleValue(json['credit_limit']),
      oneTimeCreditLimit: parseDoubleValue(json['one_time_credit_limit']),
      dueDate: parseIntValue(json['due_date'], 7),
      badDebtor: parseIntValue(json['bad_debtor'], 30),
      dormant: json['dormant']?.toString() ?? 'ACTIVE',
      balance: parseDoubleValue(json['balance']),
      days: json['days'] != null ? parseIntValue(json['days']) : null,
      supervisor: json['supervisor'] != null
          ? Supervisor.fromJson(json['supervisor'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'person_id': personId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone_number': phoneNumber,
      'address_1': address1,
      'address_2': address2,
      'city': city,
      'state': state,
      'zip': zip,
      'country': country,
      'comments': comments,
      'gender': gender,
      'account_number': accountNumber,
      'company_name': companyName,
      'discount': discount,
      'discount_type': discountType,
      'taxable': taxable,
      'tax_id': taxId,
      'consent': consent,
      'is_boda_boda': isBodaBoda,
      'one_time_credit': oneTimeCredit,
      'is_allowed_credit': isAllowedCredit,
      'credit_limit': creditLimit,
      'one_time_credit_limit': oneTimeCreditLimit,
      'due_date': dueDate,
      'bad_debtor': badDebtor,
      'dormant': dormant,
      'balance': balance,
      if (supervisor != null) 'supervisor': supervisor!.toJson(),
    };
  }

  String get fullName => '$firstName $lastName';
  String get displayName => companyName?.isNotEmpty == true ? companyName! : fullName;
}

/// Form data for creating or updating a customer
class CustomerFormData {
  final String firstName;
  final String lastName;
  final String? email;
  final String? phoneNumber;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? zip;
  final String? country;
  final String? comments;
  final int? gender;
  final String? accountNumber;
  final String? companyName;
  final double? discount;
  final int? discountType;
  final bool? taxable;
  final String? taxId;
  final bool? consent;
  final bool? isBodaBoda;
  final bool? oneTimeCredit;
  final bool? isAllowedCredit;
  final double? creditLimit;
  final double? oneTimeCreditLimit;
  final int? dueDate;
  final int? badDebtor;
  final String? supervisorId;

  CustomerFormData({
    required this.firstName,
    required this.lastName,
    this.email,
    this.phoneNumber,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.zip,
    this.country,
    this.comments,
    this.gender,
    this.accountNumber,
    this.companyName,
    this.discount,
    this.discountType,
    this.taxable,
    this.taxId,
    this.consent,
    this.isBodaBoda,
    this.oneTimeCredit,
    this.isAllowedCredit,
    this.creditLimit,
    this.oneTimeCreditLimit,
    this.dueDate,
    this.badDebtor,
    this.supervisorId,
  });

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      if (email != null) 'email': email,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (address1 != null) 'address_1': address1,
      if (address2 != null) 'address_2': address2,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (zip != null) 'zip': zip,
      if (country != null) 'country': country,
      if (comments != null) 'comments': comments,
      if (gender != null) 'gender': gender,
      if (accountNumber != null) 'account_number': accountNumber,
      if (companyName != null) 'company_name': companyName,
      if (discount != null) 'discount': discount,
      if (discountType != null) 'discount_type': discountType,
      if (taxable != null) 'taxable': taxable,
      if (taxId != null) 'tax_id': taxId,
      if (consent != null) 'consent': consent,
      if (isBodaBoda != null) 'is_boda_boda': isBodaBoda,
      if (oneTimeCredit != null) 'one_time_credit': oneTimeCredit,
      if (isAllowedCredit != null) 'is_allowed_credit': isAllowedCredit,
      if (creditLimit != null) 'credit_limit': creditLimit,
      if (oneTimeCreditLimit != null) 'one_time_credit_limit': oneTimeCreditLimit,
      if (dueDate != null) 'due_date': dueDate,
      if (badDebtor != null) 'bad_debtor': badDebtor,
      if (supervisorId != null) 'supervisor_id': int.tryParse(supervisorId!),
    };
  }
}
