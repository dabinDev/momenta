import 'package:get/get.dart';

import '../../app/constants.dart';
import '../../app/routes.dart';
import '../../core/utils/snackbar_helper.dart';
import '../auth/auth_controller.dart';

class SettingsController extends GetxController {
  SettingsController() : authController = Get.find<AuthController>();

  final AuthController authController;

  final RxBool isLoading = false.obs;
  final RxBool isCheckingUpdate = false.obs;

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

  Future<void> logout() async {
    await authController.logout();
  }

  Future<void> checkForUpdates() async {
    isCheckingUpdate.value = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      SnackbarHelper.info(
        '当前安装版本为 $versionLabel。${AppConstants.updateHint}',
        title: '版本更新',
      );
    } finally {
      isCheckingUpdate.value = false;
    }
  }
}
