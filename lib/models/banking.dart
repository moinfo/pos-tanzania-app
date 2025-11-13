// Banking model for bank deposits

class BankingListItem {
  final int id;
  final double amount;
  final String date;
  final String bankName;
  final String depositor;
  final int supervisorId;
  final String supervisorName;
  final int? stockLocationId;
  final String? locationName;
  final String? picFile; // File path or URL for the attached banking slip
  final String? createdAt;

  BankingListItem({
    required this.id,
    required this.amount,
    required this.date,
    required this.bankName,
    required this.depositor,
    required this.supervisorId,
    required this.supervisorName,
    this.stockLocationId,
    this.locationName,
    this.picFile,
    this.createdAt,
  });

  factory BankingListItem.fromJson(Map<String, dynamic> json) {
    return BankingListItem(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      amount: (json['amount'] is String)
          ? double.parse(json['amount'])
          : (json['amount'] is int)
              ? (json['amount'] as int).toDouble()
              : json['amount'] as double,
      date: json['date']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      depositor: json['depositor']?.toString() ?? '',
      supervisorId: json['supervisor_id'] is String
          ? int.parse(json['supervisor_id'])
          : json['supervisor_id'] as int,
      supervisorName: json['supervisor_name']?.toString() ?? '',
      stockLocationId: json['stock_location_id'] != null
          ? (json['stock_location_id'] is String
              ? int.parse(json['stock_location_id'])
              : json['stock_location_id'] as int)
          : null,
      locationName: json['location_name']?.toString(),
      picFile: json['pic_file']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class BankingCreate {
  final double amount;
  final String date;
  final String bankName;
  final String depositor;
  final int supervisorId;
  final int? stockLocationId;
  final String? picFile; // Base64 encoded file or file path

  BankingCreate({
    required this.amount,
    required this.date,
    required this.bankName,
    required this.depositor,
    required this.supervisorId,
    this.stockLocationId,
    this.picFile,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'date': date,
      'bank_name': bankName,
      'depositor': depositor,
      'supervisor_id': supervisorId,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      if (picFile != null) 'pic_file': picFile,
    };
  }
}

// Tanzania bank names (predefined)
class TanzaniaBanks {
  static const List<String> banks = [
    'CRDB',
    'NMB',
    'NBC',
    'Others',
  ];
}
