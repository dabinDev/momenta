import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/constants.dart';
import '../../data/models/user_profile_model.dart';
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
          children: <Widget>[
            _ProfileHero(
              controller: controller,
              user: user,
            ),
            const SizedBox(height: 12),
            _ProfileInfoCard(
              controller: controller,
              user: user,
            ),
            const SizedBox(height: 12),
            _SecurityCard(controller: controller),
            const SizedBox(height: 12),
            _VersionCard(controller: controller),
          ],
        );
      }),
    );

    if (_embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: SafeArea(child: content),
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
    final String statusLabel = user?.isActive == false ? '已停用' : '正常使用';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF3E7080),
            Color(0xFF84A86A),
            Color(0xFFE4A14B)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1F3E7080),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                backgroundImage: (user?.avatar.isNotEmpty ?? false)
                    ? NetworkImage(user!.avatar)
                    : null,
                child: (user?.avatar.isNotEmpty ?? false)
                    ? null
                    : const Icon(Icons.person_rounded,
                        color: Colors.white, size: 32),
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
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.94),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: controller.refreshProfile,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
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
              _HeroBadge(icon: Icons.verified_user_outlined, label: roleLabel),
              _HeroBadge(
                  icon: Icons.favorite_border_rounded, label: statusLabel),
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
      title: '用户信息',
      subtitle: '当前账号资料',
      icon: Icons.badge_outlined,
      accentColor: const Color(0xFF4E7BB4),
      child: Column(
        children: <Widget>[
          _InfoRow(
            icon: Icons.numbers_rounded,
            label: '用户 ID',
            value: user != null ? user!.id.toString() : '未获取',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: '用户名',
            value: user?.username.trim().isNotEmpty == true
                ? user!.username
                : '未设置',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.drive_file_rename_outline_rounded,
            label: '昵称',
            value: user?.displayName.trim().isNotEmpty == true
                ? user!.displayName
                : '未设置',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.mail_outline_rounded,
            label: '邮箱',
            value:
                user?.email.trim().isNotEmpty == true ? user!.email : '未设置邮箱',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.phone_android_rounded,
            label: '手机号',
            value:
                user?.phone.trim().isNotEmpty == true ? user!.phone : '未设置手机号',
          ),
          const SizedBox(height: 16),
          _EntryTile(
            icon: Icons.edit_outlined,
            title: '编辑资料',
            subtitle: '修改昵称、邮箱、手机号',
            onTap: controller.openEditProfile,
          ),
          const SizedBox(height: 12),
          _EntryTile(
            icon: Icons.tune_rounded,
            title: '应用设置',
            subtitle: '服务配置与接口地址',
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
      subtitle: '密码与登录',
      icon: Icons.shield_outlined,
      accentColor: const Color(0xFF876B41),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool stackVertically = constraints.maxWidth < 360;

          if (stackVertically) {
            return Column(
              children: <Widget>[
                PrimaryButton.outline(
                  label: '修改密码',
                  icon: Icons.key_outlined,
                  onPressed: controller.openChangePassword,
                ),
                const SizedBox(height: 12),
                PrimaryButton.outline(
                  label: '退出登录',
                  icon: Icons.logout_rounded,
                  onPressed: controller.logout,
                ),
              ],
            );
          }

          return Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton.outline(
                  label: '修改密码',
                  icon: Icons.key_outlined,
                  onPressed: controller.openChangePassword,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton.outline(
                  label: '退出登录',
                  icon: Icons.logout_rounded,
                  onPressed: controller.logout,
                ),
              ),
            ],
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

    return SectionCard(
      title: '版本更新',
      subtitle: '查看版本与更新方式',
      icon: Icons.system_update_alt_rounded,
      accentColor: const Color(0xFFE18E48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: <Widget>[
                _VersionRow(
                  icon: Icons.new_releases_outlined,
                  label: '当前版本',
                  value: controller.versionLabel,
                ),
                const SizedBox(height: 12),
                _VersionRow(
                  icon: Icons.route_outlined,
                  label: '更新渠道',
                  value: AppConstants.updateChannel,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppConstants.updateHint,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => PrimaryButton(
              label: controller.isCheckingUpdate.value ? '检查中...' : '检查更新',
              icon: Icons.refresh_rounded,
              onPressed: controller.isCheckingUpdate.value
                  ? null
                  : controller.checkForUpdates,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
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
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: theme.colorScheme.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
