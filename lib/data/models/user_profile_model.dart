class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.username,
    required this.email,
    required this.alias,
    required this.phone,
    required this.isActive,
    required this.isSuperuser,
    required this.avatar,
  });

  final int id;
  final String username;
  final String email;
  final String alias;
  final String phone;
  final bool isActive;
  final bool isSuperuser;
  final String avatar;

  String get displayName => alias.trim().isNotEmpty ? alias : username;

  factory UserProfileModel.placeholder(String username) {
    return UserProfileModel(
      id: 0,
      username: username,
      email: '',
      alias: '',
      phone: '',
      isActive: true,
      isSuperuser: false,
      avatar: '',
    );
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      alias: (json['alias'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      isActive: json['is_active'] == true,
      isSuperuser: json['is_superuser'] == true,
      avatar: (json['avatar'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'email': email,
      'alias': alias,
      'phone': phone,
      'is_active': isActive,
      'is_superuser': isSuperuser,
      'avatar': avatar,
    };
  }
}
