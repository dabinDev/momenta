import 'dart:async';

import 'package:get/get.dart';

import '../../app/constants.dart';
import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/download_manager_service.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/video_save_helper.dart';
import '../../data/api/api_service.dart';
import '../../data/models/history_item_model.dart';
import '../../data/models/video_task_model.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../auth/auth_controller.dart';

class HistoryController extends GetxController {
  HistoryController()
      : _historyRepository = Get.find<HistoryRepository>(),
        _videoRepository = Get.find<VideoRepository>(),
        _apiService = Get.find<ApiService>(),
        _downloadManager = Get.find<DownloadManagerService>();

  final HistoryRepository _historyRepository;
  final VideoRepository _videoRepository;
  final ApiService _apiService;
  final DownloadManagerService _downloadManager;

  final RxList<HistoryItemModel> items = <HistoryItemModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxBool isRefreshingProcessing = false.obs;
  final RxInt page = 1.obs;
  final RxInt totalCount = 0.obs;
  final RxInt completedCount = 0.obs;
  final RxInt processingCount = 0.obs;
  final RxInt failedCount = 0.obs;
  final RxString selectedFilter = 'all'.obs;
  Timer? _processingPollTimer;
  bool _processingPollInFlight = false;

  @override
  void onInit() {
    super.onInit();
    loadHistory(reset: true);
  }

  @override
  void onClose() {
    _stopProcessingPolling();
    super.onClose();
  }

  Future<void> refreshList() async {
    if (isLoading.value) {
      return;
    }
    await loadHistory(reset: true);
  }

