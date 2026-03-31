import 'package:get/get.dart';

import '../create/create_binding.dart';
import '../history/history_binding.dart';
import '../settings/settings_binding.dart';
import 'main_shell_controller.dart';

class MainShellBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<MainShellController>()) {
      Get.lazyPut<MainShellController>(MainShellController.new);
    }
    CreateBinding().dependencies();
    HistoryBinding().dependencies();
    SettingsBinding().dependencies();
  }
}
