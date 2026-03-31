import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/constants.dart';
import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'app_settings_controller.dart';

class AppSettingsPage extends GetView<AppSettingsController> {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: SafeArea(
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
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: <Widget>[
                SectionCard(
                  title: '配置面板',
                  subtitle: '选择要调整的服务',
                  icon: Icons.tune_rounded,
                  accentColor: const Color(0xFF5A816A),
                  child: Column(
                    children: <Widget>[
                      Obx(
                        () => Row(
                          children: <Widget>[
                            Expanded(
                              child: _SectionChip(
                                label: '文案服务',
                                icon: Icons.auto_awesome_outlined,
                                selected:
                                    controller.selectedSectionIndex.value == 0,
                                onTap: () => controller.switchSection(0),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SectionChip(
                                label: '视频服务',
                                icon: Icons.movie_creation_outlined,
                                selected:
                                    controller.selectedSectionIndex.value == 1,
                                onTap: () => controller.switchSection(1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: controller.selectedSectionIndex.value == 0
                              ? const _LlmSettingsForm(
                                  key: ValueKey<String>('llm'))
                              : const _VideoSettingsForm(
                                  key: ValueKey<String>('video')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: '设置操作',
                  subtitle: '保存后立即生效',
                  icon: Icons.tune_rounded,
                  accentColor: const Color(0xFF5A816A),
                  child: Column(
                    children: <Widget>[
                      Obx(
                        () => PrimaryButton(
                          label: controller.isSaving.value ? '保存中...' : '保存设置',
                          icon: Icons.save_outlined,
                          onPressed: controller.isSaving.value
                              ? null
                              : controller.save,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Obx(
                              () => PrimaryButton.outline(
                                label: controller.isSyncing.value
                                    ? '同步中...'
                                    : '同步配置',
                                icon: Icons.sync_rounded,
                                onPressed: controller.isSyncing.value
                                    ? null
                                    : controller.refreshConfig,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton.outline(
                              label: '恢复默认',
                              icon: Icons.restart_alt_rounded,
                              onPressed: controller.restoreDefaults,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.10)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                icon,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: selected ? theme.colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LlmSettingsForm extends GetView<AppSettingsController> {
  const _LlmSettingsForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      children: <Widget>[
        LargeTextField(
          controller: controller.llmBaseUrlController,
          label: '服务地址',
          hintText: AppConstants.defaultLlmBaseUrl,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        LargeTextField(
          controller: controller.llmModelController,
          label: '模型名称',
          hintText: AppConstants.defaultLlmModel,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        LargeTextField(
          controller: controller.llmApiKeyController,
          label: 'API Key',
          hintText: AppConstants.defaultLlmApiKeyPlaceholder,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

class _VideoSettingsForm extends GetView<AppSettingsController> {
  const _VideoSettingsForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      children: <Widget>[
        LargeTextField(
          controller: controller.videoBaseUrlController,
          label: '服务地址',
          hintText: AppConstants.defaultVideoBaseUrl,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        LargeTextField(
          controller: controller.videoModelController,
          label: '模型名称',
          hintText: AppConstants.defaultVideoModel,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        LargeTextField(
          controller: controller.videoApiKeyController,
          label: 'API Key',
          hintText: '请输入视频服务密钥',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.save(),
        ),
      ],
    );
  }
}
