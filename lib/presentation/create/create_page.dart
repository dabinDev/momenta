import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/constants.dart';
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: <Widget>[
        SectionCard(
          title: '文案',
          subtitle: '先写清视频要表达的内容。',
          icon: Icons.edit_note_rounded,
          accentColor: const Color(0xFFD46E5E),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LargeTextField(
                controller: controller.textController,
                label: '视频文案',
                hintText: '例如：今天给家人送上一句暖心问候。',
                minLines: 4,
                maxLines: 6,
              ),
              const SizedBox(height: 14),
              Obx(
                () => Row(
                  children: <Widget>[
                    Expanded(
                      child: PrimaryButton.outline(
                        label: controller.isRecording.value ? '识别中' : '语音输入',
                        icon: controller.isRecording.value
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_none_rounded,
                        onPressed: controller.isRecording.value
                            ? null
                            : controller.toggleRecording,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton.outline(
                        label: controller.isPolishing.value ? '润色中' : 'AI 润色',
                        icon: Icons.auto_fix_high_outlined,
                        onPressed: controller.isPolishing.value
                            ? null
                            : controller.polishText,
                      ),
                    ),
                  ],
                ),
              ),
              Obx(
                () => controller.isTranscribing.value
                    ? const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(minHeight: 8),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '提示词',
          subtitle: '生成后再按需要微调。',
          icon: Icons.auto_awesome_rounded,
          accentColor: const Color(0xFF3D7F8C),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Obx(
                () => PrimaryButton.outline(
                  label:
                      controller.isGeneratingPrompt.value ? '生成中' : '一键生成提示词',
                  icon: Icons.auto_awesome_outlined,
                  onPressed: controller.isGeneratingPrompt.value
                      ? null
                      : controller.buildPrompt,
                ),
              ),
              const SizedBox(height: 14),
              LargeTextField(
                controller: controller.promptController,
                label: '提示词 Prompt',
                hintText: '例如：大字字幕，节奏舒缓，画面稳定。',
                minLines: 5,
                maxLines: 7,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '参考图和时长',
          subtitle: '图片最多 3 张，可不上传。',
          icon: Icons.photo_library_outlined,
          accentColor: const Color(0xFF537CC0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('视频时长', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              PrimaryButton.outline(
                label: '上传图片',
                icon: Icons.photo_library_outlined,
                onPressed: controller.pickImages,
              ),
              const SizedBox(height: 14),
              Obx(
                () => controller.selectedImages.isEmpty
                    ? Text(
                        '未上传参考图',
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
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '生成视频',
          subtitle: '点击后会自动刷新当前进度。',
          icon: Icons.movie_creation_outlined,
          accentColor: const Color(0xFFE29A3B),
          child: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PrimaryButton(
                  label: controller.isSubmitting.value ? '生成中，请稍候' : '开始生成视频',
                  icon: Icons.movie_creation_outlined,
                  onPressed: controller.isSubmitting.value
                      ? null
                      : controller.generateVideo,
                ),
                if (controller.isSubmitting.value) ...<Widget>[
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    minHeight: 10,
                    value: controller.generationProgress.value == 0
                        ? null
                        : controller.generationProgress.value,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '进度 ${controller.pollingCount.value}/${AppConstants.maxPollingTimes}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (controller.currentTask.value != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      StatusChip(status: controller.currentTask.value!.status),
                      Text(
                        controller.currentTask.value!.errorMessage
                                    ?.trim()
                                    .isNotEmpty ==
                                true
                            ? controller.currentTask.value!.errorMessage!
                            : '任务编号：${controller.currentTask.value!.id}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (controller.currentTask.value!.isCompleted &&
                      (controller.currentTask.value!.videoUrl?.isNotEmpty ??
                          false)) ...<Widget>[
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
        ),
      ],
    );

    if (_embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('创建视频')),
      body: SafeArea(child: content),
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
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: 108,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(file.path),
                  width: 108,
                  height: 108,
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
                      child: Icon(Icons.close, size: 18),
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
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
