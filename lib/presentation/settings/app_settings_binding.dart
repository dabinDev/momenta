import 'package:get/get.dart';

import 'app_settings_controller.dart';

class AppSettingsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AppSettingsController>()) {
      Get.lazyPut<AppSettingsController>(AppSettingsController.new,
          fenix: true);
    }
  }
}
