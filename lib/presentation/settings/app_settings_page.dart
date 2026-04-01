import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'app_settings_controller.dart';

class AppSettingsPage extends GetView<AppSettingsController> {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '应用设置',
      subtitle: '管理文案服务和视频服务配置',
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
                title: '服务配置',
                subtitle: '切换文案服务或视频服务，并直接保存到当前账号',
                icon: Icons.tune_rounded,
                accentColor: AppTheme.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Obx(
                      () => Row(
                        children: <Widget>[
                          Expanded(
                            child: _SectionChip(
                              label: '文案服务',
                              icon: Icons.auto_awesome_outlined,
                              selected: controller.selectedSectionIndex.value == 0,
                              onTap: () => controller.switchSection(0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SectionChip(
                              label: '视频服务',
                              icon: Icons.movie_creation_outlined,
                              selected: controller.selectedSectionIndex.value == 1,
                              onTap: () => controller.switchSection(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Obx(
                      () => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: controller.selectedSectionIndex.value == 0
                            ? const _LlmSettingsForm(key: ValueKey<String>('llm'))
                            : const _VideoSettingsForm(
                                key: ValueKey<String>('video'),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final List<Widget> buttons = <Widget>[
                          Obx(
                            () => PrimaryButton(
                              label: controller.isSaving.value ? '保存中...' : '保存设置',
                              icon: Icons.save_outlined,
                              onPressed: controller.isSaving.value
                                  ? null
                                  : controller.save,
                            ),
                          ),
                          Obx(
                            () => PrimaryButton.outline(
                              label: controller.isSyncing.value ? '同步中...' : '同步配置',
                              icon: Icons.sync_rounded,
                              onPressed: controller.isSyncing.value
                                  ? null
                                  : controller.refreshConfig,
                            ),
                          ),
                          PrimaryButton.outline(
                            label: '恢复默认',
                            icon: Icons.restart_alt_rounded,
                            onPressed: controller.restoreDefaults,
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

                        return Column(
                          children: <Widget>[
                            buttons.first,
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                Expanded(child: buttons[1]),
                                const SizedBox(width: 10),
                                Expanded(child: buttons[2]),
                              ],
                            ),
                          ],
                        );
                      },
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
                ? AppTheme.primary.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                icon,
                color: selected ? AppTheme.primary : theme.colorScheme.onSurface,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: selected ? AppTheme.primary : null,
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
