import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../data/models/ai_template_model.dart';
import '../../data/models/video_task_model.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_chip.dart';
import 'create_controller.dart';
import 'create_mode_sheet.dart';

class CreatePage extends GetView<CreateController> {
  const CreatePage({super.key}) : _embedded = false;

  const CreatePage.embedded({super.key}) : _embedded = true;

  final bool _embedded;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final CreateWorkbenchMode mode = controller.mode;
      final Widget content = ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _ModeHero(
            controller: controller,
            mode: mode,
            onSwitch: () => _showModeSheet(context),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _ModeWorkspace(
              key: ValueKey<String>(mode.code),
              mode: mode,
              controller: controller,
            ),
          ),
        ],
      );

      if (_embedded) {
        return content;
      }

      return AppPageScaffold(
        title: 'AI 创作',
        subtitle: controller.modeSubtitle,
        accentColor: mode.tint,
        actions: <Widget>[
          _ModeSwitchAction(
            label: controller.modeLabel,
            onTap: () => _showModeSheet(context),
          ),
        ],
        child: content,
      );
    });
  }

  Future<void> _showModeSheet(BuildContext context) {
    return showCreateModeSheet(
      context: context,
      controller: controller,
    );
  }
}

class _ModeWorkspace extends StatelessWidget {
  const _ModeWorkspace({
    super.key,
    required this.mode,
    required this.controller,
  });

  final CreateWorkbenchMode mode;
  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case CreateWorkbenchMode.simple:
        return Column(
          children: <Widget>[
            SectionCard(
              title: '快捷步骤',
              subtitle: '语音转文字、AI 校准、提示词生成和成片拆开执行。',
              icon: Icons.hub_rounded,
              accentColor: AppTheme.primary,
              child: _AiEntryGrid(controller: controller),
            ),
            const SizedBox(height: 14),
            _SimpleModeBody(controller: controller),
          ],
        );
      case CreateWorkbenchMode.starter:
        return _StarterModeBody(controller: controller);
      case CreateWorkbenchMode.custom:
        return _CustomModeBody(controller: controller);
    }
  }
}

class _ModeHero extends StatelessWidget {
  const _ModeHero({
    required this.controller,
    required this.mode,
    required this.onSwitch,
  });

