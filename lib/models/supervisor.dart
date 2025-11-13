class Supervisor {
  final String id;
  final String name;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final String? email;

  Supervisor({
    required this.id,
    required this.name,
    this.phone,
    this.firstName,
    this.lastName,
    this.email,
  });

  String get displayName => name.isNotEmpty ? name : '${firstName ?? ''} ${lastName ?? ''}'.trim();

  factory Supervisor.fromJson(Map<String, dynamic> json) {
    return Supervisor(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
    };
  }
}
