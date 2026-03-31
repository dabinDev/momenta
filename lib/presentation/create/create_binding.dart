import 'package:get/get.dart';

import 'create_controller.dart';

class CreateBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CreateController>()) {
      Get.lazyPut<CreateController>(CreateController.new, fenix: true);
    }
  }
}
