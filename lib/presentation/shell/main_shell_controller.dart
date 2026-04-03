import 'dart:async';

import 'package:get/get.dart';

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
    if (index == 1 && Get.isRegistered<HistoryController>()) {
      unawaited(Get.find<HistoryController>().refreshList());
    }
    currentIndex.value = index;
  }
}
