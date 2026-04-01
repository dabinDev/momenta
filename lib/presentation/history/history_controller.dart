import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/constants.dart';
import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../data/api/api_service.dart';
import '../../data/models/history_item_model.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/video_repository.dart';

class HistoryController extends GetxController {
  HistoryController()
      : _historyRepository = Get.find<HistoryRepository>(),
        _videoRepository = Get.find<VideoRepository>(),
        _apiService = Get.find<ApiService>();

  final HistoryRepository _historyRepository;
  final VideoRepository _videoRepository;
  final ApiService _apiService;

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

  @override
  void onInit() {
    super.onInit();
    loadHistory(reset: true);
  }

  Future<void> refreshList() async {
    await loadHistory(reset: true);
  }

  Future<void> loadHistory({bool reset = false}) async {
    if (reset) {
      isLoading.value = true;
      page.value = 1;
      hasMore.value = true;
      await _refreshProcessingItems();
    } else {
      if (isLoadingMore.value || !hasMore.value) {
        return;
      }
      isLoadingMore.value = true;
    }

    try {
      await _loadSummary();
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
    final String videoUrl =
        FileUtils.resolveUrl(AppConstants.serverBaseUrl, item.videoUrl);
    if (videoUrl.isEmpty) {
      SnackbarHelper.error('该记录还没有可播放的视频');
      return;
    }
    Get.toNamed(
      AppRoutes.videoPlayer,
      arguments: <String, dynamic>{
        'url': videoUrl,
        'title': '历史视频播放',
      },
    );
  }

  Future<void> downloadItem(HistoryItemModel item) async {
    final String videoUrl =
        FileUtils.resolveUrl(AppConstants.serverBaseUrl, item.videoUrl);
    if (videoUrl.isEmpty) {
      SnackbarHelper.error('该记录没有可下载的视频地址');
      return;
    }

    try {
      final Directory baseDir = await getApplicationDocumentsDirectory();
      final File file = File(
        p.join(
          baseDir.path,
          'downloads',
          'history_${item.id}_${DateTime.now().millisecondsSinceEpoch}.mp4',
        ),
      );
      await FileUtils.ensureParentDirectory(file);
      final File downloaded = await _apiService.downloadVideo(
        url: videoUrl,
        savePath: file.path,
      );
      SnackbarHelper.success('视频已保存到：${downloaded.path}');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '下载失败'));
    }
  }

  Future<void> _refreshProcessingItems() async {
    isRefreshingProcessing.value = true;
    try {
      final List<HistoryItemModel> all = await _historyRepository.allItems();
      for (final HistoryItemModel item
          in all.where((HistoryItemModel element) => element.isProcessing)) {
        try {
          final status = await _videoRepository.videoStatus(item.id);
          await _historyRepository.upsert(
            item.copyWith(
              status: status.status,
              prompt: (status.prompt?.trim().isNotEmpty ?? false)
                  ? status.prompt
                  : item.prompt,
              videoUrl: status.videoUrl ?? item.videoUrl,
              errorMessage: status.errorMessage ?? item.errorMessage,
              duration: status.duration ?? item.duration,
            ),
          );
        } catch (_) {
          // Keep local status when remote refresh fails.
        }
      }
    } finally {
      isRefreshingProcessing.value = false;
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
    if (error is AppException) {
      return error.message;
    }
    return error.toString().isEmpty ? fallback : error.toString();
  }
}
