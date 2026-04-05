import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/models/invite_overview_model.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/section_card.dart';
import 'invite_center_controller.dart';

class InviteCenterPage extends GetView<InviteCenterController> {
  const InviteCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '我的邀请',
      subtitle: '查看当前邀请码和已邀请用户',
      accentColor: AppTheme.sky,
      child: RefreshIndicator(
        onRefresh: controller.refreshOverview,
        child: Obx(() {
          final InviteOverviewModel? overview = controller.overview.value;
          if (controller.isLoading.value && overview == null) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 120),
              children: const <Widget>[
                Center(child: CircularProgressIndicator()),
              ],
            );
          }

          final List<InvitedUserModel> invitedUsers =
              overview?.invitedUsers.toList() ?? const <InvitedUserModel>[];

          return ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              SectionCard(
                title: '当前邀请码',
                subtitle: '注册页填写这个邀请码后，受邀用户和邀请人都会按后台规则获得积分。',
                icon: Icons.qr_code_rounded,
                accentColor: AppTheme.primary,
                child: _InviteCodeCard(
                  code: overview?.primaryInviteCode.code ?? '--',
                  usedCount: overview?.primaryInviteCode.usedCount ?? 0,
                  totalCount: overview?.primaryInviteCode.maxUses ?? 0,
                  active: overview?.primaryInviteCode.isActive ?? false,
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '邀请记录',
                subtitle: '已邀请 ${overview?.totalInvitedUsers ?? 0} 位用户',
                icon: Icons.group_outlined,
                accentColor: AppTheme.jade,
                child: invitedUsers.isEmpty
                    ? const _EmptyState(message: '还没有邀请记录，分享邀请码后新用户注册就会出现在这里。')
                    : Column(
                        children: invitedUsers
                            .map(
                              (InvitedUserModel item) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: item == invitedUsers.last ? 0 : 12,
                                ),
                                child: _InvitedUserTile(item: item),
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

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.code,
    required this.usedCount,
    required this.totalCount,
    required this.active,
  });

  final String code;
  final int usedCount;
  final int totalCount;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppTheme.sky.withValues(alpha: 0.16),
            AppTheme.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            code,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 30,
                  letterSpacing: 2,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            active ? '状态正常，可继续分享' : '当前邀请码已停用，请联系管理员处理',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '已使用 $usedCount 次 / 总次数 ${totalCount <= 0 ? "--" : totalCount}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _InvitedUserTile extends StatelessWidget {
  const _InvitedUserTile({required this.item});

  final InvitedUserModel item;

  @override
  Widget build(BuildContext context) {
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
                  item.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                item.username,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.muted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.phone.trim().isNotEmpty ? item.phone : item.email,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '注册时间：${_formatDate(item.createdAt)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (item.inviteCode.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '使用邀请码：${item.inviteCode}',
              style: Theme.of(context).textTheme.bodyMedium,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    );
  }
}
