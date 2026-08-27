import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/channel.dart';
import '../models/video.dart';
import '../screens/channel_videos_screen.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import 'finreels_watermark.dart';
import 'video_thumbnail_image.dart';
import 'web_youtube_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Video playing design (merged from old + current fixes):
//
// 1. PRE-WARMING (from old)
//    Controller is created the moment a card scrolls >30 % into view —
//    BEFORE the user taps. muted=true, autoPlay=false so nothing is audible.
//    By tap time the native WebView surface has already initialised → no
//    black/gray flash on reveal. Pre-warmed-but-never-tapped controllers are
//    disposed once the card scrolls <5 % visible.
//
// 2. INSTANT CANCEL (new feature)
//    _onActiveChanged tears down the current card immediately whenever another
//    video becomes active — covers all states: pre-warming, loading, playing.
//
// 3. STABLE WIDGET TREE / NO GRAY FLASH
//    YoutubePlayerBuilder lives at a FIXED Stack position whenever
//    _controller != null. It is never moved or re-typed based on _revealPlayer.
//    IgnorePointer (opacity=0 path) prevents the hidden WebView from stealing
//    scroll gestures while not visible.
//    AnimatedOpacity fades the PLAYER in over the always-present thumbnail so
//    the thumbnail shows through during the 200 ms window — any gray from the
//    WebView's native surface is never visible to the user.
//
// 4. useHybridComposition: false (Virtual Display mode)
//    WebView renders to a GPU texture Flutter composites normally. This is
//    required for Flutter overlay layers (thumbnail, play button, watermark)
//    to appear ABOVE the WebView on Android.
//
// 5. FINREELS WATERMARK (covers YouTube logo)
//    Right-side dark bar + gold accent + icon/text. Shown ~4 s after play
//    starts and while paused — same window the YouTube logo is visible.
//
// 6. FULLSCREEN via YoutubePlayerBuilder (from old)
//    Moves the existing WebView into an Overlay — same controller, same
//    position, zero restart. Only orientation is set in the callbacks.
//
// 7. WEB EMBED
//    kIsWeb path uses WebYoutubePlayer (HTML iframe) since youtube_player_flutter
//    has no reliable web engine.
// ─────────────────────────────────────────────────────────────────────────────

class InlineVideoCard extends StatefulWidget {
  final Video video;
  final Channel channel;
  final bool saved;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final ValueNotifier<String?> activeVideoNotifier;

  const InlineVideoCard({
    required this.video,
    required this.channel,
    required this.activeVideoNotifier,
    super.key,
    this.saved = false,
    this.onSave,
    this.onShare,
  });

  @override
  State<InlineVideoCard> createState() => _InlineVideoCardState();
}

