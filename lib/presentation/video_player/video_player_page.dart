import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart' as vp;

import 'video_player_controller.dart';

class VideoPlayerPage extends GetView<VideoPlayerController> {
  const VideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Obx(() => Text(controller.title.value))),
      body: SafeArea(
        child: Center(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const CircularProgressIndicator();
            }
            if (controller.errorText.value.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  controller.errorText.value,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              );
            }

            final vp.VideoPlayerController player = controller.playerController;
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: AspectRatio(
                      aspectRatio: player.value.aspectRatio == 0
                          ? 16 / 9
                          : player.value.aspectRatio,
                      child: vp.VideoPlayer(player),
                    ),
                  ),
                  const SizedBox(height: 18),
                  IconButton.filled(
                    onPressed: controller.togglePlayback,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(72, 72),
                    ),
                    icon: Icon(
                      player.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 36,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
