import 'package:get/get.dart';

import 'invite_center_controller.dart';

class InviteCenterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InviteCenterController>(InviteCenterController.new);
  }
}
