import 'package:get/get.dart';

import 'download_manager_controller.dart';

class DownloadManagerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DownloadManagerController>(DownloadManagerController.new);
  }
}
