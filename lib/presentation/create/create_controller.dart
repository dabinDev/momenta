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
import '../../core/utils/video_save_helper.dart';
import '../../data/api/api_service.dart';
import '../../data/models/ai_template_model.dart';
import '../../data/models/create_mode_model.dart';
import '../../data/models/create_workbench_model.dart';
import '../../data/models/history_item_model.dart';
import '../../data/models/video_task_model.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/media_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../history/history_controller.dart';

enum CreateWorkbenchMode {
  simple,
  starter,
  custom,
}

extension CreateWorkbenchModeX on CreateWorkbenchMode {
  String get code {
    switch (this) {
      case CreateWorkbenchMode.simple:
        return 'simple';
      case CreateWorkbenchMode.starter:
        return 'starter';
      case CreateWorkbenchMode.custom:
        return 'custom';
    }
  }

  String get fallbackLabel {
    switch (this) {
      case CreateWorkbenchMode.simple:
        return '简单';
      case CreateWorkbenchMode.starter:
        return '入门';
      case CreateWorkbenchMode.custom:
        return '自定义';
    }
  }

  String get fallbackTitle {
    switch (this) {
      case CreateWorkbenchMode.simple:
        return 'AI 快速创作';
      case CreateWorkbenchMode.starter:
        return '链接跟做';
      case CreateWorkbenchMode.custom:
        return '模板复刻';
    }
  }

  String get fallbackSubtitle {
    switch (this) {
      case CreateWorkbenchMode.simple:
        return '保留语音转写、AI 校准、提示词生成和基础成片能力。';
      case CreateWorkbenchMode.starter:
        return '复制公开视频链接，结合上传图片快速生成同主题短视频。';
      case CreateWorkbenchMode.custom:
        return '查看热门模板样片，按模板或参考短视频去复刻成片。';
    }
  }

  List<String> get fallbackHighlights {
    switch (this) {
      case CreateWorkbenchMode.simple:
        return const <String>['语音转文字', 'AI 校准', '少参数'];
      case CreateWorkbenchMode.starter:
        return const <String>['视频链接', '上传图片', '快速跟做'];
      case CreateWorkbenchMode.custom:
        return const <String>['热门模板', '样片预览', '图片和短视频'];
    }
  }

  IconData get icon {
    switch (this) {
      case CreateWorkbenchMode.simple:
        return Icons.auto_awesome_rounded;
      case CreateWorkbenchMode.starter:
        return Icons.link_rounded;
      case CreateWorkbenchMode.custom:
        return Icons.view_in_ar_rounded;
    }
  }

  Color get tint {
    switch (this) {
      case CreateWorkbenchMode.simple:
        return AppTheme.coral;
      case CreateWorkbenchMode.starter:
        return AppTheme.sky;
      case CreateWorkbenchMode.custom:
        return AppTheme.jade;
    }
  }
}

CreateWorkbenchMode? createWorkbenchModeFromCode(String? code) {
  switch ((code ?? '').trim().toLowerCase()) {
    case 'simple':
      return CreateWorkbenchMode.simple;
    case 'starter':
      return CreateWorkbenchMode.starter;
    case 'custom':
      return CreateWorkbenchMode.custom;
  }
  return null;
}

class CreateController extends GetxController {
  CreateController()
      : _mediaRepository = Get.find<MediaRepository>(),
        _videoRepository = Get.find<VideoRepository>(),
        _historyRepository = Get.find<HistoryRepository>(),
        _apiService = Get.find<ApiService>();

  final MediaRepository _mediaRepository;
  final VideoRepository _videoRepository;
  final HistoryRepository _historyRepository;
  final ApiService _apiService;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  final TextEditingController textController = TextEditingController();
  final TextEditingController promptController = TextEditingController();
  final TextEditingController starterLinkController = TextEditingController();

