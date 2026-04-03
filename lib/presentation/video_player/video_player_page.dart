import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart' as vp;

import 'video_player_controller.dart';

class VideoPlayerPage extends GetView<VideoPlayerController> {
  const VideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool fullscreen = controller.isFullscreen.value;
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: fullscreen ? null : AppBar(title: Text(controller.title.value)),
        body: SafeArea(
          top: !fullscreen,
          bottom: !fullscreen,
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
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final vp.VideoPlayerController player = controller.playerController;
              final Widget video = AspectRatio(
                aspectRatio: player.value.aspectRatio == 0
                    ? 16 / 9
                    : player.value.aspectRatio,
                child: vp.VideoPlayer(player),
              );

              return Stack(
                children: <Widget>[
                  Center(
                    child: fullscreen
                        ? SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: player.value.size.width,
                                height: player.value.size.height,
                                child: video,
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(20),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: video,
                            ),
                          ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        IconButton.filled(
                          onPressed: controller.togglePlayback,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(64, 64),
                          ),
                          icon: Icon(
                            player.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          onPressed: controller.toggleFullscreen,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(56, 56),
                          ),
                          icon: Icon(
                            fullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (fullscreen)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: IconButton.filledTonal(
                        onPressed: controller.toggleFullscreen,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      );
    });
  }
}
