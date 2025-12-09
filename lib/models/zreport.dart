// Z Report model for EFD (Electronic Fiscal Device) compliance

class ZReportListItem {
  final int id;
  final double turnover;
  final double net;
  final double tax;
  final double turnoverExSr;
  final double total;
  final double totalCharges;
  final String date;
  final int? stockLocationId;
  final String? locationName;
  final String? picFile;

  ZReportListItem({
    required this.id,
    required this.turnover,
    required this.net,
    required this.tax,
    required this.turnoverExSr,
    required this.total,
    required this.totalCharges,
    required this.date,
    this.stockLocationId,
    this.locationName,
    this.picFile,
  });

  factory ZReportListItem.fromJson(Map<String, dynamic> json) {
    return ZReportListItem(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      turnover: _parseDouble(json['turnover']),
      net: _parseDouble(json['net']),
      tax: _parseDouble(json['tax']),
      turnoverExSr: _parseDouble(json['turnover_ex_sr']),
      total: _parseDouble(json['total']),
      totalCharges: _parseDouble(json['total_charges']),
      date: json['date']?.toString() ?? '',
      stockLocationId: json['stock_location_id'] != null
          ? (json['stock_location_id'] is String
              ? int.parse(json['stock_location_id'])
              : json['stock_location_id'] as int)
          : null,
      locationName: json['location_name']?.toString(),
      picFile: json['pic_file']?.toString(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'turnover': turnover,
      'net': net,
      'tax': tax,
      'turnover_ex_sr': turnoverExSr,
      'total': total,
      'total_charges': totalCharges,
      'date': date,
      'stock_location_id': stockLocationId,
      'location_name': locationName,
      'pic_file': picFile,
    };
  }
}

class ZReportDetails {
  final int id;
  final double turnover;
  final double net;
  final double tax;
  final double turnoverExSr;
  final double total;
  final double totalCharges;
  final String date;
  final int? stockLocationId;
  final String? locationName;
  final String? picFile;

  ZReportDetails({
    required this.id,
    required this.turnover,
    required this.net,
    required this.tax,
    required this.turnoverExSr,
    required this.total,
    required this.totalCharges,
    required this.date,
    this.stockLocationId,
    this.locationName,
    this.picFile,
  });

  factory ZReportDetails.fromJson(Map<String, dynamic> json) {
    return ZReportDetails(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      turnover: ZReportListItem._parseDouble(json['turnover']),
      net: ZReportListItem._parseDouble(json['net']),
      tax: ZReportListItem._parseDouble(json['tax']),
      turnoverExSr: ZReportListItem._parseDouble(json['turnover_ex_sr']),
      total: ZReportListItem._parseDouble(json['total']),
      totalCharges: ZReportListItem._parseDouble(json['total_charges']),
      date: json['date']?.toString() ?? '',
      stockLocationId: json['stock_location_id'] != null
          ? (json['stock_location_id'] is String
              ? int.parse(json['stock_location_id'])
              : json['stock_location_id'] as int)
          : null,
      locationName: json['location_name']?.toString(),
      picFile: json['pic_file']?.toString(),
    );
  }
}

class ZReportCreate {
  final double turnover;
  final double net;
  final double tax;
  final double turnoverExSr;
  final double total;
  final double totalCharges;
  final String date;
  final int? stockLocationId;
  final String? picFile; // Base64 encoded file

  ZReportCreate({
    required this.turnover,
    required this.net,
    required this.tax,
    required this.turnoverExSr,
    required this.total,
    required this.totalCharges,
    required this.date,
    this.stockLocationId,
    this.picFile,
  });

  Map<String, dynamic> toJson() {
    return {
      'turnover': turnover,
      'net': net,
      'tax': tax,
      'turnover_ex_sr': turnoverExSr,
      'total': total,
      'total_charges': totalCharges,
      'date': date,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      if (picFile != null) 'pic_file': picFile,
    };
  }
}