  Future<void> loadHistory({bool reset = false}) async {
    if (reset) {
      isLoading.value = true;
      page.value = 1;
      hasMore.value = true;
    } else {
      if (isLoadingMore.value || !hasMore.value) {
        return;
      }
      isLoadingMore.value = true;
    }

    try {
      final result = await _historyRepository.list(
        page: page.value,
        limit: AppConstants.historyPageSize,
        filter: selectedFilter.value,
      );
      if (reset) {
        items.assignAll(result.items);
      } else {
        items.addAll(result.items);
      }
      hasMore.value = items.length < result.total && result.items.isNotEmpty;
      if (hasMore.value) {
        page.value = page.value + 1;
      }
      try {
        await _loadSummary();
      } catch (_) {
        // Keep the last summary snapshot when the stats request fails.
      }
      _syncProcessingPolling();
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '获取历史记录失败'));
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _historyRepository.remove(id);
      items.removeWhere((HistoryItemModel item) => item.id == id);
      await _loadSummary();
      hasMore.value = items.length < totalCount.value;
      SnackbarHelper.success('历史记录已删除');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '删除失败'));
    }
  }

  Future<void> clearAll() async {
    try {
      await _historyRepository.clear();
      items.clear();
      totalCount.value = 0;
      completedCount.value = 0;
      processingCount.value = 0;
      failedCount.value = 0;
      hasMore.value = false;
      page.value = 1;
      SnackbarHelper.success('历史记录已清空');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '清空失败'));
    }
  }

  void changeFilter(String filter) {
    if (selectedFilter.value == filter) {
      return;
    }
    selectedFilter.value = filter;
    loadHistory(reset: true);
  }

  void playItem(HistoryItemModel item) {
    final String localPath =
        _downloadManager.completedForTask(item.id)?.savePath ?? '';
    final String videoUrl =
        FileUtils.resolveUrl(AppConstants.serverBaseUrl, item.videoUrl);
    if (localPath.isEmpty && videoUrl.isEmpty) {
      SnackbarHelper.error('该记录还没有可播放的视频');
      return;
    }
    Get.toNamed(
      AppRoutes.videoPlayer,
      arguments: <String, dynamic>{
        if (localPath.isNotEmpty) 'localPath': localPath,
        if (videoUrl.isNotEmpty) 'url': videoUrl,
        'title': '历史视频播放',
        'taskId': item.id,
      },
    );
  }

  Future<void> saveItem(HistoryItemModel item) async {
    if (!item.isCompleted) {
      SnackbarHelper.error('该记录没有可保存的视频');
      return;
    }

    try {
      await VideoSaveHelper.saveTaskVideoToGallery(
        apiService: _apiService,
        taskId: item.id,
        fileNamePrefix: '历史视频',
      );
      SnackbarHelper.success('视频已保存到系统相册');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '保存视频失败'));
    }
  }

  Future<void> downloadItem(HistoryItemModel item) async {
    if (!item.isCompleted) {
      SnackbarHelper.error('该记录没有可下载的视频');
      return;
    }
    if (_downloadManager.latestForTask(item.id)?.isDownloading == true) {
      SnackbarHelper.info('该记录已在下载中，可在下载管理查看进度');
      return;
    }

    try {
      await _downloadManager.startTaskDownload(
        taskId: item.id,
        title: item.displayTitle,
      );
      SnackbarHelper.info('已加入下载队列，可在下载管理查看进度');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '加入下载队列失败'));
    }
  }

  Future<void> retryItem(HistoryItemModel item) async {
    if (!item.isFailed) {
      return;
    }

    try {
      final VideoTaskModel task = await _apiService.retryTask(item.id);
      final HistoryItemModel updated = item.copyWith(
        status: task.status,
        videoUrl: task.videoUrl,
        errorMessage: task.errorMessage,
        duration: task.duration,
        pointsCost: task.pointsCost,
        pointsRefunded: task.pointsRefunded,
      );
      await _historyRepository.upsert(updated);
      final int index =
          items.indexWhere((HistoryItemModel value) => value.id == item.id);
      if (index >= 0) {
        items[index] = updated;
      }
      _syncProcessingPolling();
      await _refreshPointsBalance();
      await _loadSummary();
      SnackbarHelper.success('已重新提交该任务');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '重新生成失败'));
    }
  }

  Future<void> _refreshProcessingItems({
    List<HistoryItemModel>? items,
  }) async {
    isRefreshingProcessing.value = true;
    bool shouldRefreshListForFilter = false;
    bool shouldRefreshUser = false;
    try {
      final Iterable<HistoryItemModel> processingItems =
          (items ?? this.items.toList())
              .where((HistoryItemModel element) => element.isProcessing);
      for (final HistoryItemModel item in processingItems) {
        try {
          final status = await _videoRepository.videoStatus(item.id);
          final HistoryItemModel updated = item.copyWith(
            status: status.status,
            prompt: (status.prompt?.trim().isNotEmpty ?? false)
                ? status.prompt
                : item.prompt,
            displayText: (status.displayText?.trim().isNotEmpty ?? false)
                ? status.displayText
                : item.displayText,
            videoUrl: status.videoUrl ?? item.videoUrl,
            errorMessage: status.errorMessage ?? item.errorMessage,
            duration: status.duration ?? item.duration,
            pointsCost: status.pointsCost,
            pointsRefunded: status.pointsRefunded,
          );
          await _historyRepository.upsert(updated);
          if (item.status != updated.status &&
              (updated.isCompleted || updated.isFailed)) {
            shouldRefreshUser = true;
          }
          final int index = this
              .items
              .indexWhere((HistoryItemModel element) => element.id == item.id);
          if (index >= 0) {
            if (selectedFilter.value == 'processing' && !updated.isProcessing) {
              this.items.removeAt(index);
              shouldRefreshListForFilter = true;
            } else {
              this.items[index] = updated;
            }
          }
        } catch (_) {
          // Keep local status when remote refresh fails.
        }
      }
    } finally {
      isRefreshingProcessing.value = false;
    }
    if (shouldRefreshUser) {
      await _refreshPointsBalance();
    }
    _syncProcessingPolling();
    if (shouldRefreshListForFilter &&
        selectedFilter.value == 'processing' &&
        !isLoading.value) {
      await loadHistory(reset: true);
      return;
    }
    try {
      await _loadSummary();
    } catch (_) {
      // Ignore transient summary failures during polling.
    }
  }

  Future<void> _loadSummary() async {
    final Map<String, int> summary = await _historyRepository.summary();
    totalCount.value = summary['total'] ?? 0;
    completedCount.value = summary['completed'] ?? 0;
    processingCount.value = summary['processing'] ?? 0;
    failedCount.value = summary['failed'] ?? 0;
  }

  String _readError(Object error, {required String fallback}) {
    return AppException.resolveMessage(error, fallback: fallback);
  }

  Future<void> _refreshPointsBalance() async {
    if (!Get.isRegistered<AuthController>()) {
      return;
    }
    await Get.find<AuthController>().refreshCurrentUser(silent: true);
  }

  void _syncProcessingPolling() {
    if (items.any((HistoryItemModel item) => item.isProcessing)) {
      _startProcessingPolling();
      return;
    }
    _stopProcessingPolling();
  }

  void _startProcessingPolling() {
    if (_processingPollTimer != null) {
      return;
    }
    _processingPollTimer = Timer.periodic(
      const Duration(seconds: AppConstants.pollingIntervalSeconds),
      (_) => unawaited(_pollVisibleProcessingItems()),
    );
  }

  void _stopProcessingPolling() {
    _processingPollTimer?.cancel();
    _processingPollTimer = null;
  }

  Future<void> _pollVisibleProcessingItems() async {
    if (_processingPollInFlight ||
        isLoading.value ||
        isLoadingMore.value ||
        isRefreshingProcessing.value) {
      return;
    }
    final List<HistoryItemModel> processingItems = items
        .where((HistoryItemModel item) => item.isProcessing)
        .toList(growable: false);
    if (processingItems.isEmpty) {
      _stopProcessingPolling();
      return;
    }

    _processingPollInFlight = true;
    try {
      await _refreshProcessingItems(items: processingItems);
    } finally {
      _processingPollInFlight = false;
    }
  }
}
