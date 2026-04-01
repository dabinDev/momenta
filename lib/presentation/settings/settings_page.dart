import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../data/models/app_update_info_model.dart';
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
            _ProfileHero(
              controller: controller,
              user: user,
            ),
            const SizedBox(height: 14),
            _ProfileInfoCard(
              controller: controller,
              user: user,
            ),
            const SizedBox(height: 14),
            _SecurityCard(controller: controller),
            const SizedBox(height: 14),
            _VersionCard(controller: controller),
          ],
        );
      }),
    );

    if (_embedded) {
      return content;
    }

    return AppPageScaffold(
      title: '个人中心',
      subtitle: '账号信息、版本更新与应用设置',
      accentColor: AppTheme.primary,
      child: content,
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.controller,
    required this.user,
  });

  final SettingsController controller;
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
    final String roleLabel = user?.isSuperuser == true ? '管理员' : '普通用户';
    final String statusLabel = user?.isActive == false ? '账号停用' : '正常使用';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 52,
            height: 6,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  AppTheme.primary,
                  AppTheme.amber,
                  AppTheme.jade,
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
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
              IconButton(
                onPressed: controller.refreshProfile,
                style: IconButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                ),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新信息',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _HeroBadge(label: roleLabel, tint: AppTheme.sky),
              _HeroBadge(label: statusLabel, tint: AppTheme.jade),
              _HeroBadge(
                label: controller.versionLabel,
                tint: AppTheme.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.controller,
    required this.user,
  });

  final SettingsController controller;
  final UserProfileModel? user;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '资料与设置',
      subtitle: '查看资料并进入常用设置',
      icon: Icons.badge_outlined,
      accentColor: AppTheme.sky,
      child: Column(
        children: <Widget>[
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: '账号',
            value: user?.username.trim().isNotEmpty == true
                ? user!.username
                : '未设置',
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _InfoRow(
            icon: Icons.drive_file_rename_outline_rounded,
            label: '昵称',
            value: user?.displayName.trim().isNotEmpty == true
                ? user!.displayName
                : '未设置',
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _InfoRow(
            icon: Icons.mail_outline_rounded,
            label: '邮箱',
            value: user?.email.trim().isNotEmpty == true ? user!.email : '未设置',
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _InfoRow(
            icon: Icons.phone_android_rounded,
            label: '手机',
            value: user?.phone.trim().isNotEmpty == true ? user!.phone : '未设置',
          ),
          const SizedBox(height: 10),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _EntryTile(
            icon: Icons.edit_outlined,
            title: '编辑资料',
            subtitle: '修改昵称、邮箱和手机号',
            onTap: controller.openEditProfile,
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _EntryTile(
            icon: Icons.tune_rounded,
            title: '应用设置',
            subtitle: '管理文案服务和视频服务配置',
            onTap: controller.openAppSettings,
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '账号安全',
      subtitle: '修改密码或退出当前账号',
      icon: Icons.shield_outlined,
      accentColor: AppTheme.coral,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final List<Widget> buttons = <Widget>[
            PrimaryButton.outline(
              label: '修改密码',
              icon: Icons.key_outlined,
              onPressed: controller.openChangePassword,
            ),
            PrimaryButton(
              label: '退出登录',
              icon: Icons.logout_rounded,
              onPressed: controller.logout,
            ),
          ];

          if (constraints.maxWidth < 360) {
            return Column(
              children: buttons
                  .expand<Widget>(
                    (Widget child) => <Widget>[
                      child,
                      const SizedBox(height: 10),
                    ],
                  )
                  .toList()
                ..removeLast(),
            );
          }

          return Row(
            children: buttons
                .expand<Widget>(
                  (Widget child) => <Widget>[
                    Expanded(child: child),
                    const SizedBox(width: 12),
                  ],
                )
                .toList()
              ..removeLast(),
          );
        },
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Obx(() {
      final AppUpdateInfoModel? updateInfo = controller.latestUpdateInfo.value;
      final AppReleaseModel? latest = updateInfo?.latest;
      final String latestVersionText = latest != null
          ? latest.versionLabel
          : (updateInfo == null ? '未获取' : '暂无新版本');
      final String channelText = latest?.channel.trim().isNotEmpty == true
          ? latest!.channel
          : AppConstants.updateChannel;
      final String statusText = updateInfo == null
          ? '未检查更新'
          : updateInfo.hasUpdate
              ? (updateInfo.isForceUpdate ? '有强制更新' : '有可用更新')
              : '已经是最新版本';
      final String notesText = latest?.releaseNotes.trim().isNotEmpty == true
          ? latest!.releaseNotes
          : AppConstants.updateHint;

      return SectionCard(
        title: '版本更新',
        subtitle: '查看当前版本和后台发布状态',
        icon: Icons.system_update_alt_rounded,
        accentColor: AppTheme.amber,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _VersionRow(label: '当前版本', value: controller.versionLabel),
            Divider(color: theme.colorScheme.outlineVariant),
            _VersionRow(label: '更新通道', value: channelText),
            Divider(color: theme.colorScheme.outlineVariant),
            _VersionRow(label: '更新状态', value: statusText),
            Divider(color: theme.colorScheme.outlineVariant),
            _VersionRow(label: '最新版本', value: latestVersionText),
            if (latest?.downloadUrl.trim().isNotEmpty == true) ...<Widget>[
              Divider(color: theme.colorScheme.outlineVariant),
              _VersionRow(label: '下载地址', value: latest!.downloadUrl),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                notesText,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: controller.isCheckingUpdate.value ? '检查中...' : '检查更新',
              icon: Icons.refresh_rounded,
              onPressed: controller.isCheckingUpdate.value
                  ? null
                  : controller.checkForUpdates,
            ),
          ],
        ),
      );
    });
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.tint,
  });

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.text,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 54,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 10),
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

class _VersionRow extends StatelessWidget {
  const _VersionRow({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 70,
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

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
