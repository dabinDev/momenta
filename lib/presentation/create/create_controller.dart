import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/constants.dart';
import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../data/models/history_item_model.dart';
import '../../data/models/video_task_model.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/media_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../history/history_controller.dart';

class CreateController extends GetxController {
  CreateController()
      : _mediaRepository = Get.find<MediaRepository>(),
        _videoRepository = Get.find<VideoRepository>(),
        _historyRepository = Get.find<HistoryRepository>();

  static const MethodChannel _speechChannel =
      MethodChannel('com.dabindev.momenta/speech');

  final MediaRepository _mediaRepository;
  final VideoRepository _videoRepository;
  final HistoryRepository _historyRepository;
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController textController = TextEditingController();
  final TextEditingController promptController = TextEditingController();

  final RxList<XFile> selectedImages = <XFile>[].obs;
  final RxList<String> uploadedImagePaths = <String>[].obs;
  final RxInt selectedDuration = AppConstants.durations.first.obs;
  final RxBool isRecording = false.obs;
  final RxBool isTranscribing = false.obs;
  final RxBool isPolishing = false.obs;
  final RxBool isGeneratingPrompt = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxInt pollingCount = 0.obs;
  final RxDouble generationProgress = 0.0.obs;
  final RxString transcribedText = ''.obs;
  final Rxn<VideoTaskModel> currentTask = Rxn<VideoTaskModel>();

  bool _isSpeechDialogVisible = false;

  @override
  void onClose() {
    textController.dispose();
    promptController.dispose();
    super.onClose();
  }

