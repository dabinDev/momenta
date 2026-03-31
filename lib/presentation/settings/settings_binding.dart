import 'package:get/get.dart';

import 'settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SettingsController>()) {
      Get.lazyPut<SettingsController>(SettingsController.new, fenix: true);
    }
  }
}
