// Z Report model for EFD (Electronic Fiscal Device) compliance

class ZReportListItem {
  final int id;
  final String a;
  final String c;
  final String date;
  final int? stockLocationId;
  final String? locationName;
  final String? picFile;

  ZReportListItem({
    required this.id,
    required this.a,
    required this.c,
    required this.date,
    this.stockLocationId,
    this.locationName,
    this.picFile,
  });

  factory ZReportListItem.fromJson(Map<String, dynamic> json) {
    return ZReportListItem(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      a: json['a']?.toString() ?? '',
      c: json['c']?.toString() ?? '',
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'a': a,
      'c': c,
      'date': date,
      'stock_location_id': stockLocationId,
      'location_name': locationName,
      'pic_file': picFile,
    };
  }
}

class ZReportDetails {
  final int id;
  final String a;
  final String c;
  final String date;
  final int? stockLocationId;
  final String? locationName;
  final String? picFile;

  ZReportDetails({
    required this.id,
    required this.a,
    required this.c,
    required this.date,
    this.stockLocationId,
    this.locationName,
    this.picFile,
  });

  factory ZReportDetails.fromJson(Map<String, dynamic> json) {
    return ZReportDetails(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      a: json['a']?.toString() ?? '',
      c: json['c']?.toString() ?? '',
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
  final String a;
  final String c;
  final String date;
  final int? stockLocationId;
  final String? picFile; // Base64 encoded file

  ZReportCreate({
    required this.a,
    required this.c,
    required this.date,
    this.stockLocationId,
    this.picFile,
  });

  Map<String, dynamic> toJson() {
    return {
      'a': a,
      'c': c,
      'date': date,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      if (picFile != null) 'pic_file': picFile,
    };
  }
}
