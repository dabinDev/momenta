import 'dart:io';

import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/download_manager_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/video_save_helper.dart';
import '../../data/models/download_task_record_model.dart';

class VideoPlayerController extends GetxController {
  VideoPlayerController()
      : _downloadManager = Get.find<DownloadManagerService>();

  final DownloadManagerService _downloadManager;

  final RxString title = '视频预览'.obs;
  final RxBool isDownloading = false.obs;
  final RxBool isSavingToGallery = false.obs;
  final RxString localPath = ''.obs;

  String taskId = '';
  String _remoteUrl = '';
  Worker? _downloadWorker;

  String get remoteUrl => _remoteUrl;

  bool get hasLocalCopy {
    final String path = localPath.value.trim();
    return path.isNotEmpty && File(path).existsSync();
  }

  bool get canDownload => taskId.trim().isNotEmpty && !hasLocalCopy;

  bool get canSaveToGallery => hasLocalCopy;

  String get sourceLabel => hasLocalCopy ? '本地高清预览' : '云端视频预览';

  String get helperText => hasLocalCopy
      ? '当前已切换为本地视频，预览会更稳定，也可以直接保存到相册。'
      : '当前正在播放云端视频，如网络波动较大，建议先下载到本地后再观看。';

  @override
  void onInit() {
    super.onInit();
    final Map<String, dynamic> args =
        Get.arguments as Map<String, dynamic>? ?? <String, dynamic>{};
    title.value = (args['title'] ?? '视频预览').toString();
    taskId = (args['taskId'] ?? '').toString();
    _remoteUrl = (args['url'] ?? '').toString();
    localPath.value = (args['localPath'] ?? '').toString();
    _syncLocalCopy();
    _downloadWorker = ever<List<DownloadTaskRecordModel>>(
      _downloadManager.items,
      (_) => _syncLocalCopy(),
    );
  }

  void _syncLocalCopy() {
    if (taskId.trim().isEmpty) {
      return;
    }
    final String nextPath =
        _downloadManager.completedForTask(taskId)?.savePath.trim() ?? '';
    if (nextPath == localPath.value.trim()) {
      return;
    }
    localPath.value = nextPath;
  }

  Future<void> downloadCurrentVideo() async {
    if (!canDownload) {
      SnackbarHelper.info('当前视频已经下载到本地');
      return;
    }
    if (isDownloading.value) {
      return;
    }
    if (_downloadManager.latestForTask(taskId)?.isDownloading == true) {
      SnackbarHelper.info('当前视频已在下载中，可到下载管理查看进度');
      return;
    }

    isDownloading.value = true;
    try {
      await _downloadManager.startTaskDownload(
        taskId: taskId,
        title: title.value,
      );
      SnackbarHelper.info('已加入下载队列，下载完成后会自动切换为本地播放');
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '加入下载队列失败'),
      );
    } finally {
      isDownloading.value = false;
    }
  }

  Future<void> saveToGallery() async {
    final String path = localPath.value.trim();
    if (path.isEmpty) {
      SnackbarHelper.error('请先把视频下载到本地，再保存到相册');
      return;
    }
    if (isSavingToGallery.value) {
      return;
    }

    isSavingToGallery.value = true;
    try {
      await VideoSaveHelper.saveLocalVideoToGallery(filePath: path);
      SnackbarHelper.success('视频已保存到系统相册');
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '保存到相册失败'),
      );
    } finally {
      isSavingToGallery.value = false;
    }
  }

  void openDownloadManager() {
    Get.toNamed(AppRoutes.downloadManager);
  }

  @override
  void onClose() {
    _downloadWorker?.dispose();
    super.onClose();
  }
}
