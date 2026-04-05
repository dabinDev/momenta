import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../app/theme.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'video_player_controller.dart';

class VideoPlayerPage extends GetView<VideoPlayerController> {
  const VideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AppPageScaffold(
        title: controller.title.value,
        subtitle: controller.sourceLabel,
        accentColor: AppTheme.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            SectionCard(
              title: '视频预览',
              subtitle: controller.helperText,
              icon: Icons.smart_display_rounded,
              accentColor: AppTheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _InfoStrip(
                    isLocalSource: controller.hasLocalCopy,
                  ),
                  const SizedBox(height: 14),
                  _SmartVideoPlayer(
                    title: controller.title.value,
                    remoteUrl: controller.remoteUrl,
                    localPath: controller.localPath.value,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSky,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.outlineSoft),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.sky.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.tips_and_updates_outlined,
                            size: 18,
                            color: AppTheme.sky,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            controller.hasLocalCopy
                                ? '当前已经切到本地文件播放，画面和拖动会更稳定。'
                                : '右下角可进入全屏预览；如果网络一般，先下载到本地再看会明显更稳。',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.text,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ActionArea(controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.isLocalSource});

  final bool isLocalSource;

  @override
  Widget build(BuildContext context) {
    final List<_InfoBadgeData> items = <_InfoBadgeData>[
      _InfoBadgeData(
        label: isLocalSource ? '本地播放' : '云端直连',
        icon: isLocalSource ? Icons.sd_card_rounded : Icons.cloud_queue_rounded,
        color: isLocalSource ? AppTheme.jade : AppTheme.primaryDeep,
        background: isLocalSource ? AppTheme.surfaceJade : AppTheme.surfaceSoft,
      ),
      const _InfoBadgeData(
        label: '支持全屏',
        icon: Icons.fullscreen_rounded,
        color: AppTheme.sky,
        background: AppTheme.surfaceSky,
      ),
      const _InfoBadgeData(
        label: '支持倍速',
        icon: Icons.speed_rounded,
        color: AppTheme.amber,
        background: AppTheme.surfaceAmber,
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (_InfoBadgeData item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: item.background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(item.icon, size: 16, color: item.color),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: item.color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = <Widget>[
      PrimaryButton.outline(
        label: '下载管理',
        icon: Icons.download_done_rounded,
        onPressed: controller.openDownloadManager,
      ),
      if (controller.canDownload)
        Obx(
          () => PrimaryButton(
            label: controller.isDownloading.value ? '加入下载中...' : '下载后本地看',
            icon: controller.isDownloading.value
                ? Icons.downloading_rounded
                : Icons.download_rounded,
            onPressed: controller.isDownloading.value
                ? null
                : controller.downloadCurrentVideo,
          ),
        ),
      if (controller.canSaveToGallery)
        Obx(
          () => PrimaryButton(
            label: controller.isSavingToGallery.value ? '保存中...' : '保存到相册',
            icon: controller.isSavingToGallery.value
                ? Icons.hourglass_top_rounded
                : Icons.photo_library_outlined,
            onPressed: controller.isSavingToGallery.value
                ? null
                : controller.saveToGallery,
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            children: actions
                .expand<Widget>(
                  (Widget item) => <Widget>[
                    item,
                    const SizedBox(height: 10),
                  ],
                )
                .toList()
              ..removeLast(),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map(
                (Widget action) => SizedBox(
                  width: constraints.maxWidth > 540
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth,
                  child: action,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SmartVideoPlayer extends StatefulWidget {
  const _SmartVideoPlayer({
    required this.title,
    required this.remoteUrl,
    required this.localPath,
    this.fullscreen = false,
    this.initialPosition = Duration.zero,
    this.initialPlaybackSpeed = 1.0,
    this.autoplay = true,
    this.onCloseRequested,
  });

  final String title;
  final String remoteUrl;
  final String localPath;
  final bool fullscreen;
  final Duration initialPosition;
  final double initialPlaybackSpeed;
  final bool autoplay;
  final ValueChanged<_PlaybackSnapshot>? onCloseRequested;

  @override
  State<_SmartVideoPlayer> createState() => _SmartVideoPlayerState();
}

class _SmartVideoPlayerState extends State<_SmartVideoPlayer> {
  static const List<double> _speedOptions = <double>[1.0, 1.25, 1.5, 2.0];

  vp.VideoPlayerController? _playerController;
  Timer? _controlsTimer;
  bool _isLoading = true;
  bool _controlsVisible = true;
  bool _isMuted = false;
  bool _isLocalSource = false;
  String _errorText = '';
  double _playbackSpeed = 1.0;
  String _resolvedSourceKey = '';

  bool get _hasPlayer => _playerController?.value.isInitialized == true;

  @override
  void initState() {
    super.initState();
    unawaited(
      _initializePlayer(
        initialPosition: widget.initialPosition,
        autoplay: widget.autoplay,
        playbackSpeed: widget.initialPlaybackSpeed,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _SmartVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final _ResolvedVideoSource nextSource = _resolveSource();
    if (nextSource.key != _resolvedSourceKey) {
      final _PlaybackSnapshot snapshot = _currentSnapshot();
      unawaited(
        _initializePlayer(
          initialPosition: snapshot.position,
          autoplay: snapshot.isPlaying,
          playbackSpeed: snapshot.playbackSpeed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    final vp.VideoPlayerController? controller = _playerController;
    _playerController = null;
    controller?.removeListener(_handleVideoStateChanged);
    controller?.dispose();
    super.dispose();
  }

  _ResolvedVideoSource _resolveSource() {
    final String localPath = widget.localPath.trim();
    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      return _ResolvedVideoSource(
        key: 'file:$localPath',
        value: localPath,
        isLocal: true,
      );
    }

    final String remoteUrl = widget.remoteUrl.trim();
    if (remoteUrl.isNotEmpty) {
      return _ResolvedVideoSource(
        key: 'url:$remoteUrl',
        value: remoteUrl,
        isLocal: false,
      );
    }

    return const _ResolvedVideoSource(
      key: '',
      value: '',
      isLocal: false,
    );
  }

  Future<void> _initializePlayer({
    Duration initialPosition = Duration.zero,
    bool autoplay = true,
    double playbackSpeed = 1.0,
  }) async {
    final _ResolvedVideoSource source = _resolveSource();
    final vp.VideoPlayerController? previousController = _playerController;

    _controlsTimer?.cancel();
    previousController?.removeListener(_handleVideoStateChanged);

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorText = '';
        _controlsVisible = true;
      });
    }

    _playerController = null;
    _resolvedSourceKey = source.key;
    _isLocalSource = source.isLocal;

    await previousController?.dispose();

    if (source.value.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorText = '当前没有可预览的视频';
      });
      return;
    }

    try {
      final vp.VideoPlayerController controller = source.isLocal
          ? vp.VideoPlayerController.file(
              File(source.value),
              videoPlayerOptions: vp.VideoPlayerOptions(
                allowBackgroundPlayback: false,
                mixWithOthers: false,
              ),
            )
          : vp.VideoPlayerController.networkUrl(
              Uri.parse(source.value),
              videoPlayerOptions: vp.VideoPlayerOptions(
                allowBackgroundPlayback: false,
                mixWithOthers: false,
              ),
            );

      _playerController = controller;
      controller.addListener(_handleVideoStateChanged);
      await controller.initialize();

      final Duration duration = controller.value.duration;
      final Duration safePosition = initialPosition > duration
          ? duration
          : (initialPosition < Duration.zero ? Duration.zero : initialPosition);
      if (safePosition > Duration.zero) {
        await controller.seekTo(safePosition);
      }

      _playbackSpeed = playbackSpeed;
      await controller.setPlaybackSpeed(playbackSpeed);
      await controller.setVolume(_isMuted ? 0 : 1);

      if (autoplay) {
        await controller.play();
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _scheduleAutoHide();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorText = '视频加载失败，请稍后重试';
      });
    }
  }

  void _handleVideoStateChanged() {
    final vp.VideoPlayerValue? value = _playerController?.value;
    if (!mounted || value == null) {
      return;
    }

    if (value.hasError && _errorText.isEmpty) {
      setState(() {
        _errorText = value.errorDescription?.trim().isNotEmpty == true
            ? value.errorDescription!.trim()
            : '视频播放失败，请稍后重试';
      });
      return;
    }

    if (value.isPlaying) {
      _scheduleAutoHide();
    } else {
      _controlsTimer?.cancel();
      if (!_controlsVisible) {
        setState(() {
          _controlsVisible = true;
        });
      }
    }

    setState(() {});
  }

  void _scheduleAutoHide() {
    if (!(_playerController?.value.isPlaying ?? false)) {
      return;
    }
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !(_playerController?.value.isPlaying ?? false)) {
        return;
      }
      setState(() {
        _controlsVisible = false;
      });
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _scheduleAutoHide();
    }
  }

  Future<void> _togglePlayPause() async {
    final vp.VideoPlayerController? controller = _playerController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final Duration duration = controller.value.duration;
    final Duration position = controller.value.position;
    if (duration > Duration.zero && position >= duration) {
      await controller.seekTo(Duration.zero);
    }

    if (controller.value.isPlaying) {
      await controller.pause();
      setState(() {
        _controlsVisible = true;
      });
      _controlsTimer?.cancel();
      return;
    }

    await controller.play();
    _scheduleAutoHide();
  }

  Future<void> _seekRelative(int seconds) async {
    final vp.VideoPlayerController? controller = _playerController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final Duration duration = controller.value.duration;
    final Duration next =
        controller.value.position + Duration(seconds: seconds);
    final Duration clamped = next < Duration.zero
        ? Duration.zero
        : (next > duration ? duration : next);
    await controller.seekTo(clamped);
    setState(() {
      _controlsVisible = true;
    });
    _scheduleAutoHide();
  }

  Future<void> _toggleMute() async {
    final vp.VideoPlayerController? controller = _playerController;
    if (controller == null) {
      return;
    }
    _isMuted = !_isMuted;
    await controller.setVolume(_isMuted ? 0 : 1);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _cyclePlaybackSpeed() async {
    final vp.VideoPlayerController? controller = _playerController;
    if (controller == null) {
      return;
    }

    final int currentIndex = _speedOptions.indexWhere(
      (double item) => (item - _playbackSpeed).abs() < 0.01,
    );
    final double nextSpeed =
        _speedOptions[(currentIndex + 1) % _speedOptions.length];
    _playbackSpeed = nextSpeed;
    await controller.setPlaybackSpeed(nextSpeed);
    if (mounted) {
      setState(() {
        _controlsVisible = true;
      });
    }
    _scheduleAutoHide();
  }

  Future<void> _handleFullscreen() async {
    final vp.VideoPlayerController? controller = _playerController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (widget.fullscreen) {
      widget.onCloseRequested?.call(_currentSnapshot());
      return;
    }

    final _PlaybackSnapshot snapshot = _currentSnapshot();
    final NavigatorState navigator = Navigator.of(context);
    await controller.pause();
    if (!mounted) {
      return;
    }
    final _PlaybackSnapshot? result = await navigator.push<_PlaybackSnapshot>(
      MaterialPageRoute<_PlaybackSnapshot>(
        builder: (BuildContext context) => _FullscreenVideoPlayerPage(
          title: widget.title,
          remoteUrl: widget.remoteUrl,
          localPath: widget.localPath,
          snapshot: snapshot,
        ),
        fullscreenDialog: true,
      ),
    );

    if (!mounted || _playerController == null) {
      return;
    }
    final _PlaybackSnapshot effectiveResult = result ?? snapshot;

    if ((_playbackSpeed - effectiveResult.playbackSpeed).abs() > 0.01) {
      _playbackSpeed = effectiveResult.playbackSpeed;
      await _playerController!.setPlaybackSpeed(effectiveResult.playbackSpeed);
    }
    await _playerController!.seekTo(effectiveResult.position);
    if (effectiveResult.isPlaying) {
      await _playerController!.play();
      _scheduleAutoHide();
    } else {
      await _playerController!.pause();
      setState(() {
        _controlsVisible = true;
      });
    }
  }

  _PlaybackSnapshot _currentSnapshot() {
    final vp.VideoPlayerValue? value = _playerController?.value;
    return _PlaybackSnapshot(
      position: value?.position ?? Duration.zero,
      isPlaying: value?.isPlaying ?? false,
      playbackSpeed: _playbackSpeed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget playerContent = _buildPlayerBody(context);
    if (widget.fullscreen) {
      return ColoredBox(
        color: Colors.black,
        child: playerContent,
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFF9DED2),
            Color(0xFFF3F7FF),
            Color(0xFFF4FBF7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: playerContent,
      ),
    );
  }

  Widget _buildPlayerBody(BuildContext context) {
    final double maxHeight = widget.fullscreen
        ? double.infinity
        : math.min(MediaQuery.sizeOf(context).height * 0.62, 520);

    return GestureDetector(
      onTap: _toggleControls,
      child: SizedBox(
        height: maxHeight,
        child: ColoredBox(
          color: const Color(0xFF090909),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (_isLoading)
                const _PlayerStatusView(
                  icon: Icons.motion_photos_on_rounded,
                  title: '视频加载中',
                  message: '正在准备播放器，请稍候。',
                  loading: true,
                )
              else if (_errorText.isNotEmpty)
                _PlayerStatusView(
                  icon: Icons.error_outline_rounded,
                  title: '视频暂时无法播放',
                  message: _errorText,
                  actionLabel: '重新加载',
                  onAction: () => _initializePlayer(
                    initialPosition: Duration.zero,
                    autoplay: true,
                    playbackSpeed: _playbackSpeed,
                  ),
                )
              else if (!_hasPlayer)
                const _PlayerStatusView(
                  icon: Icons.videocam_off_rounded,
                  title: '暂无可预览视频',
                  message: '当前任务还没有可用的视频文件。',
                )
              else
                Center(
                  child: AspectRatio(
                    aspectRatio: _safeAspectRatio(
                      _playerController!.value.aspectRatio,
                    ),
                    child: vp.VideoPlayer(_playerController!),
                  ),
                ),
              if (_hasPlayer && _playerController!.value.isBuffering)
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.8),
                      ),
                    ),
                  ),
                ),
              if (_hasPlayer)
                AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: _buildControlsOverlay(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(BuildContext context) {
    final vp.VideoPlayerValue value = _playerController!.value;
    final bool isPlaying = value.isPlaying;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              12,
              widget.fullscreen ? 16 : 12,
              12,
              18,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xB3000000),
                  Color(0x00000000),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: <Widget>[
                if (widget.fullscreen)
                  _GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: _handleFullscreen,
                  ),
                if (widget.fullscreen) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _isLocalSource ? '本地高清播放' : '云端在线播放',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _RoundControlButton(
                icon: Icons.replay_10_rounded,
                onTap: () => _seekRelative(-10),
              ),
              const SizedBox(width: 14),
              _RoundControlButton(
                icon:
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onTap: _togglePlayPause,
                primary: true,
                size: 76,
                iconSize: 34,
              ),
              const SizedBox(width: 14),
              _RoundControlButton(
                icon: Icons.forward_10_rounded,
                onTap: () => _seekRelative(10),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              12,
              20,
              12,
              widget.fullscreen ? 20 : 12,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0x00000000),
                  Color(0xC9000000),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: vp.VideoProgressIndicator(
                    _playerController!,
                    allowScrubbing: true,
                    colors: vp.VideoProgressColors(
                      playedColor: AppTheme.primary,
                      bufferedColor: Colors.white.withValues(alpha: 0.36),
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Text(
                      '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    _MiniActionButton(
                      label: _isMuted ? '静音' : '声音',
                      icon: _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      onTap: _toggleMute,
                    ),
                    const SizedBox(width: 8),
                    _MiniActionButton(
                      label:
                          '${_playbackSpeed.toStringAsFixed(_playbackSpeed.truncateToDouble() == _playbackSpeed ? 0 : 2)}x',
                      icon: Icons.speed_rounded,
                      onTap: _cyclePlaybackSpeed,
                    ),
                    const SizedBox(width: 8),
                    _MiniActionButton(
                      label: widget.fullscreen ? '退出' : '全屏',
                      icon: widget.fullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      onTap: _handleFullscreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FullscreenVideoPlayerPage extends StatelessWidget {
  const _FullscreenVideoPlayerPage({
    required this.title,
    required this.remoteUrl,
    required this.localPath,
    required this.snapshot,
  });

  final String title;
  final String remoteUrl;
  final String localPath;
  final _PlaybackSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: _FullscreenLifecycle(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: _SmartVideoPlayer(
              title: title,
              remoteUrl: remoteUrl,
              localPath: localPath,
              fullscreen: true,
              initialPosition: snapshot.position,
              initialPlaybackSpeed: snapshot.playbackSpeed,
              autoplay: snapshot.isPlaying,
              onCloseRequested: (_PlaybackSnapshot result) {
                Navigator.of(context).pop(result);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenLifecycle extends StatefulWidget {
  const _FullscreenLifecycle({required this.child});

  final Widget child;

  @override
  State<_FullscreenLifecycle> createState() => _FullscreenLifecycleState();
}

class _FullscreenLifecycleState extends State<_FullscreenLifecycle> {
  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(
      SystemChrome.setPreferredOrientations(
        const <DeviceOrientation>[
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      ),
    );
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(
      SystemChrome.setPreferredOrientations(
        const <DeviceOrientation>[DeviceOrientation.portraitUp],
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PlayerStatusView extends StatelessWidget {
  const _PlayerStatusView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    )
                  : Icon(icon, size: 30, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (!loading &&
                actionLabel != null &&
                onAction != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.size = 62,
    this.iconSize = 28,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: primary
                ? const LinearGradient(
                    colors: <Color>[
                      AppTheme.primary,
                      AppTheme.coral,
                      AppTheme.amber,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _ResolvedVideoSource {
  const _ResolvedVideoSource({
    required this.key,
    required this.value,
    required this.isLocal,
  });

  final String key;
  final String value;
  final bool isLocal;
}

class _PlaybackSnapshot {
  const _PlaybackSnapshot({
    required this.position,
    required this.isPlaying,
    required this.playbackSpeed,
  });

  final Duration position;
  final bool isPlaying;
  final double playbackSpeed;
}

class _InfoBadgeData {
  const _InfoBadgeData({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
}

double _safeAspectRatio(double value) {
  if (!value.isFinite || value <= 0) {
    return 9 / 16;
  }
  return value;
}

String _formatDuration(Duration value) {
  final int totalSeconds = value.inSeconds;
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  final String mm = minutes.toString().padLeft(2, '0');
  final String ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
  }
  return '$mm:$ss';
}