  final CreateController controller;
  final CreateWorkbenchMode mode;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: mode.tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(mode.icon, color: mode.tint, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      controller.labelForMode(mode),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: mode.tint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.titleForMode(mode),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 26,
                      ),
                    ),
                  ],
                ),
              ),
              _ModeSwitchAction(
                label: '切换',
                onTap: onSwitch,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(controller.subtitleForMode(mode),
              style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: controller
                .highlightsForMode(mode)
                .map(
                  (String item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: mode.tint.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(item),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitchAction extends StatelessWidget {
  const _ModeSwitchAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.swap_horiz_rounded, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleModeBody extends StatelessWidget {
  const _SimpleModeBody({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SectionCard(
          title: '原稿输入',
          subtitle: '先输入想表达的内容，或者直接用语音转成文字。',
          icon: Icons.edit_note_rounded,
          accentColor: AppTheme.coral,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LargeTextField(
                controller: controller.textController,
                label: '原稿内容',
                hintText: '例如：给家里人做一条温暖自然的问候视频。',
                minLines: 4,
                maxLines: 6,
              ),
              const SizedBox(height: 14),
              _AdaptiveButtonRow(
                children: <Widget>[
                  Obx(
                    () => PrimaryButton.outline(
                      label: controller.isRecording.value
                          ? '录音中'
                          : controller.isTranscribing.value
                              ? '识别中'
                              : '语音转文字',
                      icon: controller.isRecording.value
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_none_rounded,
                      onPressed: controller.isRecording.value ||
                              controller.isTranscribing.value
                          ? null
                          : controller.toggleRecording,
                    ),
                  ),
                  Obx(
                    () => PrimaryButton.outline(
                      label: controller.isCorrecting.value ? '校准中' : 'AI 校准',
                      icon: Icons.spellcheck_rounded,
                      onPressed: controller.isCorrecting.value
                          ? null
                          : controller.correctText,
                    ),
                  ),
                ],
              ),
              Obx(
                () => controller.isTranscribing.value
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '正在识别语音内容...',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(minHeight: 7),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '创作提示词',
          subtitle: '提示词模板由后端维护，生成后仍可继续手动修改。',
          icon: Icons.auto_awesome_rounded,
          accentColor: AppTheme.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Obx(
                () => _TemplateSelector(
                  title: '后端提示词模板',
                  templates: controller.promptTemplates,
                  selectedKey: controller.selectedPromptTemplateKey.value,
                  selectedTemplate: controller.selectedPromptTemplate,
                  isLoading: controller.isLoadingTemplates.value,
                  emptyText: '未获取到提示词模板，将使用服务端默认模板。',
                  onRefresh: controller.refreshTemplates,
                  onSelected: controller.selectPromptTemplate,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '创作提示词',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Obx(
                    () => TextButton.icon(
                      onPressed: controller.isGeneratingPrompt.value
                          ? null
                          : controller.buildPrompt,
                      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text(
                        controller.isGeneratingPrompt.value ? '生成中' : '生成提示词',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LargeTextField(
                controller: controller.promptController,
                label: '视频提示词',
                hintText: '例如：暖色家庭场景，大字幕，镜头稳定，情绪温暖自然。',
                minLines: 5,
                maxLines: 7,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '视频生成',
          subtitle: '支持基础模板、时长和图片参考，适合快速成片。',
          icon: Icons.movie_creation_outlined,
          accentColor: AppTheme.jade,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Obx(
                () => _TemplateSelector(
                  title: '基础视频风格',
                  templates: controller.videoTemplates,
                  selectedKey: controller.selectedVideoTemplateKey.value,
                  selectedTemplate: controller.selectedVideoTemplate,
                  isLoading: controller.isLoadingTemplates.value,
                  emptyText: '未获取到视频模板，将使用服务端默认模板。',
                  onRefresh: controller.refreshTemplates,
                  onSelected: controller.selectVideoTemplate,
                ),
              ),
              const SizedBox(height: 18),
              _DurationSelector(controller: controller),
              const SizedBox(height: 18),
              _ImageUploadPanel(controller: controller),
              const SizedBox(height: 18),
              _SubmitPanel(
                controller: controller,
                label: '开始生成视频',
                onPressed: controller.generateSimpleVideo,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StarterModeBody extends StatelessWidget {
  const _StarterModeBody({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SectionCard(
          title: '视频链接参考',
          subtitle: '复制一个公开视频链接，结合上传图片去生成相关视频。',
          icon: Icons.link_rounded,
          accentColor: AppTheme.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LargeTextField(
                controller: controller.starterLinkController,
                label: '公开视频链接',
                hintText: '例如：https://www.douyin.com/...',
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              LargeTextField(
                controller: controller.starterNoteController,
                label: '补充说明',
                hintText: '例如：保留温暖节奏，字幕大一些，突出家庭陪伴。',
                minLines: 3,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Text(
                '入门模式默认采用系统模板，你只需要提供链接、图片和一句补充说明。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '参考图片',
          subtitle: '上传人物或场景图片，系统会围绕这些素材生成相似节奏的视频。',
          icon: Icons.photo_library_outlined,
          accentColor: AppTheme.coral,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ImageUploadPanel(controller: controller),
              const SizedBox(height: 18),
              _SubmitPanel(
                controller: controller,
                label: '生成关联视频',
                onPressed: controller.generateStarterVideo,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomModeBody extends StatelessWidget {
  const _CustomModeBody({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SectionCard(
          title: '热门模板',
          subtitle: '模板管理页后续可独立维护，这里先用热榜样片驱动自定义创作。',
          icon: Icons.local_fire_department_rounded,
          accentColor: AppTheme.jade,
          child: Obx(
            () => _TemplateGallery(
              templates: controller.videoTemplates,
              selectedKey: controller.selectedCustomTemplateKey.value,
              isLoading: controller.isLoadingTemplates.value,
              onRefresh: controller.refreshTemplates,
              onSelected: controller.selectCustomTemplate,
              onPreview: controller.openTemplatePreview,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '复刻素材',
          subtitle: '可仅上传图片，也可再上传一段 1 分钟内短视频作为节奏参考。',
          icon: Icons.perm_media_rounded,
          accentColor: AppTheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ImageUploadPanel(controller: controller),
              const SizedBox(height: 18),
              Obx(
                () => _AdaptiveButtonRow(
                  children: <Widget>[
                    PrimaryButton.outline(
                      label: '上传参考短视频',
                      icon: Icons.video_library_outlined,
                      onPressed: controller.pickReferenceVideo,
                    ),
                    PrimaryButton.outline(
                      label: controller.selectedReferenceVideo.value == null
                          ? '可不上传短视频'
                          : '已选参考短视频',
                      icon: Icons.smart_display_outlined,
                      onPressed: null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Obx(() {
                final XFile? file = controller.selectedReferenceVideo.value;
                if (file == null) {
                  return Text(
                    '如果有样片短视频，上传后会作为节奏和结构参考。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return _SelectedVideoTile(
                  file: file,
                  isUploading: controller.isUploadingReferenceVideo.value,
                  onRemove: controller.removeReferenceVideo,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '自定义要求',
          subtitle: '补充人物关系、口播语气、字幕样式或镜头重点。',
          icon: Icons.tune_rounded,
          accentColor: AppTheme.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LargeTextField(
                controller: controller.customNoteController,
                label: '补充要求',
                hintText: '例如：前 3 秒要有强开场，字幕大，节奏偏抖音口播。',
                minLines: 4,
                maxLines: 5,
              ),
              const SizedBox(height: 18),
              _DurationSelector(controller: controller),
              const SizedBox(height: 18),
              _SubmitPanel(
                controller: controller,
                label: '生成模板视频',
                onPressed: controller.generateCustomVideo,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AiEntryGrid extends StatelessWidget {
  const _AiEntryGrid({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 560;
        final List<Widget> items = <Widget>[
          Obx(
            () => _AiEntryTile(
              title: '语音转文字',
              subtitle: '先说出来，再自动识别成原稿内容。',
              icon: controller.isRecording.value
                  ? Icons.graphic_eq_rounded
                  : Icons.mic_rounded,
              tint: AppTheme.coral,
              onTap: controller.isRecording.value ||
                      controller.isTranscribing.value
                  ? null
                  : controller.toggleRecording,
            ),
          ),
          Obx(
            () => _AiEntryTile(
              title: 'AI 校准',
              subtitle: '修正错字、漏字和识别产生的输入偏差。',
              icon: Icons.spellcheck_rounded,
              tint: AppTheme.primary,
              onTap:
                  controller.isCorrecting.value ? null : controller.correctText,
            ),
          ),
          Obx(
            () => _AiEntryTile(
              title: '提示词生成',
              subtitle: '结合后端模板生成适合视频模型的提示词。',
              icon: Icons.auto_awesome_rounded,
              tint: AppTheme.sky,
              onTap: controller.isGeneratingPrompt.value
                  ? null
                  : controller.buildPrompt,
            ),
          ),
          Obx(
            () => _AiEntryTile(
              title: '短视频任务',
              subtitle: '带图片、提示词和基础模板参数直接发起生成。',
              icon: Icons.movie_creation_rounded,
              tint: AppTheme.jade,
              onTap: controller.isSubmitting.value
                  ? null
                  : controller.generateSimpleVideo,
            ),
          ),
        ];

        if (compact) {
          return Column(
            children: items
                .expand<Widget>(
                  (Widget child) => <Widget>[child, const SizedBox(height: 12)],
                )
                .toList()
              ..removeLast(),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (Widget child) => SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AiEntryTile extends StatelessWidget {
  const _AiEntryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: enabled
                ? tint.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: enabled
                  ? tint.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: enabled
                      ? Colors.white.withValues(alpha: 0.74)
                      : Colors.white.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon,
                    color: enabled ? tint : AppTheme.muted, size: 22),
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateSelector extends StatelessWidget {
  const _TemplateSelector({
    required this.title,
    required this.templates,
    required this.selectedKey,
    required this.selectedTemplate,
    required this.isLoading,
    required this.emptyText,
    required this.onRefresh,
    required this.onSelected,
  });

  final String title;
  final List<AiTemplateModel> templates;
  final String? selectedKey;
  final AiTemplateModel? selectedTemplate;
  final bool isLoading;
  final String emptyText;
  final VoidCallback onRefresh;
  final ValueChanged<AiTemplateModel> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AiTemplateModel? currentTemplate = selectedTemplate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            TextButton.icon(
              onPressed: isLoading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(isLoading ? '刷新中' : '刷新模板'),
            ),
          ],
        ),
        if (isLoading && templates.isEmpty) ...<Widget>[
          const SizedBox(height: 6),
          const LinearProgressIndicator(minHeight: 6),
          const SizedBox(height: 10),
        ] else if (templates.isEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(emptyText, style: theme.textTheme.bodyMedium),
        ] else ...<Widget>[
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: templates
                .map(
                  (AiTemplateModel template) => ChoiceChip(
                    label: Text(template.name),
                    selected: selectedKey == template.key,
                    onSelected: (_) => onSelected(template),
                  ),
                )
                .toList(),
          ),
          if (currentTemplate != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(currentTemplate.description,
                      style: theme.textTheme.bodyMedium),
                  if ((currentTemplate.preview ?? '')
                      .trim()
                      .isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      '模板预览：${currentTemplate.preview}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppTheme.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _TemplateGallery extends StatelessWidget {
  const _TemplateGallery({
    required this.templates,
    required this.selectedKey,
    required this.isLoading,
    required this.onRefresh,
    required this.onSelected,
    required this.onPreview,
  });

  final List<AiTemplateModel> templates;
  final String? selectedKey;
  final bool isLoading;
  final VoidCallback onRefresh;
  final ValueChanged<AiTemplateModel> onSelected;
  final ValueChanged<AiTemplateModel> onPreview;

  @override
  Widget build(BuildContext context) {
    if (isLoading && templates.isEmpty) {
      return const LinearProgressIndicator(minHeight: 6);
    }
    if (templates.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('暂时没有模板样片。', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          PrimaryButton.outline(
            label: '刷新模板',
            icon: Icons.refresh_rounded,
            onPressed: onRefresh,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '热门模板列表',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: isLoading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('刷新模板'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int index = 0; index < templates.length; index++) ...<Widget>[
          _TemplateGalleryTile(
            template: templates[index],
            selected: templates[index].key == selectedKey,
            onSelected: () => onSelected(templates[index]),
            onPreview: () => onPreview(templates[index]),
          ),
          if (index != templates.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TemplateGalleryTile extends StatelessWidget {
  const _TemplateGalleryTile({
    required this.template,
    required this.selected,
    required this.onSelected,
    required this.onPreview,
  });

  final AiTemplateModel template;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final List<String> tags = <String>[
      ...template.tags,
      if (template.supportsReferenceImage) '图片可用',
      if (template.supportsReferenceLink) '链接跟做',
      if (template.supportsReferenceVideo) '视频复刻',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.jade.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected
              ? AppTheme.jade.withValues(alpha: 0.4)
              : AppTheme.outline.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  template.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (template.popularity != null)
                Text('热度 ${template.popularity}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(template.description,
              style: Theme.of(context).textTheme.bodyMedium),
          if (tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  tags.map((String item) => Chip(label: Text(item))).toList(),
            ),
          ],
          const SizedBox(height: 14),
          _AdaptiveButtonRow(
            children: <Widget>[
              PrimaryButton.outline(
                label: '查看样片',
                icon: Icons.play_circle_outline,
                onPressed:
                    (template.previewVideoUrl ?? '').isEmpty ? null : onPreview,
              ),
              PrimaryButton.outline(
                label: selected ? '已选模板' : '使用模板',
                icon: selected ? Icons.check_rounded : Icons.add_rounded,
                onPressed: selected ? null : onSelected,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DurationSelector extends StatelessWidget {
  const _DurationSelector({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('视频时长', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Obx(
          () => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final int duration in controller.availableDurations)
                ChoiceChip(
                  label: Text('$duration 秒'),
                  selected: controller.selectedDuration.value == duration,
                  onSelected: (_) =>
                      controller.selectedDuration.value = duration,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageUploadPanel extends StatelessWidget {
  const _ImageUploadPanel({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _AdaptiveButtonRow(
          children: <Widget>[
            PrimaryButton.outline(
              label: '上传图片',
              icon: Icons.photo_library_outlined,
              onPressed: controller.pickImages,
            ),
            Obx(
              () => PrimaryButton.outline(
                label: controller.selectedImages.isEmpty
                    ? '可先不上传'
                    : '已选 ${controller.selectedImages.length} 张',
                icon: Icons.collections_outlined,
                onPressed: null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Obx(
          () => controller.selectedImages.isEmpty
              ? Text(
                  '没有参考图也可以直接生成，但上传图片后会优先参考人物和场景。',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: controller.selectedImages
                      .map(
                        (XFile file) => _SelectedImageTile(
                          file: file,
                          onRemove: () => controller.removeImage(file),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _SubmitPanel extends StatelessWidget {
  const _SubmitPanel({
    required this.controller,
    required this.label,
    required this.onPressed,
  });

  final CreateController controller;
  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Obx(
          () => PrimaryButton(
            label: controller.isSubmitting.value ? '生成中' : label,
            icon: Icons.movie_creation_outlined,
            onPressed: controller.isSubmitting.value
                ? null
                : () {
                    onPressed();
                  },
          ),
        ),
        const SizedBox(height: 14),
        _TaskStatusPanel(controller: controller),
      ],
    );
  }
}

class _TaskStatusPanel extends StatelessWidget {
  const _TaskStatusPanel({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final VideoTaskModel? task = controller.currentTask.value;
      final bool showProgress = controller.isSubmitting.value;
      if (!showProgress && task == null) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showProgress) ...<Widget>[
              LinearProgressIndicator(
                minHeight: 8,
                value: controller.generationProgress.value == 0
                    ? null
                    : controller.generationProgress.value,
              ),
              const SizedBox(height: 8),
              Text(
                '正在跟进任务进度 '
                '${controller.pollingCount.value}/${AppConstants.maxPollingTimes}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (task != null) ...<Widget>[
              if (showProgress) const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  StatusChip(status: task.status),
                  Text(
                    task.errorMessage?.trim().isNotEmpty == true
                        ? task.errorMessage!
                        : '任务编号：${task.id}',
                  ),
                ],
              ),
              if (task.isCompleted &&
                  (task.videoUrl?.isNotEmpty ?? false)) ...<Widget>[
                const SizedBox(height: 14),
                PrimaryButton.outline(
                  label: '播放结果',
                  icon: Icons.play_circle_outline,
                  onPressed: controller.openCurrentVideo,
                ),
              ],
            ],
          ],
        ),
      );
    });
  }
}

class _AdaptiveButtonRow extends StatelessWidget {
  const _AdaptiveButtonRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            children: children
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
          children: children
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
    );
  }
}

class _SelectedImageTile extends StatelessWidget {
  const _SelectedImageTile({
    required this.file,
    required this.onRemove,
  });

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 102,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File(file.path),
                  width: 102,
                  height: 102,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.88),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SelectedVideoTile extends StatelessWidget {
  const _SelectedVideoTile({
    required this.file,
    required this.isUploading,
    required this.onRemove,
  });

  final XFile file;
  final bool isUploading;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.sky.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: AppTheme.sky,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(isUploading ? '正在上传参考视频...' : '已选参考视频，可用于复刻节奏。'),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
