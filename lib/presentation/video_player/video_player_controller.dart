import 'package:get/get.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../core/utils/snackbar_helper.dart';

class VideoPlayerController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxString title = '视频播放'.obs;
  final RxString errorText = ''.obs;

  late final vp.VideoPlayerController playerController;

  VideoPlayerController() {
    final Map<String, dynamic> args =
        Get.arguments as Map<String, dynamic>? ?? <String, dynamic>{};
    title.value = (args['title'] ?? '视频播放').toString();
    final String url = (args['url'] ?? '').toString();
    if (url.isEmpty) {
      errorText.value = '视频地址为空';
      isLoading.value = false;
      return;
    }
    playerController = vp.VideoPlayerController.networkUrl(Uri.parse(url));
    _init();
  }

  Future<void> _init() async {
    try {
      await playerController.initialize();
      await playerController.setLooping(true);
      await playerController.play();
    } catch (_) {
      errorText.value = '视频加载失败，请稍后重试';
      SnackbarHelper.error(errorText.value);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> togglePlayback() async {
    if (playerController.value.isPlaying) {
      await playerController.pause();
    } else {
      await playerController.play();
    }
    update();
  }

  @override
  void onClose() {
    if (!isLoading.value && errorText.value.isEmpty) {
      playerController.dispose();
    }
    super.onClose();
  }
}
