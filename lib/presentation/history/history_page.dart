import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/models/history_item_model.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_chip.dart';
import 'history_controller.dart';

class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key}) : _embedded = false;

  const HistoryPage.embedded({super.key}) : _embedded = true;

  final bool _embedded;

  @override
  Widget build(BuildContext context) {
    final Widget content = Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return RefreshIndicator(
        onRefresh: controller.refreshList,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            SectionCard(
              title: '历史记录',
              subtitle: controller.items.isEmpty
                  ? '下拉可以刷新'
                  : '共 ${controller.totalCount.value} 条任务记录',
              icon: Icons.history_rounded,
              accentColor: AppTheme.sky,
              child: controller.items.isEmpty
                  ? const EmptyState(
                      title: '还没有历史记录',
                      subtitle: '完成第一条创作后，视频任务会自动保存在这里。',
                    )
                  : Column(
                      children: <Widget>[
                        for (int index = 0;
                            index < controller.items.length;
                            index++) ...<Widget>[
                          if (index > 0)
                            Divider(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          _HistoryListItem(
                            item: controller.items[index],
                            onPlay: controller.items[index].isCompleted
                                ? () => controller.playItem(
                                      controller.items[index],
                                    )
                                : null,
                            onDownload: controller.items[index].isCompleted
                                ? () => controller.downloadItem(
                                      controller.items[index],
                                    )
                                : null,
                            onSaveAlbum: controller.items[index].isCompleted
                                ? () => controller.saveItem(
                                      controller.items[index],
                                    )
                                : null,
                            onRetry: controller.items[index].isFailed
                                ? () => controller.retryItem(
                                      controller.items[index],
                                    )
                                : null,
                            onDelete: () => controller
                                .deleteItem(controller.items[index].id),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _HistoryActionRow(controller: controller),
                        const SizedBox(height: 12),
                        _LoadMoreArea(controller: controller),
                      ],
                    ),
            ),
          ],
        ),
      );
    });

    if (_embedded) {
      return content;
    }

    return AppPageScaffold(
      title: '历史记录',
      subtitle: '查看结果、重新生成和删除任务',
      accentColor: AppTheme.sky,
      child: content,
    );
  }
}

class _HistoryActionRow extends StatelessWidget {
  const _HistoryActionRow({required this.controller});

  final HistoryController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final List<Widget> children = <Widget>[
          PrimaryButton.outline(
            label: '刷新',
            icon: Icons.refresh_rounded,
            onPressed: controller.refreshList,
          ),
          PrimaryButton.outline(
            label: '清空记录',
            icon: Icons.delete_sweep_outlined,
            onPressed: controller.totalCount.value == 0
                ? null
                : () => _confirmClearAll(context, controller),
          ),
        ];

        if (constraints.maxWidth < 360) {
          return Column(
            children: children
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
          children: children
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

  Future<void> _confirmClearAll(
    BuildContext context,
    HistoryController controller,
  ) async {
    final bool? confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确认清空当前账号下的全部历史记录吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.clearAll();
    }
  }
}

class _HistoryListItem extends StatelessWidget {
  const _HistoryListItem({
    required this.item,
    required this.onPlay,
    required this.onDownload,
    required this.onSaveAlbum,
    required this.onRetry,
    required this.onDelete,
  });

  final HistoryItemModel item;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onSaveAlbum;
  final VoidCallback? onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String subtitle = item.createdAt == null
        ? '任务编号: ${item.id}'
        : DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt!);

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
                      subtitle,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (item.duration != null) _MetaTag(label: '${item.duration} 秒'),
              _MetaTag(
                label: item.isCompleted
                    ? '可播放'
                    : item.isFailed
                        ? '已失败'
                        : '等待完成',
              ),
            ],
          ),
          if (item.errorMessage?.isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              item.errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFC35A4E),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              if (item.isCompleted)
                _ActionChipButton(
                  icon: Icons.play_circle_outline,
                  label: '播放',
                  onTap: onPlay,
                ),
              if (item.isCompleted)
                _ActionChipButton(
                  icon: Icons.download_outlined,
                  label: '下载到本地',
                  onTap: onDownload,
                ),
              if (item.isCompleted)
                _ActionChipButton(
                  icon: Icons.photo_library_outlined,
                  label: '保存到相册',
                  onTap: onSaveAlbum,
                ),
              if (item.isFailed)
                _ActionChipButton(
                  icon: Icons.refresh_rounded,
                  label: '重新生成',
                  onTap: onRetry,
                ),
              _ActionChipButton(
                icon: Icons.delete_outline,
                label: '删除',
                onTap: onDelete,
                tint: AppTheme.coral,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.text,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
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
    final bool enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: enabled
                ? tint.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: enabled ? tint : AppTheme.muted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: enabled ? AppTheme.text : AppTheme.muted,
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

class _LoadMoreArea extends StatelessWidget {
  const _LoadMoreArea({required this.controller});

  final HistoryController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingMore.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (!controller.hasMore.value) {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(
            child: Text(
              '没有更多记录了',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      }
      return PrimaryButton.outline(
        label: '加载更多',
        icon: Icons.expand_more,
        onPressed: () => controller.loadHistory(),
      );
    });
  }
}
