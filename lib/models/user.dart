class User {
  final String? id;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? language;
  final String? token;
  final String? tokenType;
  final int? expiresIn;

  User({
    this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.email,
    this.language,
    this.token,
    this.tokenType,
    this.expiresIn,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
  String get displayName => fullName.isEmpty ? username : fullName;

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle both nested and flat user data
    final userData = json['user'] ?? json;

    return User(
      id: userData['id']?.toString(),
      username: userData['username'] ?? '',
      firstName: userData['first_name'],
      lastName: userData['last_name'],
      email: userData['email'],
      language: userData['language'],
      token: json['token'],
      tokenType: json['token_type'],
      expiresIn: json['expires_in'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'language': language,
      'token': token,
      'token_type': tokenType,
      'expires_in': expiresIn,
    };
  }
}
