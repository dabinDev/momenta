import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'app_settings_controller.dart';

class AppSettingsPage extends GetView<AppSettingsController> {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '应用设置',
      subtitle: '普通用户不展示服务器地址和接口配置',
      accentColor: AppTheme.primary,
      child: RefreshIndicator(
        onRefresh: controller.refreshConfig,
        child: Obx(() {
          if (controller.isLoading.value) {
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
              SectionCard(
                title: '服务说明',
                subtitle: 'AI、视频生成和语音识别参数由后台统一维护',
                icon: Icons.admin_panel_settings_outlined,
                accentColor: AppTheme.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '当前 App 不再向普通用户展示服务器地址、API Key、模型名称等开发配置，避免误操作影响使用。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '如需切换环境、更新接口或调整模型，请在后端与开发环境中统一维护。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    Obx(
                      () => PrimaryButton.outline(
                        label: controller.isSyncing.value ? '刷新中...' : '刷新状态',
                        icon: Icons.sync_rounded,
                        onPressed: controller.isSyncing.value
                            ? null
                            : controller.refreshConfig,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