  final Rx<CreateWorkbenchMode> currentMode = CreateWorkbenchMode.simple.obs;
  final RxList<CreateModeModel> modeConfigs = <CreateModeModel>[].obs;
  final RxList<AiTemplateModel> promptTemplates = <AiTemplateModel>[].obs;
  final RxList<AiTemplateModel> videoTemplates = <AiTemplateModel>[].obs;
  final RxList<int> availableDurations =
      List<int>.from(AppConstants.durations).obs;
  final RxList<XFile> selectedImages = <XFile>[].obs;
  final Rxn<XFile> selectedReferenceVideo = Rxn<XFile>();
  final RxList<String> uploadedImagePaths = <String>[].obs;
  final RxnString uploadedReferenceVideoPath = RxnString();
  final RxInt selectedDuration = AppConstants.durations.first.obs;
  final RxnString selectedPromptTemplateKey = RxnString();
  final RxnString selectedVideoTemplateKey = RxnString();
  final RxnString selectedCustomTemplateKey = RxnString();
  final RxBool isLoadingTemplates = false.obs;
  final RxBool isRecording = false.obs;
  final RxBool isTranscribing = false.obs;
  final RxBool isCorrecting = false.obs;
  final RxBool isGeneratingPrompt = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool isUploadingReferenceVideo = false.obs;
  final RxBool isSavingCurrentVideo = false.obs;
  final RxInt recordingSeconds = 0.obs;
  final RxInt pollingCount = 0.obs;
  final RxDouble generationProgress = 0.0.obs;
  final RxString transcribedText = ''.obs;
  final Rxn<VideoTaskModel> currentTask = Rxn<VideoTaskModel>();

  bool _isSpeechDialogVisible = false;
  bool _isApplyingTextChange = false;
  Timer? _recordingTimer;
  Completer<bool>? _speechDecisionCompleter;
  String? _lastRawTextBeforeCorrection;
  String? _lastCorrectedText;

  @override
  void onInit() {
    super.onInit();
    textController.addListener(_handleTextChanged);
    unawaited(loadTemplates());
  }

