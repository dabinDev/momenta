import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../data/models/user_profile_model.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'settings_controller.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key}) : _embedded = false;

  const SettingsPage.embedded({super.key}) : _embedded = true;

  final bool _embedded;

  @override
  Widget build(BuildContext context) {
    final Widget content = RefreshIndicator(
      onRefresh: controller.refreshProfile,
      child: Obx(() {
        final UserProfileModel? user =
            controller.authController.currentUser.value;

        if (controller.isLoading.value && user == null) {
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
            _ProfileHero(user: user),
            const SizedBox(height: 14),
            _BasicInfoCard(
              controller: controller,
              user: user,
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: '退出登录',
              icon: Icons.logout_rounded,
              onPressed: controller.logout,
            ),
          ],
        );
      }),
    );

    if (_embedded) {
      return content;
    }

    return AppPageScaffold(
      title: '个人中心',
      subtitle: '账号信息与常用设置',
      accentColor: AppTheme.primary,
      child: content,
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final UserProfileModel? user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName
        : '未登录用户';
    final String username = user?.username.trim().isNotEmpty == true
        ? '@${user!.username}'
        : '请先登录账号';

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Row(
        children: <Widget>[
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: (user?.avatar.isNotEmpty ?? false)
                  ? Image.network(user!.avatar, fit: BoxFit.cover)
                  : const Icon(
                      Icons.person_rounded,
                      color: AppTheme.primary,
                      size: 34,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BasicInfoCard extends StatelessWidget {
  const _BasicInfoCard({
    required this.controller,
    required this.user,
  });

  final SettingsController controller;
  final UserProfileModel? user;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '个人基础信息',
      subtitle: '关键信息收纳在这里',
      icon: Icons.badge_outlined,
      accentColor: AppTheme.sky,
      child: Column(
        children: <Widget>[
          _InfoRow(
            label: '账号',
            value: user?.username.trim().isNotEmpty == true
                ? user!.username
                : '未设置',
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _InfoRow(
            label: '手机号',
            value: user?.phone.trim().isNotEmpty == true ? user!.phone : '未设置',
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _InfoRow(
            label: '版本号',
            value: controller.versionLabel,
          ),
          const SizedBox(height: 16),
          PrimaryButton.outline(
            label: '个人信息',
            icon: Icons.chevron_right_rounded,
            onPressed: controller.openProfileDetail,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
