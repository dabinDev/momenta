import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'video_player_controller.dart';

class VideoPlayerPage extends GetView<VideoPlayerController> {
  const VideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AppPageScaffold(
        title: controller.title.value,
        subtitle: controller.sourceLabel,
        accentColor: AppTheme.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            SectionCard(
              title: '视频预览',
              subtitle: controller.helperText,
              icon: Icons.play_circle_rounded,
              accentColor: AppTheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _PlayerFrame(controller: controller),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          AppTheme.surfaceSky,
                          AppTheme.surfaceJade,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.screen_rotation_alt_rounded,
                            size: 18,
                            color: AppTheme.primaryDeep,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '点击播放器右下角进入全屏后可横屏观看，播放器内支持拖动进度、倍速和系统返回退出全屏。',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.text,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ActionArea(controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerFrame extends StatelessWidget {
  const _PlayerFrame({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFF9DED2),
            Color(0xFFF3F7FF),
            Color(0xFFF4FBF7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: controller.aspectRatio.value,
          child: ColoredBox(
            color: const Color(0xFF090909),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: controller.isLoading.value
                  ? const _PlayerStatusView(
                      key: ValueKey<String>('loading'),
                      icon: Icons.motion_photos_on_rounded,
                      title: '正在加载视频',
                      message: '播放器已切换为更稳定的预览模式，请稍候。',
                      loading: true,
                    )
                  : controller.errorText.value.isNotEmpty
                      ? _PlayerStatusView(
                          key: const ValueKey<String>('error'),
                          icon: Icons.error_outline_rounded,
                          title: '视频暂时无法播放',
                          message: controller.errorText.value,
                          actionLabel: '重新加载',
                          onAction: controller.initializePlayer,
                        )
                      : controller.hasPlayer
                          ? Chewie(
                              key: const ValueKey<String>('player'),
                              controller: controller.chewieController,
                            )
                          : _PlayerStatusView(
                              key: const ValueKey<String>('empty'),
                              icon: Icons.videocam_off_rounded,
                              title: '没有可播放的视频',
                              message: '当前任务还没有可用的视频文件。',
                              actionLabel: '重新加载',
                              onAction: controller.initializePlayer,
                            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerStatusView extends StatelessWidget {
  const _PlayerStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    )
                  : Icon(icon, size: 30, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (!loading && actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = <Widget>[
      if (controller.canDownload)
        Obx(
          () => PrimaryButton.outline(
            label: controller.isDownloading.value ? '加入下载中...' : '下载到本地',
            icon: controller.isDownloading.value
                ? Icons.downloading_rounded
                : Icons.download_rounded,
            onPressed: controller.isDownloading.value
                ? null
                : controller.downloadCurrentVideo,
          ),
        ),
      if (controller.canSaveToGallery)
        Obx(
          () => PrimaryButton(
            label: controller.isSavingToGallery.value ? '保存中...' : '保存到相册',
            icon: controller.isSavingToGallery.value
                ? Icons.hourglass_top_rounded
                : Icons.photo_library_outlined,
            onPressed: controller.isSavingToGallery.value
                ? null
                : controller.saveToGallery,
          ),
        ),
    ];

    if (actions.isEmpty) {
      return PrimaryButton.outline(
        label: '重新加载',
        icon: Icons.refresh_rounded,
        onPressed: controller.initializePlayer,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (actions.length == 1) {
          return actions.first;
        }
        if (constraints.maxWidth < 360) {
          return Column(
            children: actions
                .expand<Widget>(
                  (Widget item) => <Widget>[
                    item,
                    const SizedBox(height: 10),
                  ],
                )
                .toList()
              ..removeLast(),
          );
        }
        return Row(
          children: actions
              .expand<Widget>(
                (Widget item) => <Widget>[
                  Expanded(child: item),
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
