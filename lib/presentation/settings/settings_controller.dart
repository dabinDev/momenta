import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/constants.dart';
import '../../app/routes.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../data/api/api_service.dart';
import '../../data/models/app_update_info_model.dart';
import '../auth/auth_controller.dart';

class SettingsController extends GetxController {
  SettingsController()
      : authController = Get.find<AuthController>(),
        _apiService = Get.find<ApiService>();

  final AuthController authController;
  final ApiService _apiService;

  final RxBool isLoading = false.obs;
  final RxBool isCheckingUpdate = false.obs;
  final RxBool isOpeningUpdateUrl = false.obs;
  final Rxn<AppUpdateInfoModel> latestUpdateInfo = Rxn<AppUpdateInfoModel>();

  String get versionLabel =>
      'V${AppConstants.appVersion} (${AppConstants.appBuildNumber})';

  @override
  void onInit() {
    super.onInit();
    refreshProfile();
  }

  Future<void> refreshProfile() async {
    isLoading.value = true;
    try {
      if (authController.isLoggedIn) {
        await authController.refreshCurrentUser(silent: true);
      }
    } finally {
      isLoading.value = false;
    }
  }

  void openAppSettings() {
    Get.toNamed(AppRoutes.appSettings);
  }

  void openEditProfile() {
    Get.toNamed(AppRoutes.editProfile);
  }

  void openChangePassword() {
    Get.toNamed(AppRoutes.changePassword);
  }

  void openProfileDetail() {
    Get.toNamed(AppRoutes.profileDetail);
  }

  Future<void> logout() async {
    await authController.logout();
  }

  Future<void> checkForUpdates({bool silent = false}) async {
    isCheckingUpdate.value = true;
    try {
      final AppUpdateInfoModel info = await _apiService.checkAppUpdate();
      latestUpdateInfo.value = info;
      if (silent) {
        return;
      }

      if (info.hasUpdate && info.latest != null) {
        _showUpdateDialog(info);
        return;
      }

      SnackbarHelper.info(
        '当前已经是最新版本：$versionLabel',
        title: '版本更新',
      );
    } catch (_) {
      if (!silent) {
        SnackbarHelper.error('检查更新失败，请稍后重试');
      }
    } finally {
      isCheckingUpdate.value = false;
    }
  }

  Future<void> openUpdateUrl() async {
    final String downloadUrl =
        latestUpdateInfo.value?.latest?.downloadUrl.trim() ?? '';
    if (downloadUrl.isEmpty) {
      SnackbarHelper.error('当前版本尚未配置下载地址');
      return;
    }

    final Uri? uri = Uri.tryParse(downloadUrl);
    if (uri == null) {
      SnackbarHelper.error('下载地址格式无效');
      return;
    }

    isOpeningUpdateUrl.value = true;
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        SnackbarHelper.error('无法打开下载地址，请稍后重试');
      }
    } catch (_) {
      SnackbarHelper.error('打开下载地址失败，请稍后重试');
    } finally {
      isOpeningUpdateUrl.value = false;
    }
  }

  void _showUpdateDialog(AppUpdateInfoModel info) {
    final AppReleaseModel? latest = info.latest;
    if (latest == null) {
      return;
    }

    final bool forceUpdate = info.isForceUpdate;
    final String notes = latest.releaseNotes.trim().isNotEmpty
        ? latest.releaseNotes.trim()
        : AppConstants.updateHint;

    Get.dialog<void>(
      PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          title: Text(forceUpdate ? '发现重要更新' : '发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('最新版本：${latest.versionLabel}'),
              const SizedBox(height: 12),
              Text(latest.title.trim().isEmpty ? '版本说明' : latest.title.trim()),
              const SizedBox(height: 8),
              Text(notes),
            ],
          ),
          actions: <Widget>[
            if (!forceUpdate)
              TextButton(
                onPressed: Get.back,
                child: const Text('稍后再说'),
              ),
            Obx(
              () => FilledButton(
                onPressed: isOpeningUpdateUrl.value
                    ? null
                    : () async {
                        await openUpdateUrl();
                        if (!forceUpdate && Get.isDialogOpen == true) {
                          Get.back<void>();
                        }
                      },
                child: Text(
                  isOpeningUpdateUrl.value ? '打开中...' : '立即更新',
                ),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: !forceUpdate,
    );
  }
}
