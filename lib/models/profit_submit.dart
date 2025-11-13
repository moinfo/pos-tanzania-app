// Profit Submit model for profit submissions

class ProfitSubmitListItem {
  final int id;
  final double amount;
  final String date;
  final int supervisorId;
  final String supervisorName;
  final int? stockLocationId;
  final String? locationName;
  final String? createdAt;
  final String? picFile; // File path or URL for the attached profit slip

  ProfitSubmitListItem({
    required this.id,
    required this.amount,
    required this.date,
    required this.supervisorId,
    required this.supervisorName,
    this.stockLocationId,
    this.locationName,
    this.createdAt,
    this.picFile,
  });

  factory ProfitSubmitListItem.fromJson(Map<String, dynamic> json) {
    return ProfitSubmitListItem(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      amount: (json['amount'] is String)
          ? double.parse(json['amount'])
          : (json['amount'] is int)
              ? (json['amount'] as int).toDouble()
              : json['amount'] as double,
      date: json['date']?.toString() ?? '',
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
      createdAt: json['created_at']?.toString(),
      picFile: json['pic_file']?.toString(),
    );
  }
}

class ProfitSubmitDetails {
  final int id;
  final double amount;
  final String date;
  final int supervisorId;
  final String supervisorName;
  final int? stockLocationId;
  final String? createdAt;

  ProfitSubmitDetails({
    required this.id,
    required this.amount,
    required this.date,
    required this.supervisorId,
    required this.supervisorName,
    this.stockLocationId,
    this.createdAt,
  });

  factory ProfitSubmitDetails.fromJson(Map<String, dynamic> json) {
    return ProfitSubmitDetails(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      amount: (json['amount'] is String)
          ? double.parse(json['amount'])
          : (json['amount'] is int)
              ? (json['amount'] as int).toDouble()
              : json['amount'] as double,
      date: json['date']?.toString() ?? '',
      supervisorId: json['supervisor_id'] is String
          ? int.parse(json['supervisor_id'])
          : json['supervisor_id'] as int,
      supervisorName: json['supervisor_name']?.toString() ?? '',
      stockLocationId: json['stock_location_id'] != null
          ? (json['stock_location_id'] is String
              ? int.parse(json['stock_location_id'])
              : json['stock_location_id'] as int)
          : null,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ProfitSubmitCreate {
  final double amount;
  final String date;
  final int supervisorId;
  final int? stockLocationId;
  final String? picFile; // Base64 encoded file or file path

  ProfitSubmitCreate({
    required this.amount,
    required this.date,
    required this.supervisorId,
    this.stockLocationId,
    this.picFile,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'date': date,
      'supervisor_id': supervisorId,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      if (picFile != null) 'pic_file': picFile,
    };
  }
}
