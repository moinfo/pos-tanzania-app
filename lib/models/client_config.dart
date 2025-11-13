class ClientConfig {
  final String id;
  final String name;
  final String displayName;
  final String devApiUrl;
  final String prodApiUrl;
  final String? logoUrl;
  final bool isActive;

  ClientConfig({
    required this.id,
    required this.name,
    required this.displayName,
    required this.devApiUrl,
    required this.prodApiUrl,
    this.logoUrl,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'devApiUrl': devApiUrl,
      'prodApiUrl': prodApiUrl,
      'logoUrl': logoUrl,
      'isActive': isActive,
    };
  }

  factory ClientConfig.fromJson(Map<String, dynamic> json) {
    return ClientConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      devApiUrl: json['devApiUrl'] as String,
      prodApiUrl: json['prodApiUrl'] as String,
      logoUrl: json['logoUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'ClientConfig(id: $id, name: $name, displayName: $displayName)';
  }
}
