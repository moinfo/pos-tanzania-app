class Supplier {
  final int supplierId;
  final String companyName;
  final String firstName;
  final String lastName;
  final String displayName;
  final String? gender;
  final String? email;
  final String? phoneNumber;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? zip;
  final String? country;
  final String? comments;
  final String? agencyName;
  final String? accountNumber;
  final String? taxId;
  final int category;
  final int? supervisorId;
  final double credit;
  final double debit;
  final double balance;

  Supplier({
    required this.supplierId,
    required this.companyName,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    this.gender,
    this.email,
    this.phoneNumber,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.zip,
    this.country,
    this.comments,
    this.agencyName,
    this.accountNumber,
    this.taxId,
    this.category = 0,
    this.supervisorId,
    required this.credit,
    required this.debit,
    required this.balance,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      supplierId: json['supplier_id'] ?? 0,
      companyName: json['company_name'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      displayName: json['display_name'] ?? '',
      gender: json['gender'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      address1: json['address_1'],
      address2: json['address_2'],
      city: json['city'],
      state: json['state'],
      zip: json['zip'],
      country: json['country'],
      comments: json['comments'],
      agencyName: json['agency_name'],
      accountNumber: json['account_number'],
      taxId: json['tax_id'],
      category: json['category'] ?? 0,
      supervisorId: json['supervisor_id'],
      credit: (json['credit'] ?? 0).toDouble(),
      debit: (json['debit'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supplier_id': supplierId,
      'company_name': companyName,
      'first_name': firstName,
      'last_name': lastName,
      'display_name': displayName,
      'gender': gender,
      'email': email,
      'phone_number': phoneNumber,
      'address_1': address1,
      'address_2': address2,
      'city': city,
      'state': state,
      'zip': zip,
      'country': country,
      'comments': comments,
      'agency_name': agencyName,
      'account_number': accountNumber,
      'tax_id': taxId,
      'category': category,
      'supervisor_id': supervisorId,
      'credit': credit,
      'debit': debit,
      'balance': balance,
    };
  }
}

class SupplierTransaction {
  final int? paymentId;
  final String date;
  final double credit;
  final double debit;
  final int? receivingId;
  final String? description;
  final double balance;

  SupplierTransaction({
    this.paymentId,
    required this.date,
    required this.credit,
    required this.debit,
    this.receivingId,
    this.description,
    required this.balance,
  });

  factory SupplierTransaction.fromJson(Map<String, dynamic> json) {
    // Handle payment_id which can be a string or int from API
    int? parsedPaymentId;
    if (json['payment_id'] != null) {
      if (json['payment_id'] is int) {
        parsedPaymentId = json['payment_id'];
      } else if (json['payment_id'] is String) {
        parsedPaymentId = int.tryParse(json['payment_id']);
      }
    }

    // Handle receiving_id which can be a string or int from API
    int? parsedReceivingId;
    if (json['receiving_id'] != null) {
      if (json['receiving_id'] is int) {
        parsedReceivingId = json['receiving_id'];
      } else if (json['receiving_id'] is String) {
        parsedReceivingId = int.tryParse(json['receiving_id']);
      }
    }

    return SupplierTransaction(
      paymentId: parsedPaymentId,
      date: json['date'] ?? '',
      credit: (json['credit'] ?? 0).toDouble(),
      debit: (json['debit'] ?? 0).toDouble(),
      receivingId: parsedReceivingId,
      description: json['description'],
      balance: (json['balance'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_id': paymentId,
      'date': date,
      'credit': credit,
      'debit': debit,
      'receiving_id': receivingId,
      'description': description,
      'balance': balance,
    };
  }
}

class SupplierStatement {
  final int supplierId;
  final String supplierName;
  final String startDate;
  final String endDate;
  final double openingBalance;
  final double closingBalance;
  final double currentBalance;
  final List<SupplierTransaction> transactions;

  SupplierStatement({
    required this.supplierId,
    required this.supplierName,
    required this.startDate,
    required this.endDate,
    required this.openingBalance,
    required this.closingBalance,
    required this.currentBalance,
    required this.transactions,
  });

  factory SupplierStatement.fromJson(Map<String, dynamic> json) {
    var transactionsJson = json['transactions'] as List? ?? [];
    List<SupplierTransaction> transactionsList = transactionsJson
        .map((t) => SupplierTransaction.fromJson(t))
        .toList();

    return SupplierStatement(
      supplierId: json['supplier_id'] ?? 0,
      supplierName: json['supplier_name'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      openingBalance: (json['opening_balance'] ?? 0).toDouble(),
      closingBalance: (json['closing_balance'] ?? 0).toDouble(),
      currentBalance: (json['current_balance'] ?? 0).toDouble(),
      transactions: transactionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'start_date': startDate,
      'end_date': endDate,
      'opening_balance': openingBalance,
      'closing_balance': closingBalance,
      'current_balance': currentBalance,
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
  }
}

class SupplierPaymentFormData {
  final int supplierId;
  final double amount;
  final int? receivingId;
  final int? stockLocationId;
  final int? paymentMode;
  final int? paidPaymentType;
  final String? description;
  final String? date;

  SupplierPaymentFormData({
    required this.supplierId,
    required this.amount,
    this.receivingId,
    this.stockLocationId,
    this.paymentMode,
    this.paidPaymentType,
    this.description,
    this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'supplier_id': supplierId,
      'amount': amount,
      'receiving_id': receivingId,
      'stock_location_id': stockLocationId,
      'payment_mode': paymentMode,
      'paid_payment_type': paidPaymentType,
      'description': description,
      'date': date,
    };
  }
}
