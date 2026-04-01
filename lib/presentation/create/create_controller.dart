import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../app/constants.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
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

  final MediaRepository _mediaRepository;
  final VideoRepository _videoRepository;
  final HistoryRepository _historyRepository;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

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
  final RxInt recordingSeconds = 0.obs;
  final RxInt pollingCount = 0.obs;
  final RxDouble generationProgress = 0.0.obs;
  final RxString transcribedText = ''.obs;
  final Rxn<VideoTaskModel> currentTask = Rxn<VideoTaskModel>();

  bool _isSpeechDialogVisible = false;
  bool _isApplyingTextChange = false;
  Timer? _recordingTimer;
  Completer<bool>? _speechDecisionCompleter;
  String? _lastRawTextBeforePolish;
  String? _lastPolishedText;

  @override
  void onInit() {
    super.onInit();
    textController.addListener(_handleTextChanged);
  }

  @override
  void onClose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
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
    if (isRecording.value || isTranscribing.value) {
      return;
    }

    final bool hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      SnackbarHelper.error('未授予麦克风权限，仍可手动输入');
      return;
    }

    _speechDecisionCompleter = Completer<bool>();
    _showSpeechDialog();

    File? audioFile;
    try {
      await _startSpeechRecording();
      final bool shouldTranscribe = await _speechDecisionCompleter!.future;
      audioFile = await _stopSpeechRecording(shouldSave: shouldTranscribe);
      if (audioFile == null) {
        return;
      }

      isTranscribing.value = true;
      final String recognizedText =
          (await _videoRepository.transcribeAudio(audioFile)).trim();
      if (recognizedText.isEmpty) {
        SnackbarHelper.error('没有识别到清晰语音，请重试');
        return;
      }

      transcribedText.value = recognizedText;
      _appendRecognizedText(recognizedText);
      SnackbarHelper.success('语音已转成文字');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '语音识别失败'));
    } finally {
      _recordingTimer?.cancel();
      _speechDecisionCompleter = null;
      recordingSeconds.value = 0;
      isRecording.value = false;
      isTranscribing.value = false;
      _closeSpeechDialog();
      if (audioFile != null) {
        await _clearSpeechTempFile(audioFile.path);
      }
    }
  }

  void cancelSpeechRecognition() {
    final Completer<bool>? completer = _speechDecisionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
    _closeSpeechDialog();
  }

  void finishSpeechRecognition() {
    final Completer<bool>? completer = _speechDecisionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(true);
    }
    _closeSpeechDialog();
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
      _lastRawTextBeforePolish = rawText;
      _lastPolishedText = polished.trim();
      _replaceText(polished);
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

      final String currentText = textController.text.trim();
      final String? polishedText = _resolvePolishedText(currentText);
      final String? inputText = polishedText == null
          ? _normalizeNullableText(currentText)
          : _normalizeNullableText(_lastRawTextBeforePolish);

      final VideoTaskModel task = await _videoRepository.generateVideo(
        inputText: inputText,
        polishedText: polishedText,
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
        const Duration(seconds: AppConstants.pollingIntervalSeconds),
      );

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

  Future<void> _startSpeechRecording() async {
    final Directory directory = await getTemporaryDirectory();
    final String filePath = p.join(
      directory.path,
      'speech_${DateTime.now().millisecondsSinceEpoch}.pcm',
    );

    recordingSeconds.value = 0;
    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.speechSampleRate,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
        ),
      ),
      path: filePath,
    );

    isRecording.value = true;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final int nextValue = recordingSeconds.value + 1;
      recordingSeconds.value = nextValue;
      if (nextValue >= AppConstants.maxSpeechSeconds) {
        timer.cancel();
        finishSpeechRecognition();
      }
    });
  }

  Future<File?> _stopSpeechRecording({required bool shouldSave}) async {
    _recordingTimer?.cancel();
    isRecording.value = false;
    if (!shouldSave) {
      await _audioRecorder.cancel();
      return null;
    }

    final String? path = await _audioRecorder.stop();
    if (path == null || path.isEmpty) {
      throw const AppException('录音文件保存失败，请重试');
    }
    return File(path);
  }

  Future<void> _clearSpeechTempFile(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // Ignore local temp file cleanup failures.
      }
    }
  }

  void _appendRecognizedText(String recognizedText) {
    _clearPolishDraft();
    final String existingText = textController.text.trim();
    final String nextText = existingText.isEmpty
        ? recognizedText
        : '$existingText\n$recognizedText';
    _replaceText(nextText);
  }

  void _showSpeechDialog() {
    _isSpeechDialogVisible = true;
    Get.dialog<void>(
      const _SpeechRecordingDialog(),
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

  String get formattedRecordingTime {
    final int seconds = recordingSeconds.value;
    final int minutes = seconds ~/ 60;
    final int remainder = seconds % 60;
    final String minuteText = minutes.toString().padLeft(2, '0');
    final String secondText = remainder.toString().padLeft(2, '0');
    return '$minuteText:$secondText';
  }

  void _handleTextChanged() {
    if (_isApplyingTextChange) {
      return;
    }
    final String currentText = textController.text.trim();
    if (_lastPolishedText != null && currentText != _lastPolishedText) {
      _clearPolishDraft();
    }
  }

  void _replaceText(String nextText) {
    _isApplyingTextChange = true;
    textController.text = nextText;
    textController.selection = TextSelection.collapsed(offset: nextText.length);
    _isApplyingTextChange = false;
  }

  void _clearPolishDraft() {
    _lastRawTextBeforePolish = null;
    _lastPolishedText = null;
  }

  String? _resolvePolishedText(String currentText) {
    if (_lastPolishedText == null || currentText != _lastPolishedText) {
      return null;
    }
    return _normalizeNullableText(_lastPolishedText);
  }

  String? _normalizeNullableText(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  String _readError(Object error, {required String fallback}) {
    if (error is AppException) {
      return error.message;
    }
    return error.toString().isEmpty ? fallback : error.toString();
  }
}

class _SpeechRecordingDialog extends StatelessWidget {
  const _SpeechRecordingDialog();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CreateController controller = Get.find<CreateController>();

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Obx(() {
          final double progress = (controller.recordingSeconds.value /
                  AppConstants.maxSpeechSeconds)
              .clamp(0, 1)
              .toDouble();

          return Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.mic_rounded,
                        size: 32,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '正在录音',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '说完后点“说完了”即可识别',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '${controller.formattedRecordingTime} / 01:00',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 18),
                Column(
                  children: <Widget>[
                    ElevatedButton.icon(
                      onPressed: controller.finishSpeechRecognition,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('说完了'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: controller.cancelSpeechRecognition,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('取消'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
