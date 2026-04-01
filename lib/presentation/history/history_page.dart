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
              subtitle: controller.isRefreshingProcessing.value
                  ? '正在刷新处理中任务'
                  : '生成结果会自动按当前账号保存',
              icon: Icons.inventory_2_outlined,
              accentColor: AppTheme.sky,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _SummaryTag(
                        label: '全部',
                        value: controller.totalCount.value.toString(),
                        tint: AppTheme.primary,
                      ),
                      _SummaryTag(
                        label: '完成',
                        value: controller.completedCount.value.toString(),
                        tint: AppTheme.jade,
                      ),
                      _SummaryTag(
                        label: '处理中',
                        value: controller.processingCount.value.toString(),
                        tint: AppTheme.amber,
                      ),
                      _SummaryTag(
                        label: '失败',
                        value: controller.failedCount.value.toString(),
                        tint: AppTheme.coral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _HistoryFilterBar(controller: controller),
                  const SizedBox(height: 16),
                  _AdaptiveOverviewActions(controller: controller),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: '任务列表',
              subtitle: controller.items.isEmpty
                  ? '还没有视频任务'
                  : '共 ${controller.items.length} 条已加载记录',
              icon: Icons.list_alt_rounded,
              accentColor: AppTheme.primary,
              child: controller.items.isEmpty
                  ? const EmptyState(
                      title: '还没有历史记录',
                      subtitle: '完成第一次创作后，视频任务会自动保存在这里。',
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
                            onDelete: () =>
                                controller.deleteItem(controller.items[index].id),
                          ),
                        ],
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
      subtitle: '查看结果、下载和删除任务',
      accentColor: AppTheme.sky,
      child: content,
    );
  }
}

class _AdaptiveOverviewActions extends StatelessWidget {
  const _AdaptiveOverviewActions({required this.controller});

  final HistoryController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final List<Widget> buttons = <Widget>[
          PrimaryButton.outline(
            label: '刷新状态',
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

        return Row(
          children: buttons
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

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({required this.controller});

  final HistoryController controller;

  @override
  Widget build(BuildContext context) {
    const List<Map<String, String>> filters = <Map<String, String>>[
      <String, String>{'label': '全部', 'value': 'all'},
      <String, String>{'label': '处理中', 'value': 'processing'},
      <String, String>{'label': '已完成', 'value': 'completed'},
      <String, String>{'label': '失败', 'value': 'failed'},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: filters.map((Map<String, String> item) {
        final bool selected = controller.selectedFilter.value == item['value'];
        return ChoiceChip(
          label: Text(item['label']!),
          selected: selected,
          onSelected: (_) => controller.changeFilter(item['value']!),
        );
      }).toList(),
    );
  }
}

class _HistoryListItem extends StatelessWidget {
  const _HistoryListItem({
    required this.item,
    required this.onPlay,
    required this.onDownload,
    required this.onDelete,
  });

  final HistoryItemModel item;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String subtitle = item.createdAt == null
        ? '任务编号：${item.id}'
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
              _MetaTag(label: item.isCompleted ? '可播放' : '等待完成'),
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
              _ActionChipButton(
                icon: Icons.play_circle_outline,
                label: '播放',
                onTap: onPlay,
              ),
              _ActionChipButton(
                icon: Icons.download_outlined,
                label: '下载',
                onTap: onDownload,
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

class _SummaryTag extends StatelessWidget {
  const _SummaryTag({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.text,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.text,
                ),
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
