class InviteCodeInfoModel {
  const InviteCodeInfoModel({
    required this.id,
    required this.code,
    required this.remark,
    required this.usedCount,
    required this.maxUses,
    required this.isActive,
  });

  final int id;
  final String code;
  final String remark;
  final int usedCount;
  final int maxUses;
  final bool isActive;

  factory InviteCodeInfoModel.fromJson(Map<String, dynamic> json) {
    return InviteCodeInfoModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: (json['code'] ?? '').toString(),
      remark: (json['remark'] ?? '').toString(),
      usedCount: (json['used_count'] as num?)?.toInt() ?? 0,
      maxUses: (json['max_uses'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true,
    );
  }
}

class InvitedUserModel {
  const InvitedUserModel({
    required this.id,
    required this.username,
    required this.alias,
    required this.email,
    required this.phone,
    required this.inviteCode,
    required this.createdAt,
  });

  final int id;
  final String username;
  final String alias;
  final String email;
  final String phone;
  final String inviteCode;
  final String createdAt;

  String get displayName => alias.trim().isNotEmpty ? alias : username;

  factory InvitedUserModel.fromJson(Map<String, dynamic> json) {
    return InvitedUserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? '').toString(),
      alias: (json['alias'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      inviteCode: (json['invite_code'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class InviteOverviewModel {
  const InviteOverviewModel({
    required this.ownerUserId,
    required this.primaryInviteCode,
    required this.inviteCodes,
    required this.invitedUsers,
    required this.totalInvitedUsers,
  });

  final int ownerUserId;
  final InviteCodeInfoModel primaryInviteCode;
  final List<InviteCodeInfoModel> inviteCodes;
  final List<InvitedUserModel> invitedUsers;
  final int totalInvitedUsers;

  factory InviteOverviewModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> summary =
        (json['summary'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final List<dynamic> inviteCodes =
        json['invite_codes'] as List<dynamic>? ?? const <dynamic>[];
    final List<dynamic> invitedUsers =
        json['invited_users'] as List<dynamic>? ?? const <dynamic>[];

    return InviteOverviewModel(
      ownerUserId: (json['owner_user_id'] as num?)?.toInt() ?? 0,
      primaryInviteCode: InviteCodeInfoModel.fromJson(
        (json['primary_invite_code'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      inviteCodes: inviteCodes
          .map((dynamic item) => InviteCodeInfoModel.fromJson(
              (item as Map).cast<String, dynamic>()))
          .toList(),
      invitedUsers: invitedUsers
          .map((dynamic item) =>
              InvitedUserModel.fromJson((item as Map).cast<String, dynamic>()))
          .toList(),
      totalInvitedUsers: (summary['total_invited_users'] as num?)?.toInt() ??
          invitedUsers.length,
    );
  }
}
