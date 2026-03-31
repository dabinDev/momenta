import 'package:get/get.dart';

import 'history_controller.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<HistoryController>()) {
      Get.lazyPut<HistoryController>(HistoryController.new, fenix: true);
    }
  }
}
