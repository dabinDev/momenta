import 'dart:async';

import 'package:get/get.dart';

import '../history/history_controller.dart';

class MainShellController extends GetxController {
  final RxInt currentIndex = 0.obs;

  void changeTab(int index) {
    if (index == 1 && Get.isRegistered<HistoryController>()) {
      unawaited(Get.find<HistoryController>().refreshList());
    }
    currentIndex.value = index;
  }
}
