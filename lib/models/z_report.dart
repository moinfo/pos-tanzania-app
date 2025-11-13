class ZReport {
  final String id;
  final String a;
  final String c;
  final String date;
  final String? picFile;
  final String? picFileUrl;
  final String? createdAt;

  ZReport({
    required this.id,
    required this.a,
    required this.c,
    required this.date,
    this.picFile,
    this.picFileUrl,
    this.createdAt,
  });

  factory ZReport.fromJson(Map<String, dynamic> json) {
    return ZReport(
      id: json['id']?.toString() ?? '',
      a: json['a']?.toString() ?? '',
      c: json['c']?.toString() ?? '',
      date: json['date'] ?? '',
      picFile: json['pic_file'],
      picFileUrl: json['pic_file_url'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'a': a,
      'c': c,
      'date': date,
      'pic_file': picFile,
      'pic_file_url': picFileUrl,
      'created_at': createdAt,
    };
  }
}
