import 'package:get/get.dart';

import 'video_player_controller.dart';

class VideoPlayerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VideoPlayerController>(VideoPlayerController.new);
  }
}
