import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/models/history_item_model.dart';
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: <Widget>[
            _HistoryOverviewCard(controller: controller),
            const SizedBox(height: 16),
            _HistoryFilterBar(controller: controller),
            const SizedBox(height: 16),
            if (controller.items.isEmpty)
              const EmptyState(
                title: '还没有历史记录',
                subtitle: '生成完成后，视频任务会按当前账号保存在这里。',
              )
            else
              ...controller.items.map(
                (HistoryItemModel item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _HistoryItemCard(
                    item: item,
                    onPlay: item.isCompleted
                        ? () => controller.playItem(item)
                        : null,
                    onDownload: item.isCompleted
                        ? () => controller.downloadItem(item)
                        : null,
                    onDelete: () => controller.deleteItem(item.id),
                  ),
                ),
              ),
            if (controller.items.isNotEmpty)
              _LoadMoreArea(controller: controller),
          ],
        ),
      );
    });

    if (_embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: SafeArea(child: content),
    );
  }
}

class _HistoryOverviewCard extends StatelessWidget {
  const _HistoryOverviewCard({required this.controller});

  final HistoryController controller;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '历史记录管理',
      subtitle:
          controller.isRefreshingProcessing.value ? '正在刷新处理中任务' : '按当前登录账号保存',
      icon: Icons.inventory_2_outlined,
      accentColor: const Color(0xFF4D74B8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: _SummaryTag(
                      label: '全部',
                      value: controller.totalCount.value.toString())),
              const SizedBox(width: 10),
              Expanded(
                  child: _SummaryTag(
                      label: '完成',
                      value: controller.completedCount.value.toString())),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                  child: _SummaryTag(
                      label: '处理中',
                      value: controller.processingCount.value.toString())),
              const SizedBox(width: 10),
              Expanded(
                  child: _SummaryTag(
                      label: '失败',
                      value: controller.failedCount.value.toString())),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton.outline(
                  label: '刷新状态',
                  icon: Icons.refresh_rounded,
                  onPressed: controller.refreshList,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton.outline(
                  label: '清空记录',
                  icon: Icons.delete_sweep_outlined,
                  onPressed: controller.totalCount.value == 0
                      ? null
                      : () => _confirmClearAll(context, controller),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(
      BuildContext context, HistoryController controller) async {
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

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({
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
    final String subtitle = item.createdAt == null
        ? '任务编号：${item.id}'
        : DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt!);

    return SectionCard(
      title: item.displayTitle,
      subtitle: subtitle,
      icon: Icons.history_rounded,
      accentColor: const Color(0xFF4D74B8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusChip(status: item.status),
              if (item.duration != null) ...<Widget>[
                const SizedBox(width: 8),
                _MetaTag(label: '${item.duration} 秒'),
              ],
            ],
          ),
          if (item.errorMessage?.isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 10),
            Text(item.errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton.outline(
                  label: '播放',
                  icon: Icons.play_circle_outline,
                  onPressed: onPlay,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton.outline(
                  label: '下载',
                  icon: Icons.download_outlined,
                  onPressed: onDownload,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton.outline(
                  label: '删除',
                  icon: Icons.delete_outline,
                  onPressed: onDelete,
                ),
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
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge),
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
        color: const Color(0xFFF0E7D8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6D5A45),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              '没有更多记录了',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: PrimaryButton.outline(
          label: '加载更多',
          icon: Icons.expand_more,
          onPressed: () => controller.loadHistory(),
        ),
      );
    });
  }
}