class _InlineVideoCardState extends State<InlineVideoCard>
    with AutomaticKeepAliveClientMixin {
  YoutubePlayerController? _controller;
  bool _playerReady  = false; // YouTube IFrame API onReady fired
  bool _revealPlayer = false; // true only after onReady + real frame decoded
  bool _expanded     = false; // true once the user has tapped
  bool _ended        = false;
  bool _isPlaying    = false;
  bool _showYtCover  = false;
  bool _showSeekLeft  = false;
  bool _showSeekRight = false;
  Timer? _revealTimer;
  Timer? _soundRetryTimer;
  Timer? _ytCoverTimer;
  Timer? _seekFeedbackTimer;

  int _soundRetryCount = 0;

  PlayerState _prevState = PlayerState.unknown;

  bool get _isActive =>
      widget.activeVideoNotifier.value == widget.video.id;

  // KeepAlive only while this card is the active expanded player.
  // Dropping it when inactive lets ListView recycle and free the WebView.
  @override
  bool get wantKeepAlive => _expanded && _isActive;

  @override
  void initState() {
    super.initState();
    widget.activeVideoNotifier.addListener(_onActiveChanged);
  }

  @override
  void dispose() {
    widget.activeVideoNotifier.removeListener(_onActiveChanged);
    _revealTimer?.cancel();
    _soundRetryTimer?.cancel();
    _ytCoverTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  // ── Sound helpers ──────────────────────────────────────────────────────────

  void _forceSoundOn() {
    final c = _controller;
    if (c == null) return;
    try {
      c.unMute();
      c.setVolume(100);
    } on Object catch (_) {}
  }

  void _startSoundRetries() {
    _soundRetryTimer?.cancel();
    _soundRetryCount = 0;
    _forceSoundOn();
    _soundRetryTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      _soundRetryCount++;
      _forceSoundOn();
      if (_soundRetryCount >= 8 || !mounted) t.cancel();
    });
  }

  void _armYtCover() {
    _ytCoverTimer?.cancel();
    if (mounted) setState(() => _showYtCover = true);
    _ytCoverTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showYtCover = false);
    });
  }

  /// Double-tap ±10 s seek — works on Android, iOS, and Web.
  void _seekRelative(int seconds) {
    if (!_expanded) return;
    if (kIsWeb) {
      WebYoutubePlayer.seekTo(widget.video.id, seconds);
    } else {
      if (_controller == null) return;
      final pos    = _controller!.value.position;
      final target = pos + Duration(seconds: seconds);
      _controller!.seekTo(target.isNegative ? Duration.zero : target);
    }
    _seekFeedbackTimer?.cancel();
    setState(() {
      _showSeekLeft  = seconds < 0;
      _showSeekRight = seconds > 0;
    });
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() { _showSeekLeft = false; _showSeekRight = false; });
    });
  }

  // ── Active-slot coordination — INSTANT CANCEL ─────────────────────────────
  //
  // Called whenever activeVideoNotifier changes (any card tapped anywhere in
  // the feed). When this card is no longer active, tear it down immediately
  // regardless of state — pre-warming, loading, or playing. This gives the
  // "stop instantly when another video is tapped" behaviour.

  void _onActiveChanged() {
    if (!mounted) return;
    if (!_isActive) {
      // Covers every state: pre-warmed (controller exists, !_expanded),
      // loading (_expanded, !_playerReady), and playing.
      _tearDownPlayer();
      return;
    }
    // This card just became active — resume if already loaded.
    if (_expanded && _playerReady) {
      try {
        _controller?.play();
        _forceSoundOn();
      } on Object catch (_) {}
    }
    updateKeepAlive();
  }

  // ── Player ready / controller updates ─────────────────────────────────────

  void _markReady() {
    if (!mounted || _playerReady) return;
    setState(() => _playerReady = true);
    if (_expanded && _isActive) {
      try {
        _controller?.play();
        _forceSoundOn();
      } on Object catch (_) {}
    }

    // Safety-net: retry play 800 ms after onReady. Keeps the spinner moving
    // toward a reveal even if the first play() call was ignored by the package.
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _revealPlayer || !_expanded) return;
      try {
        _controller?.play();
        _forceSoundOn();
      } on Object catch (_) {}
    });
    // Last-resort: reveal at 2.5 s so a stalled stream is still interactive.
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted || _revealPlayer || !_expanded) return;
      setState(() => _revealPlayer = true);
    });
  }

  int _lastCardUpdateMs = 0;

  void _onControllerUpdate() {
    if (!mounted) return;
    // Rate-limit to ~15 calls/sec — listener fires on every WebView tick.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastCardUpdateMs < 66) return;
    _lastCardUpdateMs = nowMs;

    final v            = _controller!.value;
    final ready        = v.isReady;
    final currentState = v.playerState;
    final positionMs   = v.position.inMilliseconds;

    if (ready != _playerReady) _markReady();

    // PRIMARY reveal trigger: positionMs > 0 proves real frames are decoded.
    // PlayerState.playing can flip before any frame is visible on screen —
    // using positionMs eliminates the gray-flash window entirely.
    if (currentState == PlayerState.playing &&
        positionMs > 0 &&
        !_revealPlayer &&
        _expanded) {
      _revealTimer?.cancel();
      _forceSoundOn();
      setState(() { _revealPlayer = true; _isPlaying = true; });
      _armYtCover();
    }

    final playing = currentState == PlayerState.playing;
    if (playing != _isPlaying && _revealPlayer) {
      setState(() => _isPlaying = playing);
      if (playing) {
        _armYtCover();
        _forceSoundOn();
      } else {
        _ytCoverTimer?.cancel();
        if (mounted) setState(() => _showYtCover = true);
      }
    }

    // Ad trigger on playing → paused transition.
    if (_prevState == PlayerState.playing &&
        currentState == PlayerState.paused) {
      unawaited(AdService.instance.onVideoTapped());
    }
    _prevState = currentState;
  }

  // ── Controller lifecycle ───────────────────────────────────────────────────

  /// Creates the YouTube controller.
  /// [autoPlay] = false during silent pre-warm; true for direct tap.
  /// [muted]    = true during pre-warm (no audio while scrolling); false for tap.
  /// useHybridComposition: false → Virtual Display mode — Flutter overlay
  /// widgets (thumbnail, play button, watermark) composite above the WebView.
  void _createController({required bool autoPlay, bool muted = true}) {
    if (_controller != null) return;
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.id,
      flags: YoutubePlayerFlags(
        autoPlay: autoPlay,
        mute: muted,
        enableCaption: false,
        hideControls: true,
        useHybridComposition: false, // required for Flutter overlays on Android
      ),
    )..addListener(_onControllerUpdate);
    if (mounted) setState(() {});
  }

  /// Full teardown: dispose controller, cancel all timers, reset all state.
  /// Called on active-change (instant cancel) and off-screen visibility.
  void _tearDownPlayer() {
    _revealTimer?.cancel();
    _soundRetryTimer?.cancel();
    _ytCoverTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    try { _controller?.pause(); } on Object catch (_) {}
    _controller?.dispose();
    _controller   = null;
    _playerReady  = false;
    _revealPlayer = false;
    _expanded     = false;
    _ended        = false;
    _isPlaying    = false;
    _showYtCover  = false;
    _prevState    = PlayerState.unknown;
    if (mounted) {
      setState(() {});
      updateKeepAlive();
    }
  }

  // ── Fullscreen (mobile) — orientation only ─────────────────────────────────

  void _onEnterFullScreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onExitFullScreen() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ── Tap handler ───────────────────────────────────────────────────────────

  void _onTap() {

    // ── Web path ──────────────────────────────────────────────────────────
    if (kIsWeb) {
      final willPlay    = !_isPlaying || !_expanded;
      final firstExpand = !_expanded;
      if (mounted) {
        setState(() {
          _expanded  = true;
          _ended     = false;
          // _revealPlayer stays false — set true once the iframe plays (~1.5 s)
          _isPlaying = willPlay;
        });
        updateKeepAlive();
      }

      void sendPlay() {
        WebYoutubePlayer.command(widget.video.id, 'playVideo');
        WebYoutubePlayer.command(widget.video.id, 'unMute');
        WebYoutubePlayer.command(widget.video.id, 'setVolume');
      }

      if (willPlay) {
        if (firstExpand) {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) sendPlay();
          });
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) sendPlay();
          });
          // Reveal the iframe once it has loaded and started playing.
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && _expanded && !_ended) {
              setState(() => _revealPlayer = true);
              _armYtCover();
            }
          });
        } else {
          sendPlay();
        }
      } else {
        WebYoutubePlayer.command(widget.video.id, 'pauseVideo');
      }
      widget.activeVideoNotifier.value = widget.video.id;
      return;
    }

    // ── Mobile path ───────────────────────────────────────────────────────
    if (_controller == null) {
      // No controller (first tap or was disposed). Start with sound.
      _createController(autoPlay: true, muted: false);
      _startSoundRetries();
    } else if (!_expanded) {
      // Pre-warmed (muted, !_expanded). Unmute, seek to start, and play.
      try {
        _controller!
          ..unMute()
          ..setVolume(100)
          ..seekTo(Duration.zero)
          ..play();
      } on Object catch (_) {}
      _startSoundRetries();
    } else if (!_ended) {
      // Already expanded: toggle if playing, force-retry if stalled.
      final state = _controller!.value.playerState;
      if (state == PlayerState.playing && _revealPlayer) {
        _controller!.pause();
      } else {
        try {
          _controller!
            ..unMute()
            ..setVolume(100)
            ..play();
        } on Object catch (_) {
          try { _controller!.play(); } on Object catch (_) {}
        }
        _startSoundRetries();
      }
    }

    if (mounted) {
      setState(() { _expanded = true; _ended = false; });
      updateKeepAlive();
    }
    widget.activeVideoNotifier.value = widget.video.id;
  }

  void _onReplay() {
    if (_controller == null) return;
    setState(() => _ended = false);
    try {
      _controller!
        ..seekTo(Duration.zero)
        ..play();
    } on Object catch (_) {}
  }

  // ── Visibility: pre-warm + off-screen teardown ────────────────────────────
  //
  // PRE-WARM: Create the controller (silently, muted) the moment the card
  // scrolls >30 % into view — well before the user decides to tap. By tap
  // time the native WebView surface has already finished its own initialisation
  // (which renders black/gray for its first few frames at the OS compositing
  // level — something Flutter-side Opacity cannot fully mask). The result is
  // an instant reveal with no flash.
  //
  // OFF-SCREEN: Dispose when <5 % visible. Keeps live WebView count bounded
  // regardless of feed length — typically "cards within ~1 screen height".

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final frac = info.visibleFraction;

    // Pre-warm: silently create when meaningfully visible (mobile only).
    if (!kIsWeb && _controller == null && frac > 0.3) {
      _createController(autoPlay: false);
      return;
    }

    // Off-screen: full teardown regardless of state (pre-warm or expanded).
    if (frac < 0.05) {
      _tearDownPlayer();
      return;
    }

    if (!_expanded) return;

    if (frac < 0.30) {
      try { _controller?.pause(); } on Object catch (_) {}
    } else if (frac >= 0.50 && _isActive && _playerReady) {
      try { _controller?.play(); } on Object catch (_) {}
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor(context), width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMediaArea(context),
            Container(height: 3, color: widget.channel.accentColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        height: 1.35, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ChannelVideosScreen(channel: widget.channel),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7, height: 7,
                            decoration: BoxDecoration(
                                color: widget.channel.accentColor,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(widget.channel.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.gold,
                                      decoration: TextDecoration.underline,
                                      decorationThickness: 1.4,
                                    )),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 11, color: AppTheme.gold),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '· ${timeago.format(widget.video.publishedAt)}',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (widget.onSave != null || widget.onShare != null) ...[
                      const SizedBox(width: 4),
                      _actionMenu(context),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Media area ─────────────────────────────────────────────────────────────
  //
  // Widget-tree layout (mobile):
  //
  //   Stack (expand)
  //   ├─ Layer 0  Thumbnail (VideoThumbnailImage) — ALWAYS mounted, never
  //   │                                            torn down. Provides visual
  //   │                                            continuity during pre-warm
  //   │                                            and load, and persists as
  //   │                                            the background if needed.
  //   ├─ Layer 1  IgnorePointer                  — blocks the pre-warmed /
  //   │  └─ AnimatedOpacity (0 → 1)               hidden WebView from stealing
  //   │     └─ YoutubePlayerBuilder               scroll gestures while not
  //   │        └─ YoutubePlayer                   visible (opacity=0 does NOT
  //   │           (HC: false, VD mode)            remove from hit-test tree).
  //   ├─ Layer 1b WebYoutubePlayer (kIsWeb only)
  //   ├─ Layer 2  Spinner (loading, mobile only)
  //   ├─ Layer 3  Play / pause button
  //   ├─ Layer 4  FinReels watermark (theme-aware)
  //   └─ Layer 5  End-screen overlay

  Widget _buildMediaArea(BuildContext context) {
    final media = AspectRatio(
      aspectRatio: 16 / 9,
      child: LayoutBuilder(
        builder: (_, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          onDoubleTapDown: (d) {
            if (!_expanded) return;
            _seekRelative(
                d.localPosition.dx < constraints.maxWidth / 2 ? -10 : 10);
          },
          onDoubleTap: () {}, // required for onDoubleTapDown to fire
          child: Stack(
            fit: StackFit.expand,
            children: [

            // ── Layer 0: Thumbnail — always mounted ───────────────────────
            VideoThumbnailImage(
              video: widget.video,
              fit: BoxFit.cover,
              memCacheWidth: 720,
              memCacheHeight: 405,
            ),

            // ── Layer 1: YouTube player (mobile) ─────────────────────────
            // Only mounted when controller exists. Widget type NEVER changes
            // based on _revealPlayer — that would unmount/remount the platform
            // view and cause a gray flash. IgnorePointer blocks the hidden
            // WebView from consuming scroll gestures (opacity:0 still
            // participates in hit-testing without this wrapper).
            if (!kIsWeb && _controller != null)
              IgnorePointer(
                ignoring: !(_expanded && _revealPlayer),
                child: AnimatedOpacity(
                  opacity: (_expanded && _revealPlayer) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: YoutubePlayerBuilder(
                    onEnterFullScreen: _onEnterFullScreen,
                    onExitFullScreen:  _onExitFullScreen,
                    player: YoutubePlayer(
                      controller: _controller!,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: AppTheme.gold,
                      progressColors: const ProgressBarColors(
                        playedColor: AppTheme.gold,
                        handleColor: AppTheme.gold,
                      ),
                      onReady: _markReady,
                      onEnded: (_) {
                        if (mounted) setState(() => _ended = true);
                      },
                      bufferIndicator: const SizedBox.shrink(),
                    ),
                    builder: (context, player) => player,
                  ),
                ),
              ),

            // ── Layer 1b: Web embed — fades in once iframe is playing ─────
            if (kIsWeb && _expanded)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _revealPlayer ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: WebYoutubePlayer(
                    videoId: widget.video.id,
                  ),
                ),
              ),

            // ── Layer 2: Spinner — mobile AND web while loading ───────────
            if (_expanded && !_revealPlayer && !_ended)
              const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.gold, strokeWidth: 2.5),
              ),

            // ── Layer 3: Play / pause button ──────────────────────────────
            // • Not yet expanded  → initial play affordance
            // • Expanded + stalled/paused → retry play affordance so the user
            //   is never stuck staring at the thumbnail with no way forward
            if (!_expanded ||
                (_expanded && !_ended && !_isPlaying && _controller != null))
              Center(
                child: Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 32),
                ),
              ),

            // ── Layer 4: FinReels watermark — timer-based ─────────────────
            // Right-side bar design covers the YouTube logo zone.
            // Shows for ~4 s after play starts and whenever paused
            // (same window the official YouTube logo is on-screen).
            if (_expanded &&
                !_ended &&
                _revealPlayer &&
                (_showYtCover || !_isPlaying))
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FinReelsWatermark(),
              ),

            // ── Layer 5: end-screen overlay ───────────────────────────────
            if (_ended) _buildEndOverlay(),

            // ── Layer 6: seek feedback (double-tap) ───────────────────────
            if (_showSeekLeft)
              Align(
                alignment: Alignment.centerLeft,
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.replay_10_rounded,
                            color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 4),
                      const Text('-10s',
                          style: TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            if (_showSeekRight)
              Align(
                alignment: Alignment.centerRight,
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.forward_10_rounded,
                            color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 4),
                      const Text('+10s',
                          style: TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return VisibilityDetector(
      key: Key('player_${widget.video.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: media,
    );
  }

  Widget _buildEndOverlay() {
    return Stack(fit: StackFit.expand, children: [
      VideoThumbnailImage(
        video: widget.video,
        fit: BoxFit.cover,
        memCacheWidth: 720,
        memCacheHeight: 405,
      ),
      const ColoredBox(color: Color(0xBB000000)),
      Center(
        child: GestureDetector(
          onTap: _onReplay,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: const BoxDecoration(
                  color: AppTheme.gold, shape: BoxShape.circle),
              child: const Icon(Icons.replay_rounded,
                  color: Colors.black, size: 32),
            ),
            const SizedBox(height: 10),
            const Text('Replay',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
        ),
      ),
    ]);
  }

  Widget _actionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded,
          size: 18, color: AppTheme.textMuted(context)),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        if (widget.onSave != null)
          PopupMenuItem(
            value: 'save',
            child: Row(children: [
              Icon(
                widget.saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_add_outlined,
                size: 18, color: AppTheme.gold,
              ),
              const SizedBox(width: 10),
              Text(widget.saved ? 'Remove bookmark' : 'Bookmark'),
            ]),
          ),
        if (widget.onShare != null)
          const PopupMenuItem(
            value: 'share',
            child: Row(children: [
              Icon(Icons.share_outlined, size: 18),
              SizedBox(width: 10),
              Text('Share'),
            ]),
          ),
      ],
      onSelected: (v) {
        if (v == 'save')  widget.onSave?.call();
        if (v == 'share') widget.onShare?.call();
      },
    );
  }
}

// Watermark: see lib/widgets/finreels_watermark.dart — FinReelsWatermark.
