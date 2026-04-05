class RechargeOrderModel {
  const RechargeOrderModel({
    required this.orderNo,
    required this.packageName,
    required this.pointsAmount,
    required this.amountLabel,
    required this.payMethodLabel,
    required this.status,
    required this.statusLabel,
    required this.paymentHint,
    required this.remark,
    required this.createdAt,
    required this.paidAt,
  });

  final String orderNo;
  final String packageName;
  final int pointsAmount;
  final String amountLabel;
  final String payMethodLabel;
  final String status;
  final String statusLabel;
  final String paymentHint;
  final String remark;
  final String createdAt;
  final String paidAt;

  bool get isPending => status == 'pending';

  factory RechargeOrderModel.fromJson(Map<String, dynamic> json) {
    return RechargeOrderModel(
      orderNo: (json['order_no'] ?? '').toString(),
      packageName: (json['package_name'] ?? '').toString(),
      pointsAmount: (json['points_amount'] as num?)?.toInt() ?? 0,
      amountLabel: (json['amount_label'] ?? '').toString(),
      payMethodLabel: (json['pay_method_label'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      statusLabel: (json['status_label'] ?? '').toString(),
      paymentHint: (json['payment_hint'] ?? '').toString(),
      remark: (json['remark'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      paidAt: (json['paid_at'] ?? '').toString(),
    );
  }
}
