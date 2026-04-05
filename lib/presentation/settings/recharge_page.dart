import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/models/recharge_order_model.dart';
import '../../data/models/recharge_product_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'recharge_controller.dart';

class RechargePage extends GetView<RechargeController> {
  const RechargePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '积分充值',
      subtitle: '仅支持在 App 内使用后台已开启的支付方式创建充值订单',
      accentColor: AppTheme.coral,
      child: RefreshIndicator(
        onRefresh: controller.refreshAll,
        child: Obx(() {
          final UserProfileModel? user =
              controller.authController.currentUser.value;
          final bool pointsEnabled = user?.pointsEnabled ?? true;
          final bool rechargeEnabled = user?.rechargeEnabled ?? true;
          final List<RechargeProductModel> products =
              controller.products.toList();
          final List<RechargeOrderModel> orders = controller.orders.toList();

          if (!pointsEnabled || !rechargeEnabled) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: <Widget>[
                SectionCard(
                  title: !pointsEnabled ? '积分系统未开启' : '充值入口未开启',
                  subtitle: !pointsEnabled
                      ? '管理员已在后台关闭积分系统，当前账号不会显示积分和充值相关内容。'
                      : '管理员已关闭充值入口，当前账号暂时无法在 App 内创建充值订单。',
                  icon: Icons.lock_outline_rounded,
                  accentColor: AppTheme.muted,
                  child: const _EmptyTip(
                    message: '当前暂不支持充值，请稍后再试。',
                  ),
                ),
              ],
            );
          }

          if (controller.isLoading.value &&
              products.isEmpty &&
              orders.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 120),
              children: const <Widget>[
                Center(child: CircularProgressIndicator()),
              ],
            );
          }

          return ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              _BalanceCard(user: user),
              const SizedBox(height: 14),
              _PayMethodCard(controller: controller),
              const SizedBox(height: 14),
              SectionCard(
                title: '充值套餐',
                subtitle: '下单后等待后台确认到账，确认后积分会自动增加。',
                icon: Icons.local_offer_outlined,
                accentColor: AppTheme.primary,
                child: products.isEmpty
                    ? const _EmptyTip(message: '当前没有可购买的充值套餐。')
                    : Column(
                        children: products
                            .map(
                              (RechargeProductModel product) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: product == products.last ? 0 : 12,
                                ),
                                child: _ProductTile(
                                  product: product,
                                  creating: controller.isCreating(product.code),
                                  onTap: () => controller.createOrder(product),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '最近订单',
                subtitle: '用于查看订单状态和到账说明。',
                icon: Icons.receipt_long_outlined,
                accentColor: AppTheme.sky,
                child: orders.isEmpty
                    ? const _EmptyTip(message: '还没有充值订单，选择上方套餐即可创建。')
                    : Column(
                        children: orders
                            .map(
                              (RechargeOrderModel order) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: order == orders.last ? 0 : 12,
                                ),
                                child: _OrderTile(order: order),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.user});

  final UserProfileModel? user;

  @override
  Widget build(BuildContext context) {
    final int balance = user?.pointsBalance ?? 0;
    final int costPerVideo = user?.videoGenerationCost ?? 0;
    final bool newUserOffer = user?.newUserRechargeAvailable ?? false;
    final bool rechargeEnabled = user?.paymentEnabled ?? false;

    return SectionCard(
      title: '当前积分',
      subtitle: costPerVideo > 0
          ? '生成视频每次扣除 $costPerVideo 积分，失败后系统会自动退回。'
          : '当前账号暂未开启积分扣费。',
      icon: Icons.stars_rounded,
      accentColor: AppTheme.coral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  AppTheme.primary.withValues(alpha: 0.14),
                  AppTheme.amber.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$balance',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 34,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '可用于继续生成视频',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          if (newUserOffer && rechargeEnabled) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '当前账号可购买新用户 0.1 元 30 积分尝鲜包。',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayMethodCard extends StatelessWidget {
  const _PayMethodCard({required this.controller});

  final RechargeController controller;

  @override
  Widget build(BuildContext context) {
    final UserProfileModel? user = controller.authController.currentUser.value;
    final bool wechatEnabled = user?.wechatPayEnabled ?? false;
    final bool alipayEnabled = user?.alipayPayEnabled ?? false;
    final bool hasAnyMethod = wechatEnabled || alipayEnabled;

    return SectionCard(
      title: '支付方式',
      subtitle: hasAnyMethod ? '按后台开启状态展示可用支付方式。' : '当前未配置可用支付方式。',
      icon: Icons.account_balance_wallet_outlined,
      accentColor: AppTheme.amber,
      child: Obx(
        () => !hasAnyMethod
            ? const _EmptyTip(message: '管理员暂未开启微信或支付宝支付。')
            : Row(
                children: <Widget>[
                  Expanded(
                    child: _PayMethodChip(
                      label: '微信充值',
                      selected: controller.selectedPayMethod.value == 'wechat',
                      enabled: wechatEnabled,
                      onTap: () => controller.selectPayMethod('wechat'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PayMethodChip(
                      label: '支付宝',
                      selected: controller.selectedPayMethod.value == 'alipay',
                      enabled: alipayEnabled,
                      onTap: () => controller.selectPayMethod('alipay'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.creating,
    required this.onTap,
  });

  final RechargeProductModel product;
  final bool creating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool available = product.available;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: available
            ? Colors.white.withValues(alpha: 0.74)
            : Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: available
              ? AppTheme.primary.withValues(alpha: 0.14)
              : AppTheme.muted.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${product.amountLabel} / ${product.points} 积分',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              if (product.isNewUserOnly)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '新用户',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryDeep,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
          if (!available &&
              product.disabledReason.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              product.disabledReason,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          PrimaryButton(
            label: creating ? '创建订单中...' : (available ? '创建充值订单' : '当前不可购买'),
            icon: Icons.payments_rounded,
            onPressed: available && !creating ? onTap : null,
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final RechargeOrderModel order;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = switch (order.status) {
      'paid' => AppTheme.sky,
      'failed' => AppTheme.coral,
      'cancelled' => AppTheme.muted,
      _ => AppTheme.amber,
    };

    final String hint =
        order.remark.trim().isNotEmpty ? order.remark : order.paymentHint;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  order.packageName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.statusLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.amountLabel} / ${order.pointsAmount} 积分 / ${order.payMethodLabel}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 10),
          Text(
            '订单号：${order.orderNo}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '创建时间：${_formatDate(order.createdAt)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (order.paidAt.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '到账时间：${_formatDate(order.paidAt)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (hint.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                hint,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    final DateTime? value = DateTime.tryParse(raw);
    if (value == null) {
      return raw.isEmpty ? '--' : raw;
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }
}

class _PayMethodChip extends StatelessWidget {
  const _PayMethodChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: enabled ? 0.72 : 0.42),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                enabled
                    ? Icons.check_circle_outline_rounded
                    : Icons.lock_outline_rounded,
                size: 18,
                color: enabled ? AppTheme.primaryDeep : AppTheme.muted,
              ),
              const SizedBox(width: 8),
              Text(
                enabled ? label : '$label（未开启）',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: enabled ? AppTheme.text : AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTip extends StatelessWidget {
  const _EmptyTip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    );
  }
}
