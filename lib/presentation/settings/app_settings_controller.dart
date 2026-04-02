import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../data/models/app_config_model.dart';
import '../../domain/repositories/config_repository.dart';

class AppSettingsController extends GetxController {
  AppSettingsController() : _configRepository = Get.find<ConfigRepository>();

  final ConfigRepository _configRepository;

  final TextEditingController llmBaseUrlController = TextEditingController();
  final TextEditingController llmApiKeyController = TextEditingController();
  final TextEditingController llmModelController = TextEditingController();
  final TextEditingController videoBaseUrlController = TextEditingController();
  final TextEditingController videoApiKeyController = TextEditingController();
  final TextEditingController videoModelController = TextEditingController();
  final TextEditingController speechBaseUrlController = TextEditingController();
  final TextEditingController speechApiKeyController = TextEditingController();
  final TextEditingController speechModelController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isSyncing = false.obs;
  final RxInt selectedSectionIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadInitialConfig();
  }

  @override
  void onClose() {
    llmBaseUrlController.dispose();
    llmApiKeyController.dispose();
    llmModelController.dispose();
    videoBaseUrlController.dispose();
    videoApiKeyController.dispose();
    videoModelController.dispose();
    speechBaseUrlController.dispose();
    speechApiKeyController.dispose();
    speechModelController.dispose();
    super.onClose();
  }

  Future<void> loadInitialConfig() async {
    isLoading.value = true;
    try {
      final AppConfigModel localConfig =
          await _configRepository.loadLocalConfig();
      _apply(localConfig);

      try {
        final AppConfigModel remoteConfig =
            await _configRepository.fetchRemoteConfig();
        _apply(remoteConfig);
      } catch (_) {
        // Keep local config visible if remote sync is temporarily unavailable.
      }
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '读取设置失败'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshConfig() async {
    isSyncing.value = true;
    try {
      final AppConfigModel remoteConfig =
          await _configRepository.fetchRemoteConfig();
      _apply(remoteConfig);
      SnackbarHelper.success('已同步最新配置');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '同步设置失败'));
    } finally {
      isSyncing.value = false;
    }
  }

  void restoreDefaults() {
    _apply(AppConfigModel.defaults());
    SnackbarHelper.info('已恢复默认配置，保存后生效');
  }

  void switchSection(int index) {
    selectedSectionIndex.value = index;
  }

  Future<void> save() async {
    final AppConfigModel config = AppConfigModel(
      llmBaseUrl: llmBaseUrlController.text.trim(),
      llmApiKey: llmApiKeyController.text.trim(),
      llmModel: llmModelController.text.trim(),
      videoBaseUrl: videoBaseUrlController.text.trim(),
      videoApiKey: videoApiKeyController.text.trim(),
      videoModel: videoModelController.text.trim(),
      speechBaseUrl: speechBaseUrlController.text.trim(),
      speechApiKey: speechApiKeyController.text.trim(),
      speechModel: speechModelController.text.trim(),
    );

    if (config.llmBaseUrl.isEmpty || config.llmModel.isEmpty) {
      SnackbarHelper.error('请先完善文案服务配置');
      return;
    }
    if (config.videoBaseUrl.isEmpty || config.videoModel.isEmpty) {
      SnackbarHelper.error('请先完善视频服务配置');
      return;
    }
    if (config.speechBaseUrl.isEmpty || config.speechModel.isEmpty) {
      SnackbarHelper.error('请先完善语音服务配置');
      return;
    }

    isSaving.value = true;
    try {
      final AppConfigModel savedConfig =
          await _configRepository.saveConfig(config);
      _apply(savedConfig);
      SnackbarHelper.success('设置已保存');
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '保存设置失败'));
    } finally {
      isSaving.value = false;
    }
  }

  void _apply(AppConfigModel config) {
    llmBaseUrlController.text = config.llmBaseUrl;
    llmApiKeyController.text = config.llmApiKey;
    llmModelController.text = config.llmModel;
    videoBaseUrlController.text = config.videoBaseUrl;
    videoApiKeyController.text = config.videoApiKey;
    videoModelController.text = config.videoModel;
    speechBaseUrlController.text = config.speechBaseUrl;
    speechApiKeyController.text = config.speechApiKey;
    speechModelController.text = config.speechModel;
  }

  String _readError(Object error, {required String fallback}) {
    return AppException.resolveMessage(error, fallback: fallback);
  }
}
