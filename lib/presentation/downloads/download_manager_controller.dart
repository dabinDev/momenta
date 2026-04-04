import 'dart:io';

import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/download_manager_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/video_save_helper.dart';
import '../../data/models/download_task_record_model.dart';

class DownloadManagerController extends GetxController {
  final DownloadManagerService downloadManager =
      Get.find<DownloadManagerService>();

  RxList<DownloadTaskRecordModel> get items => downloadManager.items;

  Future<void> refreshList() async {
    downloadManager.reload();
  }

  void playItem(DownloadTaskRecordModel item) {
    if (!item.isCompleted) {
      SnackbarHelper.error('当前任务还没有可播放的视频');
      return;
    }
    final File file = File(item.savePath);
    if (!file.existsSync()) {
      SnackbarHelper.error('本地文件不存在，请重新下载');
      return;
    }

    Get.toNamed(
      AppRoutes.videoPlayer,
      arguments: <String, dynamic>{
        'title': item.displayTitle,
        'localPath': item.savePath,
      },
    );
  }

  Future<void> saveToGallery(DownloadTaskRecordModel item) async {
    if (!item.isCompleted) {
      SnackbarHelper.error('当前任务还没有可保存的视频');
      return;
    }

    try {
      await VideoSaveHelper.saveLocalVideoToGallery(filePath: item.savePath);
      SnackbarHelper.success('视频已保存到系统相册');
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '保存到相册失败'),
      );
    }
  }

  Future<void> retryItem(DownloadTaskRecordModel item) async {
    try {
      await downloadManager.retryDownload(item);
      SnackbarHelper.info('已重新加入下载队列');
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '重新下载失败'),
      );
    }
  }

  Future<void> deleteItem(DownloadTaskRecordModel item) async {
    try {
      await downloadManager.removeRecord(item);
      SnackbarHelper.success('下载记录已删除');
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '删除下载记录失败'),
      );
    }
  }

  Future<void> clearCompleted() async {
    try {
      await downloadManager.clearCompleted();
      SnackbarHelper.success('已清理完成的下载记录');
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '清理下载记录失败'),
      );
    }
  }
}
