class Contract {
  final int id;
  final String name;
  final String phone;
  final String date;
  final String endDate;
  final String contractDescription;
  final int contractTime;
  final double contractCost;
  final double returnAmount;
  final double contractAmount;
  final String guarantor1;
  final String guarantor2;
  final String phoneGuarantor1;
  final String phoneGuarantor2;
  final double payments;
  final double services;
  final double balance;
  final double profit;
  final int days;
  final int weeks;
  final double daysPaid;
  final double daysUnpaid;
  final double currentUnpaid;

  Contract({
    required this.id,
    required this.name,
    required this.phone,
    required this.date,
    required this.endDate,
    required this.contractDescription,
    required this.contractTime,
    required this.contractCost,
    required this.returnAmount,
    required this.contractAmount,
    required this.guarantor1,
    required this.guarantor2,
    required this.phoneGuarantor1,
    required this.phoneGuarantor2,
    required this.payments,
    required this.services,
    required this.balance,
    required this.profit,
    required this.days,
    required this.weeks,
    required this.daysPaid,
    required this.daysUnpaid,
    required this.currentUnpaid,
  });

  factory Contract.fromJson(Map<String, dynamic> json) {
    return Contract(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String? ?? '',
      date: json['date'] as String,
      endDate: json['end_date'] as String,
      contractDescription: json['contract_description'] as String? ?? '',
      contractTime: json['contract_time'] as int,
      contractCost: (json['contract_cost'] as num).toDouble(),
      returnAmount: (json['return_amount'] as num).toDouble(),
      contractAmount: (json['contract_amount'] as num).toDouble(),
      guarantor1: json['guarantor1'] as String? ?? '',
      guarantor2: json['guarantor2'] as String? ?? '',
      phoneGuarantor1: json['phone_guarantor1'] as String? ?? '',
      phoneGuarantor2: json['phone_guarantor2'] as String? ?? '',
      payments: (json['payments'] as num).toDouble(),
      services: (json['services'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
      days: json['days'] as int,
      weeks: json['weeks'] as int,
      daysPaid: (json['days_paid'] as num).toDouble(),
      daysUnpaid: (json['days_unpaid'] as num).toDouble(),
      currentUnpaid: (json['current_unpaid'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'date': date,
      'end_date': endDate,
      'contract_description': contractDescription,
      'contract_time': contractTime,
      'contract_cost': contractCost,
      'return_amount': returnAmount,
      'contract_amount': contractAmount,
      'guarantor1': guarantor1,
      'guarantor2': guarantor2,
      'phone_guarantor1': phoneGuarantor1,
      'phone_guarantor2': phoneGuarantor2,
      'payments': payments,
      'services': services,
      'balance': balance,
      'profit': profit,
      'days': days,
      'weeks': weeks,
      'days_paid': daysPaid,
      'days_unpaid': daysUnpaid,
      'current_unpaid': currentUnpaid,
    };
  }
}

class StatementEntry {
  final int id;
  final String date;
  final String description;
  final double credit;
  final double debit;
  final double balance;
  final String type; // 'opening', 'transaction', 'closing'

  StatementEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.credit,
    required this.debit,
    required this.balance,
    required this.type,
  });

  factory StatementEntry.fromJson(Map<String, dynamic> json) {
    return StatementEntry(
      id: json['id'] as int,
      date: json['date'] as String,
      description: json['description'] as String,
      credit: (json['credit'] as num).toDouble(),
      debit: (json['debit'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'description': description,
      'credit': credit,
      'debit': debit,
      'balance': balance,
      'type': type,
    };
  }
}

class ContractStatement {
  final Contract contract;
  final List<StatementEntry> statement;
  final String startDate;
  final String endDate;

  ContractStatement({
    required this.contract,
    required this.statement,
    required this.startDate,
    required this.endDate,
  });
}
