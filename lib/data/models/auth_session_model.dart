class AuthSessionModel {
  const AuthSessionModel({
    required this.accessToken,
    required this.username,
  });

  final String accessToken;
  final String username;

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      accessToken: (json['access_token'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
    );
  }
}
