import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_chip.dart';
import 'create_controller.dart';

class CreatePage extends GetView<CreateController> {
  const CreatePage({super.key}) : _embedded = false;

  const CreatePage.embedded({super.key}) : _embedded = true;

  final bool _embedded;

  @override
  Widget build(BuildContext context) {
    final Widget content = ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        SectionCard(
          title: '创作内容',
          subtitle: '先输入要表达的话，再交给 AI 生成视频提示词',
          icon: Icons.edit_note_rounded,
          accentColor: AppTheme.coral,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LargeTextField(
                controller: controller.textController,
                label: '想说的内容',
                hintText: '例如：今天给家人送上一句暖心问候',
                minLines: 4,
                maxLines: 6,
              ),
              const SizedBox(height: 14),
              _AdaptiveButtonRow(
                children: <Widget>[
                  Obx(
                    () => PrimaryButton.outline(
                      label: controller.isRecording.value ? '识别中' : '语音输入',
                      icon: controller.isRecording.value
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_none_rounded,
                      onPressed: controller.isRecording.value
                          ? null
                          : controller.toggleRecording,
                    ),
                  ),
                  Obx(
                    () => PrimaryButton.outline(
                      label: controller.isPolishing.value ? '润色中' : 'AI 润色',
                      icon: Icons.auto_fix_high_outlined,
                      onPressed: controller.isPolishing.value
                          ? null
                          : controller.polishText,
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
                              '正在识别语音...',
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
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '最终提示词',
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
                        controller.isGeneratingPrompt.value ? '生成中' : '一键生成',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LargeTextField(
                controller: controller.promptController,
                label: '视频提示词',
                hintText: '例如：大字幕、节奏舒缓、画面稳定',
                minLines: 5,
                maxLines: 7,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '素材与生成',
          subtitle: '设置时长、上传参考图，然后开始生成',
          icon: Icons.movie_creation_outlined,
          accentColor: AppTheme.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '视频时长',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Obx(
                () => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: AppConstants.durations
                      .map(
                        (int duration) => ChoiceChip(
                          label: Text('$duration 秒'),
                          selected:
                              controller.selectedDuration.value == duration,
                          onSelected: (_) =>
                              controller.selectedDuration.value = duration,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
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
                          ? '无需图片'
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
                        '没有参考图也可以直接生成视频',
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
              const SizedBox(height: 18),
              Obx(
                () => PrimaryButton(
                  label: controller.isSubmitting.value
                      ? '生成中，请稍候'
                      : '开始生成视频',
                  icon: Icons.movie_creation_outlined,
                  onPressed: controller.isSubmitting.value
                      ? null
                      : controller.generateVideo,
                ),
              ),
              Obx(
                () => controller.isSubmitting.value
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            LinearProgressIndicator(
                              minHeight: 8,
                              value: controller.generationProgress.value == 0
                                  ? null
                                  : controller.generationProgress.value,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '正在跟进任务进度 ${controller.pollingCount.value}/${AppConstants.maxPollingTimes}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Obx(() {
                final task = controller.currentTask.value;
                if (task == null) {
                  return const SizedBox.shrink();
                }

                final String detailText =
                    task.errorMessage?.trim().isNotEmpty == true
                        ? task.errorMessage!
                        : '任务编号：${task.id}';

                return Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          StatusChip(status: task.status),
                          Text(
                            detailText,
                            style: Theme.of(context).textTheme.bodyMedium,
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
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );

    if (_embedded) {
      return content;
    }

    return AppPageScaffold(
      title: '创建视频',
      subtitle: '一句话生成家庭短视频',
      accentColor: AppTheme.coral,
      child: content,
    );
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