  @override
  void onClose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    textController.dispose();
    promptController.dispose();
    starterLinkController.dispose();
    super.onClose();
  }

  CreateWorkbenchMode get mode => currentMode.value;

  List<CreateWorkbenchMode> get availableModes {
    final List<CreateWorkbenchMode> items = modeConfigs
        .map((CreateModeModel item) => createWorkbenchModeFromCode(item.code))
        .whereType<CreateWorkbenchMode>()
        .toList();
    return items.isEmpty ? CreateWorkbenchMode.values : items;
  }

  String get modeLabel => labelForMode(mode);

  String get modeTitle => titleForMode(mode);

  String get modeSubtitle => subtitleForMode(mode);

  List<String> get modeHighlights => highlightsForMode(mode);

  CreateModeModel? modeConfigFor(CreateWorkbenchMode mode) =>
      _findModeConfig(mode.code);

  String labelForMode(CreateWorkbenchMode mode) =>
      modeConfigFor(mode)?.label ?? mode.fallbackLabel;

  String titleForMode(CreateWorkbenchMode mode) =>
      modeConfigFor(mode)?.title ?? mode.fallbackTitle;

  String subtitleForMode(CreateWorkbenchMode mode) =>
      modeConfigFor(mode)?.subtitle ?? mode.fallbackSubtitle;

  List<String> highlightsForMode(CreateWorkbenchMode mode) =>
      modeConfigFor(mode)?.highlights ?? mode.fallbackHighlights;

  AiTemplateModel? get selectedPromptTemplate =>
      _findTemplate(promptTemplates, selectedPromptTemplateKey.value);

  AiTemplateModel? get selectedVideoTemplate =>
      _findTemplate(videoTemplates, selectedVideoTemplateKey.value);

  AiTemplateModel? get selectedCustomTemplate =>
      _findTemplate(videoTemplates, selectedCustomTemplateKey.value);

  Future<void> loadTemplates({bool silent = true}) async {
    if (isLoadingTemplates.value) {
      return;
    }

    isLoadingTemplates.value = true;
    try {
      final CreateWorkbenchModel workbench =
          await _videoRepository.fetchCreateWorkbench();
      final CreateWorkbenchMode? defaultMode =
          createWorkbenchModeFromCode(workbench.defaultModeCode);

      modeConfigs.assignAll(workbench.modes);
      promptTemplates.assignAll(workbench.promptTemplates);
      videoTemplates.assignAll(workbench.videoTemplates);
      availableDurations.assignAll(
        workbench.durations.isEmpty
            ? AppConstants.durations
            : workbench.durations,
      );
      final bool currentModeSupported = workbench.modes.any(
        (CreateModeModel item) => item.code.trim().toLowerCase() == mode.code,
      );
      if (!currentModeSupported && defaultMode != null) {
        currentMode.value = defaultMode;
      }
      if (availableDurations.isNotEmpty &&
          !availableDurations.contains(selectedDuration.value)) {
        selectedDuration.value = availableDurations.first;
      }
      _ensureTemplateSelection();
    } catch (error) {
      if (!silent ||
          modeConfigs.isEmpty ||
          promptTemplates.isEmpty ||
          videoTemplates.isEmpty) {
        SnackbarHelper.error(_readError(error, fallback: '读取创作配置失败'));
      }
    } finally {
      isLoadingTemplates.value = false;
    }
  }

  Future<void> refreshTemplates() => loadTemplates(silent: false);

  void setMode(CreateWorkbenchMode mode) {
    currentMode.value = mode;
    _applyModeDefaults(mode);
    _syncDurationForMode(mode);
  }

  void selectPromptTemplate(AiTemplateModel template) {
    selectedPromptTemplateKey.value = template.key;
  }

  void selectVideoTemplate(AiTemplateModel template) {
    selectedVideoTemplateKey.value = template.key;
    final int? defaultDuration = template.defaultDuration;
    if (defaultDuration != null &&
        AppConstants.durations.contains(defaultDuration)) {
      selectedDuration.value = defaultDuration;
    }
  }

  void selectCustomTemplate(AiTemplateModel template) {
    selectedCustomTemplateKey.value = template.key;
    final int? defaultDuration = template.defaultDuration;
    if (defaultDuration != null &&
        AppConstants.durations.contains(defaultDuration)) {
      selectedDuration.value = defaultDuration;
    }
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

  Future<void> pickReferenceVideo() async {
    final XFile? file = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 1),
    );
    if (file == null) {
      return;
    }

    selectedReferenceVideo.value = file;
    uploadedReferenceVideoPath.value = null;
    SnackbarHelper.success('已选择参考短视频');
  }

  void removeReferenceVideo() {
    selectedReferenceVideo.value = null;
    uploadedReferenceVideoPath.value = null;
  }

  Future<void> openTemplatePreview(AiTemplateModel template) async {
    final String url = template.previewVideoUrl?.trim() ?? '';
    if (url.isEmpty) {
      SnackbarHelper.error('该模板暂时没有样片');
      return;
    }

    await Get.toNamed(
      AppRoutes.videoPlayer,
      arguments: <String, dynamic>{
        'url': url,
        'title': '${template.name} 样片',
      },
    );
  }

  Future<void> toggleRecording() async {
    if (isRecording.value || isTranscribing.value) {
      return;
    }

    final bool hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      SnackbarHelper.error('未授予麦克风权限，仍可手动输入文字');
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

  Future<void> correctText() async {
    final String rawText = textController.text.trim();
    if (rawText.isEmpty) {
      SnackbarHelper.error('请先输入或识别文字内容');
      return;
    }

    isCorrecting.value = true;
    try {
      final String corrected =
          (await _videoRepository.correctText(rawText)).trim();
      if (corrected.isEmpty) {
        throw const AppException('AI 校准结果为空，请稍后重试');
      }
      _lastRawTextBeforeCorrection = rawText;
      _lastCorrectedText = corrected;
      _replaceText(corrected);
      SnackbarHelper.success('已完成 AI 校准');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: 'AI 校准失败'));
    } finally {
      isCorrecting.value = false;
    }
  }

  Future<void> buildPrompt() async {
    final String rawText = textController.text.trim();
    if (rawText.isEmpty) {
      SnackbarHelper.error('请先输入或识别文字内容');
      return;
    }

    isGeneratingPrompt.value = true;
    try {
      final String prompt = await _videoRepository.generatePrompt(
        rawText,
        promptTemplateKey: selectedPromptTemplateKey.value,
      );
      promptController.text = prompt;
      SnackbarHelper.success('创作提示词已生成，可继续修改');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '提示词生成失败'));
    } finally {
      isGeneratingPrompt.value = false;
    }
  }

  Future<void> generateVideo() => generateSimpleVideo();

  Future<void> generateSimpleVideo() async {
    final String prompt = promptController.text.trim();
    if (prompt.isEmpty) {
      SnackbarHelper.error('生成视频前请先准备创作提示词');
      return;
    }

    final String currentText = textController.text.trim();
    final String? correctedText = _resolveCorrectedText(currentText);
    final String? inputText = correctedText == null
        ? _normalizeNullableText(currentText)
        : _normalizeNullableText(_lastRawTextBeforeCorrection);

    await _submitVideoTask(
      mode: CreateWorkbenchMode.simple,
      prompt: prompt,
      inputText: inputText,
      polishedText: correctedText,
      promptTemplateKey: selectedPromptTemplateKey.value,
      videoTemplateKey: selectedVideoTemplateKey.value,
    );
  }

  Future<void> generateStarterVideo() async {
    final String link = starterLinkController.text.trim();
    if (!_looksLikeVideoUrl(link)) {
      SnackbarHelper.error('请先输入可访问的视频链接');
      return;
    }
    if (selectedImages.isEmpty) {
      SnackbarHelper.error('入门模式至少上传 1 张图片');
      return;
    }

    final String prompt = promptController.text.trim();
    final String note = textController.text.trim();
    await _submitVideoTask(
      mode: CreateWorkbenchMode.starter,
      prompt: _normalizeNullableText(prompt),
      inputText: _normalizeNullableText(note),
      polishedText: null,
      promptTemplateKey:
          _modeDefaultPromptTemplateKey(CreateWorkbenchMode.starter),
      videoTemplateKey:
          _modeDefaultVideoTemplateKey(CreateWorkbenchMode.starter),
      referenceLink: link,
    );
  }

  Future<void> generateCustomVideo() async {
    final AiTemplateModel? template = selectedCustomTemplate;
    if (template == null) {
      SnackbarHelper.error('请先选择一个热门模板');
      return;
    }
    if (selectedImages.isEmpty) {
      SnackbarHelper.error('自定义模式至少上传 1 张图片');
      return;
    }

    final String prompt = promptController.text.trim();
    final String note = textController.text.trim();
    final String link = starterLinkController.text.trim();
    await _submitVideoTask(
      mode: CreateWorkbenchMode.custom,
      prompt: _normalizeNullableText(prompt),
      inputText: _normalizeNullableText(note),
      polishedText: null,
      promptTemplateKey:
          _modeDefaultPromptTemplateKey(CreateWorkbenchMode.custom),
      videoTemplateKey: template.key,
      referenceLink: _normalizeNullableText(link),
      includeReferenceVideo: true,
    );
  }

  Future<void> _submitVideoTask({
    required CreateWorkbenchMode mode,
    required String? prompt,
    required String? inputText,
    required String? polishedText,
    String? promptTemplateKey,
    String? videoTemplateKey,
    String? referenceLink,
    String? supplementalText,
    bool includeReferenceVideo = false,
  }) async {
    isSubmitting.value = true;
    generationProgress.value = 0;
    pollingCount.value = 0;
    currentTask.value = null;

    try {
      final List<String> images = await _prepareImagesIfNeeded();
      final String? referenceVideoPath =
          includeReferenceVideo ? await _prepareReferenceVideoIfNeeded() : null;

      final VideoTaskModel task;
      switch (mode) {
        case CreateWorkbenchMode.simple:
          task = await _videoRepository.generateSimpleVideo(
            inputText: inputText,
            polishedText: polishedText,
            prompt: prompt!,
            images: images,
            duration: selectedDuration.value,
            promptTemplateKey: promptTemplateKey,
            videoTemplateKey: videoTemplateKey,
          );
          break;
        case CreateWorkbenchMode.starter:
          final String? normalizedReferenceLink =
              _normalizeNullableText(referenceLink);
          if (normalizedReferenceLink == null) {
            throw const AppException('请先输入可访问的视频链接');
          }
          task = await _videoRepository.generateStarterVideo(
            inputText: inputText,
            prompt: prompt,
            images: images,
            duration: selectedDuration.value,
            referenceLink: normalizedReferenceLink,
            promptTemplateKey: promptTemplateKey,
            videoTemplateKey: videoTemplateKey,
            supplementalText: supplementalText,
          );
          break;
        case CreateWorkbenchMode.custom:
          final String? normalizedVideoTemplateKey =
              _normalizeNullableText(videoTemplateKey);
          if (normalizedVideoTemplateKey == null) {
            throw const AppException('请先选择一个热门模板');
          }
          task = await _videoRepository.generateCustomVideo(
            inputText: inputText,
            prompt: prompt,
            images: images,
            duration: selectedDuration.value,
            videoTemplateKey: normalizedVideoTemplateKey,
            promptTemplateKey: promptTemplateKey,
            referenceLink: _normalizeNullableText(referenceLink),
            referenceVideoPath: referenceVideoPath,
            supplementalText: supplementalText,
          );
          break;
      }
      currentTask.value = task;
      await _persistTask(
        task,
        fallbackPrompt: _fallbackPrompt(
          mode: mode,
          prompt: prompt,
          inputText: inputText,
        ),
      );

      if (task.isCompleted && (task.videoUrl?.isNotEmpty ?? false)) {
        _handleCompleted();
        return;
      }
      if (task.id.isEmpty) {
        throw const AppException('未获取到任务编号，请稍后再试');
      }

      await _pollVideoStatus(
        task.id,
        fallbackPrompt: _fallbackPrompt(
          mode: mode,
          prompt: prompt,
          inputText: inputText,
        ),
      );
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '视频生成失败'));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<List<String>> _prepareImagesIfNeeded() async {
    if (selectedImages.isEmpty) {
      uploadedImagePaths.clear();
      return const <String>[];
    }

    final List<File> files =
        selectedImages.map((XFile file) => File(file.path)).toList();
    final uploadedFiles = await _mediaRepository.uploadImages(files);
    uploadedImagePaths.assignAll(uploadedFiles.map((file) => file.path));
    return uploadedImagePaths.toList();
  }

  Future<String?> _prepareReferenceVideoIfNeeded() async {
    final XFile? file = selectedReferenceVideo.value;
    if (file == null) {
      uploadedReferenceVideoPath.value = null;
      return null;
    }
    if (uploadedReferenceVideoPath.value?.isNotEmpty == true) {
      return uploadedReferenceVideoPath.value;
    }

    isUploadingReferenceVideo.value = true;
    try {
      final uploadedFile =
          await _mediaRepository.uploadReferenceVideo(File(file.path));
      uploadedReferenceVideoPath.value = uploadedFile.path;
      return uploadedFile.path;
    } finally {
      isUploadingReferenceVideo.value = false;
    }
  }

  Future<void> _pollVideoStatus(
    String id, {
    required String fallbackPrompt,
  }) async {
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

  Future<void> saveCurrentVideo() async {
    final String videoUrl = FileUtils.resolveUrl(
      AppConstants.serverBaseUrl,
      currentTask.value?.videoUrl,
    );
    if (videoUrl.isEmpty) {
      SnackbarHelper.error('当前没有可保存的视频');
      return;
    }
    if (isSavingCurrentVideo.value) {
      return;
    }

    isSavingCurrentVideo.value = true;
    try {
      await VideoSaveHelper.saveRemoteVideoToGallery(
        apiService: _apiService,
        videoUrl: videoUrl,
      );
      SnackbarHelper.success('视频已保存到系统相册的“拾光视频”中');
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '保存视频失败'),
      );
    } finally {
      isSavingCurrentVideo.value = false;
    }
  }

  void _handleCompleted() {
    generationProgress.value = 1;
    SnackbarHelper.success('视频生成完成，可以立即播放');
    if (Get.isRegistered<HistoryController>()) {
      Get.find<HistoryController>().refreshList();
    }
  }

  Future<void> _persistTask(
    VideoTaskModel task, {
    required String fallbackPrompt,
  }) {
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
    _clearCorrectionDraft();
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
    if (_lastCorrectedText != null && currentText != _lastCorrectedText) {
      _clearCorrectionDraft();
    }
  }

  void _replaceText(String nextText) {
    _isApplyingTextChange = true;
    textController.text = nextText;
    textController.selection = TextSelection.collapsed(offset: nextText.length);
    _isApplyingTextChange = false;
  }

  void _clearCorrectionDraft() {
    _lastRawTextBeforeCorrection = null;
    _lastCorrectedText = null;
  }

  String? _resolveCorrectedText(String currentText) {
    if (_lastCorrectedText == null || currentText != _lastCorrectedText) {
      return null;
    }
    return _normalizeNullableText(_lastCorrectedText);
  }

  String? _normalizeNullableText(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  void _ensureTemplateSelection() {
    final String? promptTemplateKey = _modeDefaultPromptTemplateKey(mode) ??
        _defaultTemplateKey(promptTemplates);
    final String? videoTemplateKey = _defaultTemplateKey(videoTemplates);

    selectedPromptTemplateKey.value ??= promptTemplateKey;
    selectedVideoTemplateKey.value ??=
        _modeDefaultVideoTemplateKey(CreateWorkbenchMode.simple) ??
            videoTemplateKey;
    selectedCustomTemplateKey.value ??=
        _modeDefaultVideoTemplateKey(CreateWorkbenchMode.custom) ??
            videoTemplateKey;
    _applyModeDefaults(mode);

    final AiTemplateModel? template = selectedVideoTemplate;
    final int? defaultDuration = template?.defaultDuration;
    if (defaultDuration != null &&
        availableDurations.contains(defaultDuration) &&
        selectedDuration.value == availableDurations.first) {
      selectedDuration.value = defaultDuration;
    }
  }

  void _applyModeDefaults(CreateWorkbenchMode mode) {
    final String? modePromptTemplateKey = _modeDefaultPromptTemplateKey(mode);
    final String? modeVideoTemplateKey = _modeDefaultVideoTemplateKey(mode);

    if (modePromptTemplateKey != null &&
        mode != CreateWorkbenchMode.simple &&
        selectedPromptTemplateKey.value != modePromptTemplateKey) {
      selectedPromptTemplateKey.value = modePromptTemplateKey;
    } else {
      selectedPromptTemplateKey.value ??=
          modePromptTemplateKey ?? _defaultTemplateKey(promptTemplates);
    }

    switch (mode) {
      case CreateWorkbenchMode.simple:
        selectedVideoTemplateKey.value ??=
            modeVideoTemplateKey ?? _defaultTemplateKey(videoTemplates);
        break;
      case CreateWorkbenchMode.starter:
        if (modeVideoTemplateKey != null) {
          selectedVideoTemplateKey.value = modeVideoTemplateKey;
        }
        break;
      case CreateWorkbenchMode.custom:
        selectedCustomTemplateKey.value ??=
            modeVideoTemplateKey ?? _defaultTemplateKey(videoTemplates);
        break;
    }
  }

  void _syncDurationForMode(CreateWorkbenchMode mode) {
    AiTemplateModel? template;
    switch (mode) {
      case CreateWorkbenchMode.simple:
      case CreateWorkbenchMode.starter:
        template = selectedVideoTemplate;
        break;
      case CreateWorkbenchMode.custom:
        template = selectedCustomTemplate;
        break;
    }
    final int? defaultDuration = template?.defaultDuration;
    if (defaultDuration != null &&
        availableDurations.contains(defaultDuration)) {
      selectedDuration.value = defaultDuration;
    }
  }

  String? _defaultTemplateKey(List<AiTemplateModel> templates) {
    if (templates.isEmpty) {
      return null;
    }
    for (final AiTemplateModel item in templates) {
      if (item.isDefault) {
        return item.key;
      }
    }
    return templates.first.key;
  }

  AiTemplateModel? _findTemplate(
    List<AiTemplateModel> templates,
    String? key,
  ) {
    if (key == null || key.isEmpty) {
      return templates.isEmpty ? null : templates.first;
    }
    for (final AiTemplateModel item in templates) {
      if (item.key == key) {
        return item;
      }
    }
    return templates.isEmpty ? null : templates.first;
  }

  CreateModeModel? _findModeConfig(String code) {
    final String normalizedCode = code.trim().toLowerCase();
    for (final CreateModeModel item in modeConfigs) {
      if (item.code.trim().toLowerCase() == normalizedCode) {
        return item;
      }
    }
    return null;
  }

  String? _modeDefaultPromptTemplateKey(CreateWorkbenchMode mode) =>
      _findModeConfig(mode.code)?.defaultPromptTemplateKey;

  String? _modeDefaultVideoTemplateKey(CreateWorkbenchMode mode) =>
      _findModeConfig(mode.code)?.defaultVideoTemplateKey;

  bool _looksLikeVideoUrl(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        (uri.host.isNotEmpty);
  }

  String _fallbackPrompt({
    required CreateWorkbenchMode mode,
    required String? prompt,
    required String? inputText,
  }) {
    final String? normalizedPrompt = _normalizeNullableText(prompt);
    if (normalizedPrompt != null) {
      return normalizedPrompt;
    }
    final String? normalizedInput = _normalizeNullableText(inputText);
    if (normalizedInput != null) {
      return normalizedInput;
    }
    return titleForMode(mode);
  }

  String _readError(Object error, {required String fallback}) {
    return AppException.resolveMessage(error, fallback: fallback);
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
                            '说完后点“识别文字”即可提交转写',
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
                      label: const Text('识别文字'),
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
