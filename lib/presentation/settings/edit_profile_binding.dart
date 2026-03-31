import 'package:get/get.dart';

import 'edit_profile_controller.dart';

class EditProfileBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<EditProfileController>()) {
      Get.lazyPut<EditProfileController>(EditProfileController.new,
          fenix: true);
    }
  }
}
