import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../data/models/app_update_info_model.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'settings_controller.dart';

class ProfileDetailPage extends GetView<SettingsController> {
  const ProfileDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '个人信息',
      subtitle: '管理资料、密码、版本和应用设置',
      accentColor: AppTheme.primary,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          SectionCard(
            title: '账号管理',
            subtitle: '常用设置放在这里',
            icon: Icons.manage_accounts_outlined,
            accentColor: AppTheme.sky,
            child: Column(
              children: <Widget>[
                _EntryTile(
                  icon: Icons.edit_outlined,
                  title: '编辑资料',
                  subtitle: '修改昵称、邮箱和手机号',
                  onTap: controller.openEditProfile,
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                _EntryTile(
                  icon: Icons.key_outlined,
                  title: '修改密码',
                  subtitle: '更新当前账号密码',
                  onTap: controller.openChangePassword,
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                _EntryTile(
                  icon: Icons.tune_rounded,
                  title: '应用设置',
                  subtitle: '管理文案与视频服务配置',
                  onTap: controller.openAppSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Obx(() {
            final AppUpdateInfoModel? updateInfo =
                controller.latestUpdateInfo.value;
            final AppReleaseModel? latest = updateInfo?.latest;
            final String latestVersion = latest?.versionLabel ?? '暂无新版本';
            final String statusText = updateInfo == null
                ? '尚未检查更新'
                : updateInfo.hasUpdate
                    ? (updateInfo.isForceUpdate ? '发现强制更新' : '发现可用更新')
                    : '当前已是最新版本';

            return SectionCard(
              title: '版本信息',
              subtitle: '查看当前版本并检查更新',
              icon: Icons.system_update_alt_rounded,
              accentColor: AppTheme.amber,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _InfoRow(label: '当前版本', value: controller.versionLabel),
                  Divider(color: Theme.of(context).colorScheme.outlineVariant),
                  _InfoRow(label: '更新状态', value: statusText),
                  Divider(color: Theme.of(context).colorScheme.outlineVariant),
                  _InfoRow(label: '最新版本', value: latestVersion),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      latest?.releaseNotes.trim().isNotEmpty == true
                          ? latest!.releaseNotes
                          : AppConstants.updateHint,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label:
                        controller.isCheckingUpdate.value ? '检查中...' : '检查更新',
                    icon: Icons.refresh_rounded,
                    onPressed: controller.isCheckingUpdate.value
                        ? null
                        : controller.checkForUpdates,
                  ),
                ],
              ),
            );
          }),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 74,
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
