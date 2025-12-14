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
  final String? profilePicture; // Profile picture URL (Leruma feature)
  final int? locationId; // User's assigned stock location (Leruma feature)
  final String? locationName; // User's assigned stock location name

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
    this.profilePicture,
    this.locationId,
    this.locationName,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
  String get displayName => fullName.isEmpty ? username : fullName;

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle both nested and flat user data
    final userData = json['user'] ?? json;

    // Parse location_id safely
    int? locationId;
    final locId = userData['location_id'];
    if (locId != null) {
      locationId = locId is int ? locId : int.tryParse(locId.toString());
    }

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
      profilePicture: userData['profile_picture'],
      locationId: locationId,
      locationName: userData['location_name'],
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
      'profile_picture': profilePicture,
      'location_id': locationId,
      'location_name': locationName,
    };
  }
}
