import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../core/errors/app_exception.dart';
import '../../core/services/download_manager_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/video_save_helper.dart';

class VideoPlayerController extends GetxController {
  VideoPlayerController()
      : _downloadManager = Get.find<DownloadManagerService>();

  final DownloadManagerService _downloadManager;

  final RxBool isLoading = true.obs;
  final RxString title = '视频播放'.obs;
  final RxString errorText = ''.obs;
  final RxBool isDownloading = false.obs;
  final RxBool isSavingToGallery = false.obs;
  final RxBool isLocalSource = false.obs;
  final RxDouble aspectRatio = (16 / 9).obs;

  String taskId = '';
  String localPath = '';
  String _remoteUrl = '';

  vp.VideoPlayerController? _playerController;
  ChewieController? _chewieController;

  bool get hasPlayer => _playerController != null && _chewieController != null;

  ChewieController get chewieController => _chewieController!;

  bool get canDownload => taskId.trim().isNotEmpty && !isLocalSource.value;

  bool get canSaveToGallery =>
      isLocalSource.value && localPath.trim().isNotEmpty;

  String get sourceLabel => isLocalSource.value ? '本地视频预览' : '云端视频预览';

  String get helperText => isLocalSource.value
      ? '支持全屏横屏播放，也可以直接保存到系统相册。'
      : '支持全屏横屏播放，可下载到本地后再保存到系统相册。';

  @override
  void onInit() {
    super.onInit();
    final Map<String, dynamic> args =
        Get.arguments as Map<String, dynamic>? ?? <String, dynamic>{};
    title.value = (args['title'] ?? '视频播放').toString();
    taskId = (args['taskId'] ?? '').toString();
    localPath = (args['localPath'] ?? '').toString();
    _remoteUrl = (args['url'] ?? '').toString();
    if (localPath.trim().isEmpty && taskId.trim().isNotEmpty) {
      localPath = _downloadManager.completedForTask(taskId)?.savePath ?? '';
    }
    unawaited(initializePlayer());
  }

  Future<void> initializePlayer() async {
    isLoading.value = true;
    errorText.value = '';
    await _disposePlayer();

    final vp.VideoPlayerController? sourceController =
        await _buildVideoSourceController();
    if (sourceController == null) {
      isLoading.value = false;
      return;
    }

    _playerController = sourceController;

    try {
      await sourceController.initialize();
      final double resolvedAspectRatio = sourceController.value.aspectRatio;
      aspectRatio.value =
          resolvedAspectRatio.isFinite && resolvedAspectRatio > 0
              ? resolvedAspectRatio
              : 16 / 9;

      _chewieController = ChewieController(
        videoPlayerController: sourceController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        allowedScreenSleep: false,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFF06E42),
          handleColor: const Color(0xFFF4B651),
          bufferedColor: const Color(0x995D8DF7),
          backgroundColor: const Color(0x33FFFFFF),
        ),
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFF06E42),
          handleColor: const Color(0xFFF4B651),
          bufferedColor: const Color(0x995D8DF7),
          backgroundColor: const Color(0x33FFFFFF),
        ),
        optionsTranslation: OptionsTranslation(
          playbackSpeedButtonText: '播放速度',
          subtitlesButtonText: '字幕',
          cancelButtonText: '取消',
        ),
        deviceOrientationsOnEnterFullScreen: const <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: const <DeviceOrientation>[
          DeviceOrientation.portraitUp,
        ],
        systemOverlaysOnEnterFullScreen: const <SystemUiOverlay>[],
        systemOverlaysAfterFullScreen: SystemUiOverlay.values,
      );
    } catch (_) {
      errorText.value = '视频加载失败，请稍后重试';
      SnackbarHelper.error(errorText.value);
      await _disposePlayer();
    } finally {
      isLoading.value = false;
    }
  }

  Future<vp.VideoPlayerController?> _buildVideoSourceController() async {
    if (localPath.trim().isNotEmpty) {
      final File file = File(localPath);
      if (!file.existsSync()) {
        errorText.value = '本地视频文件不存在，请重新下载';
        return null;
      }
      isLocalSource.value = true;
      return vp.VideoPlayerController.file(file);
    }

    final String url = _remoteUrl.trim();
    if (url.isEmpty) {
      errorText.value = '视频地址为空';
      return null;
    }

    isLocalSource.value = false;
    return vp.VideoPlayerController.networkUrl(Uri.parse(url));
  }

  Future<void> _disposePlayer() async {
    final ChewieController? chewieController = _chewieController;
    final vp.VideoPlayerController? playerController = _playerController;
    _chewieController = null;
    _playerController = null;

    await chewieController?.pause();
    chewieController?.dispose();
    await playerController?.dispose();

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> downloadCurrentVideo() async {
    if (!canDownload) {
      SnackbarHelper.info('当前视频已经是本地文件');
      return;
    }
    if (isDownloading.value) {
      return;
    }
    if (_downloadManager.latestForTask(taskId)?.isDownloading == true) {
      SnackbarHelper.info('当前视频已在下载中，可在下载管理查看进度');
      return;
    }

    isDownloading.value = true;
    try {
      await _downloadManager.startTaskDownload(
        taskId: taskId,
        title: title.value,
      );
      SnackbarHelper.info('已加入下载队列，可在下载管理查看进度');
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '加入下载队列失败'),
      );
    } finally {
      isDownloading.value = false;
    }
  }

  Future<void> saveToGallery() async {
    if (!canSaveToGallery) {
      SnackbarHelper.error('当前没有可保存的视频');
      return;
    }
    if (isSavingToGallery.value) {
      return;
    }

    isSavingToGallery.value = true;
    try {
      await VideoSaveHelper.saveLocalVideoToGallery(filePath: localPath);
      SnackbarHelper.success('视频已保存到系统相册');
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '保存到相册失败'),
      );
    } finally {
      isSavingToGallery.value = false;
    }
  }

  @override
  void onClose() {
    unawaited(_disposePlayer());
    super.onClose();
  }
}
