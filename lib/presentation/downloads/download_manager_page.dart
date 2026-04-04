import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/models/download_task_record_model.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import 'download_manager_controller.dart';

class DownloadManagerPage extends GetView<DownloadManagerController> {
  const DownloadManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '下载管理',
      subtitle: '查看下载进度、本地文件和失败重试',
      accentColor: AppTheme.jade,
      actions: <Widget>[
        IconButton(
          tooltip: '刷新',
          onPressed: controller.refreshList,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Obx(() {
        return RefreshIndicator(
          onRefresh: controller.refreshList,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              SectionCard(
                title: '下载概览',
                subtitle: '下载中的任务会自动刷新进度，失败后可直接重试',
                icon: Icons.download_done_rounded,
                accentColor: AppTheme.jade,
                child: _SummaryRow(controller: controller),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '下载列表',
                subtitle: controller.items.isEmpty
                    ? '还没有本地下载记录'
                    : '共 ${controller.items.length} 条下载记录',
                icon: Icons.video_library_outlined,
                accentColor: AppTheme.sky,
                child: controller.items.isEmpty
                    ? const EmptyState(
                        title: '暂无下载记录',
                        subtitle: '生成完成后点击“下载到本地”，这里会显示下载进度和本地文件。',
                      )
                    : Column(
                        children: <Widget>[
                          for (int index = 0;
                              index < controller.items.length;
                              index++) ...<Widget>[
                            if (index > 0)
                              Divider(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            _DownloadItemCard(
                              item: controller.items[index],
                              controller: controller,
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.controller});

  final DownloadManagerController controller;

  @override
  Widget build(BuildContext context) {
    final List<_SummaryChipMeta> chips = <_SummaryChipMeta>[
      _SummaryChipMeta(
        label: '下载中',
        value: controller.downloadManager.downloadingCount,
        color: AppTheme.sky,
      ),
      _SummaryChipMeta(
        label: '已完成',
        value: controller.downloadManager.completedCount,
        color: AppTheme.jade,
      ),
      _SummaryChipMeta(
        label: '失败',
        value: controller.downloadManager.failedCount,
        color: AppTheme.coral,
      ),
    ];

    return Column(
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: chips
              .map((_SummaryChipMeta chip) => _SummaryChip(chip: chip))
              .toList(),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: controller.downloadManager.completedCount == 0
                ? null
                : controller.clearCompleted,
            icon: const Icon(Icons.delete_sweep_rounded),
            label: const Text('清理已完成'),
          ),
        ),
      ],
    );
  }
}

class _SummaryChipMeta {
  const _SummaryChipMeta({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.chip});

  final _SummaryChipMeta chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 94),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: chip.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            chip.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: chip.color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${chip.value}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.text,
                ),
          ),
        ],
      ),
    );
  }
}

class _DownloadItemCard extends StatelessWidget {
  const _DownloadItemCard({
    required this.item,
    required this.controller,
  });

  final DownloadTaskRecordModel item;
  final DownloadManagerController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool fileExists =
        item.savePath.trim().isNotEmpty && File(item.savePath).existsSync();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.displayTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '任务编号：${item.taskId}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _DownloadStatusChip(item: item),
            ],
          ),
          const SizedBox(height: 12),
          if (item.isDownloading) ...<Widget>[
            LinearProgressIndicator(
              value: item.progress > 0 ? item.progress : null,
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              item.progress > 0
                  ? '下载中 ${(item.progress * 100).toStringAsFixed(0)}%'
                  : '正在准备下载…',
              style: theme.textTheme.bodyMedium,
            ),
          ] else ...<Widget>[
            Text(
              '更新时间：${DateFormat('yyyy-MM-dd HH:mm').format(item.updatedAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (item.isCompleted) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                fileExists ? '已保存到：${item.savePath}' : '本地文件已丢失，请重新下载',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                item.fileSize == null
                    ? '文件大小：--'
                    : '文件大小：${_readableFileSize(item.fileSize!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (item.isFailed && item.errorMessage?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  item.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.coral,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (item.isCompleted && fileExists)
                _ActionButton(
                  icon: Icons.play_circle_outline,
                  label: '播放',
                  onTap: () => controller.playItem(item),
                ),
              if (item.isCompleted && fileExists)
                _ActionButton(
                  icon: Icons.photo_library_outlined,
                  label: '保存到相册',
                  onTap: () => controller.saveToGallery(item),
                ),
              if (item.isFailed)
                _ActionButton(
                  icon: Icons.refresh_rounded,
                  label: '重新下载',
                  onTap: () => controller.retryItem(item),
                ),
              _ActionButton(
                icon: Icons.delete_outline,
                label: '删除记录',
                tint: AppTheme.coral,
                onTap: item.isDownloading
                    ? null
                    : () => controller.deleteItem(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _readableFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DownloadStatusChip extends StatelessWidget {
  const _DownloadStatusChip({required this.item});

  final DownloadTaskRecordModel item;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;

    if (item.isDownloading) {
      color = AppTheme.sky;
      label = '下载中';
    } else if (item.isCompleted) {
      color = AppTheme.jade;
      label = '已完成';
    } else {
      color = AppTheme.coral;
      label = '失败';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint = AppTheme.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: onTap == null ? 0.06 : 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon,
                  size: 18, color: onTap == null ? AppTheme.muted : tint),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onTap == null ? AppTheme.muted : tint,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
