class RechargeProductModel {
  const RechargeProductModel({
    required this.code,
    required this.name,
    required this.amountFen,
    required this.amountLabel,
    required this.points,
    required this.isNewUserOnly,
    required this.available,
    required this.disabledReason,
  });

  final String code;
  final String name;
  final int amountFen;
  final String amountLabel;
  final int points;
  final bool isNewUserOnly;
  final bool available;
  final String disabledReason;

  factory RechargeProductModel.fromJson(Map<String, dynamic> json) {
    return RechargeProductModel(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      amountFen: (json['amount_fen'] as num?)?.toInt() ?? 0,
      amountLabel: (json['amount_label'] ?? '').toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      isNewUserOnly: json['is_new_user_only'] == true,
      available: json['available'] != false,
      disabledReason: (json['disabled_reason'] ?? '').toString(),
    );
  }
}
