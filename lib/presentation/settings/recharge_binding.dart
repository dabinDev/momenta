import 'package:get/get.dart';

import 'recharge_controller.dart';

class RechargeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RechargeController>(RechargeController.new);
  }
}
