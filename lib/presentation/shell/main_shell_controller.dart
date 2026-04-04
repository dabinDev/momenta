import 'dart:async';

import 'package:get/get.dart';

import '../create/create_controller.dart';
import '../history/history_controller.dart';
import '../settings/settings_controller.dart';

class MainShellController extends GetxController {
  final RxInt currentIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<SettingsController>()) {
      unawaited(Get.find<SettingsController>().checkForUpdates(silent: true));
    }
  }

  void changeTab(int index) {
    if (index == currentIndex.value) {
      if (index == 0 && Get.isRegistered<CreateController>()) {
        unawaited(Get.find<CreateController>().refreshTemplates());
      }
      if (index == 1 && Get.isRegistered<HistoryController>()) {
        unawaited(Get.find<HistoryController>().refreshList());
      }
      if (index == 2 && Get.isRegistered<SettingsController>()) {
        unawaited(Get.find<SettingsController>().refreshProfile());
      }
      return;
    }

    if (index == 1 && Get.isRegistered<HistoryController>()) {
      unawaited(Get.find<HistoryController>().refreshList());
    }
    if (index == 2 && Get.isRegistered<SettingsController>()) {
      unawaited(Get.find<SettingsController>().refreshProfile());
    }
    currentIndex.value = index;
  }
}