  Future<void> pickImages() async {
    final List<XFile> files = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      limit: AppConstants.maxImages,
    );
    if (files.isEmpty) {
      return;
    }
    final List<XFile> combined = <XFile>[...selectedImages, ...files];
    if (combined.length > AppConstants.maxImages) {
      SnackbarHelper.error('最多只能上传 ${AppConstants.maxImages} 张参考图');
      return;
    }
    selectedImages.assignAll(combined);
    uploadedImagePaths.clear();
    SnackbarHelper.success('已选择 ${selectedImages.length} 张参考图');
  }

  void removeImage(XFile file) {
    selectedImages.remove(file);
    uploadedImagePaths.clear();
  }

  Future<void> toggleRecording() async {
    if (isRecording.value) {
      return;
    }
    if (!Platform.isAndroid) {
      SnackbarHelper.error('当前仅支持安卓端语音输入');
      return;
    }

    final PermissionStatus status = await Permission.microphone.request();
    if (!status.isGranted) {
      SnackbarHelper.error('未授予麦克风权限，仍可手动输入');
      return;
    }

    isRecording.value = true;
    isTranscribing.value = true;
    _showSpeechDialog();

    try {
      final String? text =
          await _speechChannel.invokeMethod<String>('startSpeechToText');
      final String recognizedText = text?.trim() ?? '';
      if (recognizedText.isEmpty) {
        SnackbarHelper.error('没有识别到语音，请再试一次');
        return;
      }

      transcribedText.value = recognizedText;
      textController.text = recognizedText;
      textController.selection =
          TextSelection.collapsed(offset: recognizedText.length);
      SnackbarHelper.success('语音已转成文字');
    } on PlatformException catch (error) {
      if (error.code != 'cancelled') {
        SnackbarHelper.error(_readSpeechError(error));
      }
    } finally {
      _closeSpeechDialog();
      isRecording.value = false;
      isTranscribing.value = false;
    }
  }

  Future<void> cancelSpeechRecognition() async {
    try {
      await _speechChannel.invokeMethod<void>('cancelSpeechToText');
    } catch (_) {
      // Ignore local cancel errors.
    }
  }

  Future<void> finishSpeechRecognition() async {
    try {
      await _speechChannel.invokeMethod<void>('stopSpeechToText');
    } catch (_) {
      // Ignore local stop errors.
    }
  }

  Future<void> polishText() async {
    final String rawText = textController.text.trim();
    if (rawText.isEmpty) {
      SnackbarHelper.error('请先输入文案内容');
      return;
    }
    isPolishing.value = true;
    try {
      final String polished = await _videoRepository.polishText(rawText);
      textController.text = polished;
      SnackbarHelper.success('文案已完成 AI 润色');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '文案润色失败'));
    } finally {
      isPolishing.value = false;
    }
  }

  Future<void> buildPrompt() async {
    final String rawText = textController.text.trim();
    if (rawText.isEmpty) {
      SnackbarHelper.error('请先输入或识别文案');
      return;
    }
    isGeneratingPrompt.value = true;
    try {
      final String prompt = await _videoRepository.generatePrompt(rawText);
      promptController.text = prompt;
      SnackbarHelper.success('提示词已生成，可继续修改');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '提示词生成失败'));
    } finally {
      isGeneratingPrompt.value = false;
    }
  }

  Future<void> generateVideo() async {
    final String prompt = promptController.text.trim();
    if (prompt.isEmpty) {
      SnackbarHelper.error('生成视频前请先准备提示词');
      return;
    }

    isSubmitting.value = true;
    generationProgress.value = 0;
    pollingCount.value = 0;
    currentTask.value = null;

    try {
      if (selectedImages.isNotEmpty) {
        final List<File> files =
            selectedImages.map((XFile file) => File(file.path)).toList();
        final uploadedFiles = await _mediaRepository.uploadImages(files);
        uploadedImagePaths.assignAll(uploadedFiles.map((file) => file.path));
      } else {
        uploadedImagePaths.clear();
      }

      final VideoTaskModel task = await _videoRepository.generateVideo(
        prompt: prompt,
        images: uploadedImagePaths.toList(),
        duration: selectedDuration.value,
      );
      currentTask.value = task;
      await _persistTask(task, fallbackPrompt: prompt);

      if (task.isCompleted && (task.videoUrl?.isNotEmpty ?? false)) {
        _handleCompleted();
        return;
      }
      if (task.id.isEmpty) {
        throw const AppException('未获取到任务编号，请稍后再试');
      }

      await _pollVideoStatus(task.id, fallbackPrompt: prompt);
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '视频生成失败'));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _pollVideoStatus(String id,
      {required String fallbackPrompt}) async {
    for (int index = 1; index <= AppConstants.maxPollingTimes; index++) {
      pollingCount.value = index;
      generationProgress.value = index / AppConstants.maxPollingTimes;
      await Future<void>.delayed(
          const Duration(seconds: AppConstants.pollingIntervalSeconds));

      final VideoTaskModel status = await _videoRepository.videoStatus(id);
      currentTask.value = status;
      await _persistTask(status, fallbackPrompt: fallbackPrompt);

      if (status.isCompleted && (status.videoUrl?.isNotEmpty ?? false)) {
        _handleCompleted();
        return;
      }
      if (status.isFailed) {
        SnackbarHelper.error(status.errorMessage ?? '视频生成失败，请稍后重试');
        if (Get.isRegistered<HistoryController>()) {
          await Get.find<HistoryController>().refreshList();
        }
        return;
      }
    }

    SnackbarHelper.error('视频生成超时，请稍后去历史记录查看');
    if (Get.isRegistered<HistoryController>()) {
      await Get.find<HistoryController>().refreshList();
    }
  }

  void openCurrentVideo() {
    final String videoUrl = FileUtils.resolveUrl(
      AppConstants.serverBaseUrl,
      currentTask.value?.videoUrl,
    );
    if (videoUrl.isEmpty) {
      SnackbarHelper.error('当前没有可播放的视频');
      return;
    }
    Get.toNamed(
      AppRoutes.videoPlayer,
      arguments: <String, dynamic>{
        'url': videoUrl,
        'title': '生成结果预览',
      },
    );
  }

  void _handleCompleted() {
    generationProgress.value = 1;
    SnackbarHelper.success('视频生成完成，可立即播放');
    if (Get.isRegistered<HistoryController>()) {
      Get.find<HistoryController>().refreshList();
    }
  }

  Future<void> _persistTask(VideoTaskModel task,
      {required String fallbackPrompt}) {
    if (task.id.isEmpty) {
      return Future<void>.value();
    }
    return _historyRepository.upsert(
      HistoryItemModel(
        id: task.id,
        status: task.status,
        prompt: (task.prompt?.trim().isNotEmpty ?? false)
            ? task.prompt!.trim()
            : fallbackPrompt,
        videoUrl: task.videoUrl,
        errorMessage: task.errorMessage,
        duration: task.duration ?? selectedDuration.value,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _showSpeechDialog() {
    _isSpeechDialogVisible = true;
    Get.dialog<void>(
      const _SpeechListeningDialog(),
      barrierDismissible: false,
      useSafeArea: true,
    );
  }

  void _closeSpeechDialog() {
    if (!_isSpeechDialogVisible) {
      return;
    }
    _isSpeechDialogVisible = false;
    final BuildContext? overlayContext = Get.overlayContext;
    if (overlayContext == null) {
      return;
    }
    final NavigatorState navigator =
        Navigator.of(overlayContext, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void markSpeechDialogClosed() {
    _isSpeechDialogVisible = false;
  }

  String _readError(Object error, {required String fallback}) {
    if (error is AppException) {
      return error.message;
    }
    return error.toString().isEmpty ? fallback : error.toString();
  }

  String _readSpeechError(PlatformException error) {
    switch (error.code) {
      case 'unavailable':
        return '当前手机没有可用的语音识别服务';
      case 'busy':
        return '语音识别正在进行中';
      case 'no_match':
        return '没有识别到清晰语音，请重试';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!
            : '语音识别失败，请稍后重试';
    }
  }
}

class _SpeechListeningDialog extends StatelessWidget {
  const _SpeechListeningDialog();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CreateController controller = Get.find<CreateController>();

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF2F6E7C), Color(0xFFE28A45)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.mic_none_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '正在聆听',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '请直接说话，识别完成后会自动填入文案。',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const LinearProgressIndicator(minHeight: 8),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    controller.markSpeechDialogClosed();
                    Navigator.of(context, rootNavigator: true).pop();
                    controller.finishSpeechRecognition();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('说完了'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    controller.markSpeechDialogClosed();
                    Navigator.of(context, rootNavigator: true).pop();
                    controller.cancelSpeechRecognition();
                  },
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('取消'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
