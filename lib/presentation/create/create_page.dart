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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
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
        title: 'AI创作',
        subtitle: controller.modeLabel,
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
    return Column(
      children: <Widget>[
        SectionCard(
          title: '创作内容',
          subtitle: _contentSubtitle(mode),
          icon: Icons.edit_note_rounded,
          accentColor: mode.tint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LargeTextField(
                controller: controller.textController,
                label: '输入内容',
                hintText: _contentHint(mode),
                minLines: 4,
                maxLines: 6,
              ),
              if (mode != CreateWorkbenchMode.simple) ...<Widget>[
                const SizedBox(height: 14),
                LargeTextField(
                  controller: controller.starterLinkController,
                  label: '链接地址',
                  hintText: '例如：https://www.douyin.com/...',
                  minLines: 2,
                  maxLines: 2,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                ),
              ],
              const SizedBox(height: 14),
              _ActionButtonGrid(controller: controller),
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
              const SizedBox(height: 18),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 18),
              Text(
                '英文提示词',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '提示词生成会输出英文视频模型提示词，你可以继续手动调整。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              LargeTextField(
                controller: controller.promptController,
                label: '视频提示词',
                hintText:
                    '例如：Warm family moment, cozy indoor lighting, natural expressions, clean subtitles, stable vertical framing.',
                minLines: 5,
                maxLines: 7,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '素材与生成',
          subtitle: _assetsSubtitle(mode),
          icon: Icons.movie_creation_outlined,
          accentColor: AppTheme.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (mode == CreateWorkbenchMode.custom) ...<Widget>[
                Obx(
                  () => _TemplateGallery(
                    templates: controller.videoTemplates,
                    selectedKey: controller.selectedCustomTemplateKey.value,
                    isLoading: controller.isLoadingTemplates.value,
                    onRefresh: controller.refreshTemplates,
                    onSelected: controller.selectCustomTemplate,
                    onPreview: controller.openTemplatePreview,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              _DurationSelector(controller: controller),
              const SizedBox(height: 18),
              _ImageUploadPanel(controller: controller),
              if (_supportsReferenceVideo(controller, mode)) ...<Widget>[
                const SizedBox(height: 18),
                _ReferenceVideoPanel(controller: controller),
              ],
              const SizedBox(height: 18),
              _SubmitPanel(
                controller: controller,
                label: _submitLabel(mode),
                onPressed: () {
                  switch (mode) {
                    case CreateWorkbenchMode.simple:
                      return controller.generateSimpleVideo();
                    case CreateWorkbenchMode.starter:
                      return controller.generateStarterVideo();
                    case CreateWorkbenchMode.custom:
                      return controller.generateCustomVideo();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _contentSubtitle(CreateWorkbenchMode mode) {
    switch (mode) {
      case CreateWorkbenchMode.simple:
        return '先输入内容，再完成语音转文字、AI校验和英文提示词生成。';
      case CreateWorkbenchMode.starter:
        return '在简单模式基础上补充视频链接地址，用于入门跟做。';
      case CreateWorkbenchMode.custom:
        return '在入门模式基础上增加模板选择，按模板生成目标视频。';
    }
  }

  static String _assetsSubtitle(CreateWorkbenchMode mode) {
    switch (mode) {
      case CreateWorkbenchMode.simple:
        return '上传最多 3 张图片，选择视频时长后直接发起生成。';
      case CreateWorkbenchMode.starter:
        return '链接、图片和提示词会一起提交给后端生成入门视频。';
      case CreateWorkbenchMode.custom:
        return '选择模板后，结合链接、图片和提示词生成自定义视频。';
    }
  }

  static String _contentHint(CreateWorkbenchMode mode) {
    switch (mode) {
      case CreateWorkbenchMode.simple:
        return '例如：帮我做一条适合给家人分享的温暖短视频。';
      case CreateWorkbenchMode.starter:
        return '例如：参考目标视频的节奏，生成同主题但更适合老年用户观看的版本。';
      case CreateWorkbenchMode.custom:
        return '例如：保留模板的镜头节奏和字幕风格，替换成我上传的人物和场景。';
    }
  }

  static String _submitLabel(CreateWorkbenchMode mode) {
    switch (mode) {
      case CreateWorkbenchMode.simple:
        return '生成视频';
      case CreateWorkbenchMode.starter:
        return '生成入门视频';
      case CreateWorkbenchMode.custom:
        return '生成模板视频';
    }
  }
  static bool _supportsReferenceVideo(
    CreateController controller,
    CreateWorkbenchMode mode,
  ) {
    if (mode != CreateWorkbenchMode.custom) {
      return false;
    }
    final bool? manifestValue =
        controller.modeConfigFor(mode)?.supportsReferenceVideo;
    return manifestValue ?? true;
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

class _ActionButtonGrid extends StatelessWidget {
  const _ActionButtonGrid({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double itemWidth = constraints.maxWidth < 560
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            SizedBox(
              width: itemWidth,
              child: Obx(
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
            ),
            SizedBox(
              width: itemWidth,
              child: Obx(
                () => PrimaryButton.outline(
                  label: controller.isCorrecting.value ? '校验中' : 'AI校验',
                  icon: Icons.spellcheck_rounded,
                  onPressed: controller.isCorrecting.value
                      ? null
                      : controller.correctText,
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: Obx(
                () => PrimaryButton.outline(
                  label: controller.isGeneratingPrompt.value ? '生成中' : '生成提示词',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: controller.isGeneratingPrompt.value
                      ? null
                      : controller.buildPrompt,
                ),
              ),
            ),
          ],
        );
      },
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
          Text(
            '暂时没有可用模板，请刷新后重试。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
                '模板选择',
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
      if (template.supportsReferenceImage) '支持图片',
      if (template.supportsReferenceLink) '支持链接',
      if (template.supportsReferenceVideo) '支持视频',
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
          Text(
            template.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '参考图片',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '最多 ${AppConstants.maxImages} 张',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '3 个上传入口横向排布，点击空位可继续补图。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Obx(() {
          final List<XFile> files = controller.selectedImages.toList();
          return Row(
            children: List<Widget>.generate(
              AppConstants.maxImages,
              (int index) {
                final XFile? file = index < files.length ? files[index] : null;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == AppConstants.maxImages - 1 ? 0 : 12,
                    ),
                    child: _ImageUploadSlot(
                      file: file,
                      index: index,
                      onTap: controller.pickImages,
                      onRemove: file == null
                          ? null
                          : () => controller.removeImage(file),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class _ImageUploadSlot extends StatelessWidget {
  const _ImageUploadSlot({
    required this.file,
    required this.index,
    required this.onTap,
    required this.onRemove,
  });

  final XFile? file;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final bool hasFile = file != null;

    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasFile ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasFile
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : AppTheme.outline.withValues(alpha: 0.8),
              ),
            ),
            child: hasFile
                ? Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(
                          File(file!.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.9),
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
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppTheme.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '图片 ${index + 1}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceVideoPanel extends StatelessWidget {
  const _ReferenceVideoPanel({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final XFile? file = controller.selectedReferenceVideo.value;
      final bool isUploading = controller.isUploadingReferenceVideo.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '参考短视频',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '可选，最长 1 分钟',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '自定义模式可额外上传一段参考短视频，后端会结合模板和图片一起解析节奏与结构。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.outline.withValues(alpha: 0.78),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  file == null ? '尚未选择参考短视频' : file.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  isUploading
                      ? '正在上传参考短视频...'
                      : file == null
                          ? '上传后会在生成时自动提交 reference_video_path。'
                          : '已选择参考短视频，生成时会自动上传并传给后端。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                _AdaptiveButtonRow(
                  children: <Widget>[
                    PrimaryButton.outline(
                      label: file == null ? '选择短视频' : '重新选择',
                      icon: Icons.video_library_outlined,
                      onPressed: isUploading ? null : controller.pickReferenceVideo,
                    ),
                    PrimaryButton.outline(
                      label: '移除短视频',
                      icon: Icons.delete_outline,
                      onPressed:
                          file == null || isUploading ? null : controller.removeReferenceVideo,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    });
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
            label: controller.isSubmitting.value ? '生成中，请稍候' : label,
            icon: Icons.movie_creation_outlined,
            onPressed: controller.isSubmitting.value ? null : onPressed,
          ),
        ),
        const SizedBox(height: 14),
        _CurrentTaskStatusPanel(controller: controller),
      ],
    );
  }
}

// ignore: unused_element
class _TaskStatusPanel extends StatelessWidget {
  const _TaskStatusPanel({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final VideoTaskModel? task = controller.currentTask.value;
      final bool showProgress = controller.isSubmitting.value;
      final bool canPreview =
          task?.isCompleted == true && (task?.videoUrl?.isNotEmpty ?? false);
      if (!showProgress && task == null) {
        return const SizedBox.shrink();
      }

      return GestureDetector(
        onTap: canPreview ? controller.openCurrentVideo : null,
        child: Container(
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
        ),
      );
    });
  }
}

class _CurrentTaskStatusPanel extends StatelessWidget {
  const _CurrentTaskStatusPanel({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final VideoTaskModel? task = controller.currentTask.value;
      final bool showProgress = controller.isSubmitting.value;
      final bool canPreview =
          task?.isCompleted == true && (task?.videoUrl?.isNotEmpty ?? false);
      if (!showProgress && task == null) {
        return const SizedBox.shrink();
      }

      return GestureDetector(
        onTap: canPreview ? controller.openCurrentVideo : null,
        child: Container(
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
                  _AdaptiveButtonRow(
                    children: <Widget>[
                      PrimaryButton.outline(
                        label: '播放结果',
                        icon: Icons.play_circle_outline,
                        onPressed: controller.openCurrentVideo,
                      ),
                      PrimaryButton.outline(
                        label: controller.isSavingCurrentVideo.value
                            ? '保存中'
                            : '保存到相册',
                        icon: Icons.download_rounded,
                        onPressed: controller.isSavingCurrentVideo.value
                            ? null
                            : controller.saveCurrentVideo,
                      ),
                    ],
                  ),
                ],
                if (task.isFailed) ...<Widget>[
                  const SizedBox(height: 14),
                  _AdaptiveButtonRow(
                    children: <Widget>[
                      PrimaryButton.outline(
                        label: '重新生成',
                        icon: Icons.refresh_rounded,
                        onPressed: controller.retryCurrentTask,
                      ),
                      PrimaryButton.outline(
                        label: '删除任务',
                        icon: Icons.delete_outline,
                        onPressed: controller.deleteCurrentTask,
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
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
