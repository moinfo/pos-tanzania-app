class Expense {
  final int expenseId;
  final String date;
  final double amount;
  final double taxAmount;
  final String paymentType;
  final String description;
  final String? supplierTaxCode;
  final ExpenseCategory? category;
  final ExpenseSupervisor? supervisor;
  final ExpenseLocation? location;
  final ExpenseEmployee? employee;
  final String? supplierName;

  Expense({
    required this.expenseId,
    required this.date,
    required this.amount,
    required this.taxAmount,
    required this.paymentType,
    required this.description,
    this.supplierTaxCode,
    this.category,
    this.supervisor,
    this.location,
    this.employee,
    this.supplierName,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      expenseId: json['expense_id'] as int,
      date: json['date'] as String,
      amount: (json['amount'] as num).toDouble(),
      taxAmount: json['tax_amount'] != null ? (json['tax_amount'] as num).toDouble() : 0.0,
      paymentType: json['payment_type'] as String,
      description: json['description'] as String? ?? '',
      supplierTaxCode: json['supplier_tax_code'] as String?,
      category: json['category'] != null && json['category']['id'] != null
          ? ExpenseCategory.fromJson(json['category'])
          : null,
      supervisor: json['supervisor'] != null && json['supervisor']['id'] != null
          ? ExpenseSupervisor.fromJson(json['supervisor'])
          : null,
      location: json['location'] != null && json['location']['id'] != null
          ? ExpenseLocation.fromJson(json['location'])
          : null,
      employee: json['employee'] != null &&
                (json['employee']['first_name'] != null || json['employee']['last_name'] != null)
          ? ExpenseEmployee.fromJson(json['employee'])
          : null,
      supplierName: json['supplier_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expense_id': expenseId,
      'date': date,
      'amount': amount,
      'tax_amount': taxAmount,
      'payment_type': paymentType,
      'description': description,
      'supplier_tax_code': supplierTaxCode,
      'category': category?.toJson(),
      'supervisor': supervisor?.toJson(),
      'location': location?.toJson(),
      'employee': employee?.toJson(),
      'supplier_name': supplierName,
    };
  }

  double get totalAmount => amount + taxAmount;
}

class ExpenseCategory {
  final int id;
  final String name;
  final String? description;

  ExpenseCategory({
    required this.id,
    required this.name,
    this.description,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }
}

class ExpenseSupervisor {
  final int id;
  final String name;

  ExpenseSupervisor({
    required this.id,
    required this.name,
  });

  factory ExpenseSupervisor.fromJson(Map<String, dynamic> json) {
    return ExpenseSupervisor(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class ExpenseLocation {
  final int id;
  final String name;

  ExpenseLocation({
    required this.id,
    required this.name,
  });

  factory ExpenseLocation.fromJson(Map<String, dynamic> json) {
    return ExpenseLocation(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class ExpenseEmployee {
  final String? firstName;
  final String? lastName;

  ExpenseEmployee({
    this.firstName,
    this.lastName,
  });

  factory ExpenseEmployee.fromJson(Map<String, dynamic> json) {
    return ExpenseEmployee(
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
    };
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return '';
  }
}

// For creating/updating expenses
class ExpenseFormData {
  final String date;
  final double amount;
  final String paymentType;
  final String description;
  final int? categoryId;
  final int? supervisorId;
  final double taxAmount;
  final String? supplierTaxCode;
  final int? employeeId;
  final int? stockLocationId;

  ExpenseFormData({
    required this.date,
    required this.amount,
    required this.paymentType,
    this.description = '',
    this.categoryId,
    this.supervisorId,
    this.taxAmount = 0,
    this.supplierTaxCode,
    this.employeeId,
    this.stockLocationId,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'amount': amount,
      'payment_type': paymentType,
      'description': description,
      if (categoryId != null) 'category_id': categoryId,
      if (supervisorId != null) 'supervisor_id': supervisorId,
      'tax_amount': taxAmount,
      if (supplierTaxCode != null && supplierTaxCode!.isNotEmpty)
        'supplier_tax_code': supplierTaxCode,
      if (employeeId != null) 'employee_id': employeeId,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
    };
  }
}
