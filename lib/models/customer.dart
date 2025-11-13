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
    this.supervisor,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      personId: json['person_id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      address1: json['address_1'] as String? ?? '',
      address2: json['address_2'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      zip: json['zip'] as String? ?? '',
      country: json['country'] as String? ?? '',
      comments: json['comments'] as String? ?? '',
      gender: json['gender'] as int? ?? 0,
      accountNumber: json['account_number'] as String?,
      companyName: json['company_name'] as String?,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      discountType: json['discount_type'] as String? ?? '0',
      taxable: json['taxable'] as bool? ?? false,
      taxId: json['tax_id'] as String? ?? '',
      consent: json['consent'] as bool? ?? false,
      isBodaBoda: json['is_boda_boda'] as bool? ?? false,
      oneTimeCredit: json['one_time_credit'] as bool? ?? false,
      isAllowedCredit: json['is_allowed_credit'] as bool? ?? false,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      oneTimeCreditLimit: (json['one_time_credit_limit'] as num?)?.toDouble() ?? 0.0,
      dueDate: json['due_date'] as int? ?? 7,
      badDebtor: json['bad_debtor'] as int? ?? 30,
      dormant: json['dormant'] as String? ?? 'ACTIVE',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
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
