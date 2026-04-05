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
    required this.pointsBalance,
    required this.totalPointsSpent,
    required this.totalPointsRecharged,
    required this.completedRechargeCount,
    required this.newUserRechargeAvailable,
    required this.pointsEnabled,
    required this.rechargeEnabled,
    required this.wechatPayEnabled,
    required this.alipayPayEnabled,
    required this.paymentEnabled,
    required this.paymentMethods,
    required this.videoGenerationCost,
  });

  final int id;
  final String username;
  final String email;
  final String alias;
  final String phone;
  final bool isActive;
  final bool isSuperuser;
  final String avatar;
  final int pointsBalance;
  final int totalPointsSpent;
  final int totalPointsRecharged;
  final int completedRechargeCount;
  final bool newUserRechargeAvailable;
  final bool pointsEnabled;
  final bool rechargeEnabled;
  final bool wechatPayEnabled;
  final bool alipayPayEnabled;
  final bool paymentEnabled;
  final List<String> paymentMethods;
  final int videoGenerationCost;

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
      pointsBalance: 0,
      totalPointsSpent: 0,
      totalPointsRecharged: 0,
      completedRechargeCount: 0,
      newUserRechargeAvailable: true,
      pointsEnabled: true,
      rechargeEnabled: true,
      wechatPayEnabled: true,
      alipayPayEnabled: false,
      paymentEnabled: true,
      paymentMethods: const <String>['wechat'],
      videoGenerationCost: 10,
    );
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> pointsSummary =
        (json['points_summary'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    final Map<String, dynamic> featureFlags =
        (json['feature_flags'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    final bool pointsEnabled = (json['points_enabled'] ??
            featureFlags['points_enabled'] ??
            pointsSummary['points_enabled']) !=
        false;
    final bool rechargeEnabled = (json['recharge_enabled'] ??
            featureFlags['recharge_enabled'] ??
            pointsSummary['recharge_enabled']) ==
        true;
    final bool wechatPayEnabled = (json['wechat_pay_enabled'] ??
            featureFlags['wechat_pay_enabled'] ??
            pointsSummary['wechat_pay_enabled']) ==
        true;
    final bool alipayPayEnabled = (json['alipay_pay_enabled'] ??
            featureFlags['alipay_pay_enabled'] ??
            pointsSummary['alipay_pay_enabled']) ==
        true;
    final List<String> paymentMethods = ((json['payment_methods'] ??
                pointsSummary['payment_methods']) as List<dynamic>? ??
            const <dynamic>[])
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();
    final bool paymentEnabled =
        (json['payment_enabled'] ?? pointsSummary['payment_enabled']) == true;
    return UserProfileModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      alias: (json['alias'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      isActive: json['is_active'] == true,
      isSuperuser: json['is_superuser'] == true,
      avatar: (json['avatar'] ?? '').toString(),
      pointsBalance:
          ((json['points_balance'] ?? pointsSummary['points_balance']) as num?)
                  ?.toInt() ??
              0,
      totalPointsSpent: ((json['total_points_spent'] ??
                  pointsSummary['total_points_spent']) as num?)
              ?.toInt() ??
          0,
      totalPointsRecharged: ((json['total_points_recharged'] ??
                  pointsSummary['total_points_recharged']) as num?)
              ?.toInt() ??
          0,
      completedRechargeCount: ((json['completed_recharge_count'] ??
                  pointsSummary['completed_recharge_count']) as num?)
              ?.toInt() ??
          0,
      newUserRechargeAvailable: (json['new_user_recharge_available'] ??
              pointsSummary['new_user_recharge_available']) ==
          true,
      pointsEnabled: pointsEnabled,
      rechargeEnabled: pointsEnabled && rechargeEnabled,
      wechatPayEnabled: pointsEnabled && rechargeEnabled && wechatPayEnabled,
      alipayPayEnabled: pointsEnabled && rechargeEnabled && alipayPayEnabled,
      paymentEnabled: pointsEnabled && rechargeEnabled && paymentEnabled,
      paymentMethods: paymentMethods.isNotEmpty
          ? paymentMethods
          : <String>[
              if (pointsEnabled && rechargeEnabled && wechatPayEnabled)
                'wechat',
              if (pointsEnabled && rechargeEnabled && alipayPayEnabled)
                'alipay',
            ],
      videoGenerationCost: ((json['video_generation_cost'] ??
                  pointsSummary['video_generation_cost']) as num?)
              ?.toInt() ??
          0,
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
      'points_balance': pointsBalance,
      'total_points_spent': totalPointsSpent,
      'total_points_recharged': totalPointsRecharged,
      'completed_recharge_count': completedRechargeCount,
      'new_user_recharge_available': newUserRechargeAvailable,
      'points_enabled': pointsEnabled,
      'recharge_enabled': rechargeEnabled,
      'wechat_pay_enabled': wechatPayEnabled,
      'alipay_pay_enabled': alipayPayEnabled,
      'payment_enabled': paymentEnabled,
      'payment_methods': paymentMethods,
      'video_generation_cost': videoGenerationCost,
    };
  }
}
