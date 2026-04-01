import 'package:get/get.dart';

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
  final Rxn<AppUpdateInfoModel> latestUpdateInfo = Rxn<AppUpdateInfoModel>();

  String get versionLabel =>
      'V${AppConstants.appVersion} (${AppConstants.appBuildNumber})';

  @override
  void onInit() {
    super.onInit();
    refreshProfile();
    Future<void>.microtask(() => checkForUpdates(silent: true));
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
        final String suffix = info.isForceUpdate ? '，建议立即更新' : '';
        SnackbarHelper.success(
          '发现新版本：${info.latest!.versionLabel}$suffix',
          title: '版本更新',
        );
        return;
      }

      SnackbarHelper.info(
        '当前已是最新版本：$versionLabel',
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
}
