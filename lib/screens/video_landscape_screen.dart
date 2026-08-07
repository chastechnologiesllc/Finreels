import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../theme/app_theme.dart';

/// Dedicated landscape-only player for a single video.
///
/// Pushed from [VideoPlayerScreen] after the portrait controller has been
/// disposed (two simultaneous WebViews for the same videoId leave this
/// screen stuck on the poster at 00:00). Only this route is locked to
/// landscape — the rest of the app stays portrait. Returns the playback
/// position via [Navigator.pop].
class VideoLandscapeScreen extends StatefulWidget {
  final String videoId;
  final Duration startAt;
  final String? thumbnailUrl;

  const VideoLandscapeScreen({
    required this.videoId,
    this.startAt = Duration.zero,
    this.thumbnailUrl,
    super.key,
  });

  @override
  State<VideoLandscapeScreen> createState() => _VideoLandscapeScreenState();
}

class _VideoLandscapeScreenState extends State<VideoLandscapeScreen> {
  YoutubePlayerController? _controller;
  bool _playing = false;
  bool _hasStarted = false;
  bool _showIcon = false;
  int _tapCount = 0;
  Timer? _iconTimer;
  final ValueNotifier<double> _progress = ValueNotifier(0);
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  int _lastMs = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Wait one frame after orientation lock so the WebView mounts into a
    // settled landscape surface. Creating the controller in the same
    // frame as the orientation change is a common cause of a stuck poster.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller = YoutubePlayerController(
        initialVideoId: widget.videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          hideControls: true,
          enableCaption: false,
        ),
      )..addListener(_onUpdate);
      setState(() {});
    });
  }

  void _onUpdate() {
    if (!mounted || _controller == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 33) return;
    _lastMs = now;
    final v = _controller!.value;
    final dur = v.metaData.duration;
    final pos = v.position;
    _position.value = pos;
    _duration.value = dur;
    _progress.value = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final playing = v.playerState == PlayerState.playing;
    final justStarted = !_hasStarted && playing && pos.inMilliseconds > 0;
    if (playing != _playing || justStarted) {
      setState(() {
        _playing = playing;
        if (justStarted) _hasStarted = true;
      });
    }
  }

  @override
  void dispose() {
    _iconTimer?.cancel();
    _progress.dispose();
    _position.dispose();
    _duration.dispose();
    _controller
      ?..removeListener(_onUpdate)
      ..dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _pop() {
    final pos = _controller?.value.position ?? widget.startAt;
    Navigator.pop(context, pos);
  }

  void _toggle() {
    if (_controller == null) return;
    if (_playing) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {
      _playing = !_playing;
      _tapCount++;
      _showIcon = true;
    });
    _iconTimer?.cancel();
    _iconTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showIcon = false);
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? "${d.inHours}:" : ""}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Player — wait until controller exists (post-orientation frame).
          if (_controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(
                  controller: _controller!,
                  width: size.width,
                  onReady: () {
                    if (!mounted) return;
                    final start = widget.startAt;
                    if (start > Duration.zero) {
                      _controller!.seekTo(start);
                    }
                    _controller!
                      ..unMute()
                      ..play();
                    // Second seek after a beat — startAt / first seek can
                    // be ignored if the stream hasn't buffered yet.
                    if (start > Duration.zero) {
                      Future.delayed(const Duration(milliseconds: 350), () {
                        if (!mounted || _controller == null) return;
                        try {
                          _controller!.seekTo(start);
                          _controller!.play();
                        } catch (_) {}
                      });
                    }
                  },
                  bufferIndicator: const SizedBox.shrink(),
                ),
              ),
            ),

          // Thumbnail cover until first decoded frame (no black flash).
          if (!_hasStarted && widget.thumbnailUrl != null)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: widget.thumbnailUrl!,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                memCacheWidth: 1280,
                memCacheHeight: 720,
              ),
            ),

          if (!_hasStarted)
            const Center(
              child: CircularProgressIndicator(
                color: AppTheme.gold,
                strokeWidth: 3,
              ),
            ),

          // Solid cover over the YouTube logo region (bottom-right).
          if (_hasStarted)
            // Landscape — up + left.
            const Positioned(
              right: 56,
              bottom: 28,
              child: _LandscapeWatermark(),
            ),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: const SizedBox.expand(),
          ),

          if (_showIcon && _hasStarted)
            Center(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_tapCount),
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 230),
                  curve: Curves.easeOutBack,
                  builder: (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _playing
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),

          if (_hasStarted && !_playing && !_showIcon)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 44),
                ),
              ),
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 28),
                  onPressed: _pop,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.fullscreen_exit_rounded,
                      color: Colors.white, size: 28),
                  onPressed: _pop,
                ),
              ],
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 8,
            child: ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (_, prog, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: AppTheme.gold,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: AppTheme.gold,
                    ),
                    child: Slider(
                      value: prog.clamp(0.0, 1.0),
                      onChanged: (f) {
                        final dur = _duration.value;
                        if (dur.inMilliseconds > 0 && _controller != null) {
                          _controller!.seekTo(Duration(
                              milliseconds:
                                  (f * dur.inMilliseconds).round()));
                        }
                      },
                    ),
                  ),
                  ValueListenableBuilder<Duration>(
                    valueListenable: _position,
                    builder: (_, pos, __) => ValueListenableBuilder<Duration>(
                      valueListenable: _duration,
                      builder: (_, dur, __) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_fmt(pos)} / ${_fmt(dur)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandscapeWatermark extends StatelessWidget {
  const _LandscapeWatermark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 34,
      alignment: Alignment.center,
      color: const Color(0xF2000000),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 16,
              height: 16,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.play_arrow_rounded,
                color: AppTheme.gold,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'FinReels',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
