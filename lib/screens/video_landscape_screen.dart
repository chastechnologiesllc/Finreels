import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/rumuo_watermark.dart';
import '../widgets/video_thumbnail_image.dart';

/// Dedicated landscape-only full-screen player.
///
/// Pushed from [VideoPlayerScreen] (or anywhere) after the portrait controller
/// has been disposed. Two simultaneous WebViews for the same videoId cause the
/// second one to hang on the poster — dispose the caller's controller first,
/// then push this screen.
///
/// Returns the playback position via [Navigator.pop] so the caller can resume
/// from where the user left off.
///
/// Video playing approach (from old Rumuo, confirmed on device):
/// • useHybridComposition: false  — Virtual Display mode so Flutter overlay
///   layers (thumbnail, watermark, controls) render above the WebView.
/// • Controller is created one frame after orientation lock to avoid the
///   "stuck poster" bug that occurs when WebView mounts into an unsettled
///   landscape surface.
/// • Rumuo watermark flush bottom-right — new bar design covers the
///   YouTube native logo; visibility tied to the same ~4 s / paused timer.
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
  bool _playing      = false;
  bool _hasStarted   = false;
  bool _showYtCover  = false;
  bool _showIcon     = false;
  int  _tapCount     = 0;
  Timer? _iconTimer;
  Timer? _ytCoverTimer;

  final ValueNotifier<double>   _progress = ValueNotifier(0);
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);

  int _lastMs = 0;

  @override
  void initState() {
    super.initState();
    // Lock to landscape first.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Create the controller one frame after orientation lock.
    // Creating it in the same frame as setPreferredOrientations is a
    // common cause of the WebView mounting into an unsettled surface and
    // becoming stuck on the poster indefinitely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller = YoutubePlayerController(
        initialVideoId: widget.videoId,
        flags: const YoutubePlayerFlags(
          hideControls: true,
          enableCaption: false,
          useHybridComposition: false, // Virtual Display — overlays work on Android
        ),
      )..addListener(_onUpdate);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _iconTimer?.cancel();
    _ytCoverTimer?.cancel();
    _progress.dispose();
    _position.dispose();
    _duration.dispose();
    _controller
      ?..removeListener(_onUpdate)
      ..dispose();
    // Restore the adaptive app orientation policy for the screen below.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted || _controller == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 33) return; // ~30 fps cap on listener calls
    _lastMs = now;

    final v   = _controller!.value;
    final dur = v.metaData.duration;
    final pos = v.position;
    _position.value = pos;
    _duration.value = dur;
    _progress.value = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final playing      = v.playerState == PlayerState.playing;
    final justStarted  = !_hasStarted && playing && pos.inMilliseconds > 0;

    if (playing != _playing || justStarted) {
      setState(() {
        _playing = playing;
        if (justStarted) {
          _hasStarted = true;
          _armYtCover();
        }
        if (!playing && _hasStarted) _showYtCover = true;
      });
    }
  }

  void _armYtCover() {
    _ytCoverTimer?.cancel();
    _showYtCover = true;
    _ytCoverTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showYtCover = false);
    });
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
      _playing  = !_playing;
      _tapCount++;
      _showIcon = true;
    });
    _iconTimer?.cancel();
    _iconTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showIcon = false);
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${h > 0 ? "$h:" : ""}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final size    = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // ── Player — mounted one frame after orientation lock ──────────
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
                    try {
                      _controller!
                        ..unMute()
                        ..play();
                    } on Object catch (_) {}
                    // Second seek after a beat — first seek can be ignored
                    // if the stream hasn't buffered to startAt yet.
                    if (start > Duration.zero) {
                      Future.delayed(const Duration(milliseconds: 350), () {
                        if (!mounted || _controller == null) return;
                        try {
                          _controller!
                            ..seekTo(start)
                            ..play();
                        } on Object catch (_) {}
                      });
                    }
                  },
                  bufferIndicator: const SizedBox.shrink(),
                ),
              ),
            ),

          // ── Thumbnail cover — hides black flash before first frame ─────
          if (!_hasStarted && widget.thumbnailUrl != null)
            Positioned.fill(
              child: VideoThumbnailImage.forVideoId(
                videoId: widget.videoId,
                thumbnailUrl: widget.thumbnailUrl,
                fit: BoxFit.cover,
                memCacheWidth: 1280,
                memCacheHeight: 720,
              ),
            ),

          // ── Spinner ───────────────────────────────────────────────────
          if (!_hasStarted)
            const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.gold, strokeWidth: 3),
            ),

          // ── Tap to toggle play / pause ────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: const SizedBox.expand(),
          ),

          // ── Animated play/pause icon ──────────────────────────────────
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
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _playing
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: Colors.white, size: 44,
                    ),
                  ),
                ),
              ),
            ),

          // ── Persistent pause indicator (no animation) ─────────────────
          if (_hasStarted && !_playing && !_showIcon)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 44),
                ),
              ),
            ),

          // ── Top bar: back + fullscreen-exit ───────────────────────────
          Positioned(
            top: padding.top + 4,
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

          // ── Bottom: progress slider + position / duration ─────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: padding.bottom + 8,
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

          // Rumuo watermark — LAST in Stack so it renders above the
          // progress bar and all other overlays.
          // Flush bottom-right — new bar design covers the YouTube logo zone.
          // Visibility mirrors YouTube logo: ~4 s after play + while paused.
          if (_hasStarted && (_showYtCover || !_playing))
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RumuoWatermark(),
            ),
        ],
      ),
    );
  }
}
