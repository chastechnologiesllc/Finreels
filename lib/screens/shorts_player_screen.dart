import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/video.dart';
import '../services/ad_service.dart';
import '../services/engagement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/finreels_watermark.dart';
import '../widgets/web_youtube_player.dart';

/// Full-screen 9:16 Shorts player — TikTok/Reels-quality scroll UX.
///
/// ─── WHY PAGEVIEW + OUTER GESTUREDETECTOR ────────────────────────────────
/// YouTube's YoutubePlayer wraps an Android WebView that intercepts all touch
/// events at the platform level before Flutter's gesture arena runs. A plain
/// PageView can never win the gesture competition against the WebView.
///
/// Fix: PageView.physics = NeverScrollableScrollPhysics. A GestureDetector
/// with HitTestBehavior.opaque sits *above* the PageView in the widget tree,
/// so Flutter consults it first and it claims vertical drags exclusively.
///
/// ─── CONTROLLER POOL (memory-bounded) ────────────────────────────────────
/// Sliding window of controllers at the parent:
///   { currentIndex - 1, currentIndex, currentIndex + 1 }  (max 3)
/// Each _ShortPage receives its controller from the pool. Controllers
/// outside the window are disposed immediately so we never hold more than
/// three WebViews. Neighbours buffer briefly then pause so the next swipe
/// lands on a warm surface without exhausting device media resources.
///
/// ─── MUTE-UNTIL-FRAME ────────────────────────────────────────────────────
/// Same race as the long-form player: PlayerState.playing can fire (and
/// audio can start) before position > 0. Controllers in the pool start
/// muted; the active page unmutes only after the first decoded frame.
class ShortsPlayerScreen extends StatefulWidget {
  final List<Video> shorts;
  final int initialIndex;
  final bool autoPlayFirst;

  const ShortsPlayerScreen({
    required this.shorts,
    required this.initialIndex,
    this.autoPlayFirst = true,
    super.key,
  });

  @override
  State<ShortsPlayerScreen> createState() => _ShortsPlayerScreenState();
}

class _ShortsPlayerScreenState extends State<ShortsPlayerScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isDragging = false;

  /// Sliding window of controllers keyed by short index.
  /// Owned exclusively by this State — pages must not dispose them.
  final Map<int, YoutubePlayerController> _controllers = {};

  static const double _positionThreshold = 0.10;
  static const double _velocityThreshold = 400.0;
  static const double _rubberBandFactor = 0.25;
  static const Duration _snapDuration = Duration(milliseconds: 250);
  static const Curve _snapCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _syncControllerPool();
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  /// Ensure controllers exist for [current-1 … current+1].
  /// Tight window = at most 3 live WebViews. Previous ±2 window could
  /// still pressure low-end Android devices; ±1 is enough for smooth
  /// next/prev swipe while keeping memory bounded.
  /// Dispose anything outside that window.
  /// Web uses HTML embeds only — skip the mobile controller pool.
  void _syncControllerPool() {
    if (kIsWeb) return;
    final wanted = <int>{};
    for (var i = _currentIndex - 1; i <= _currentIndex + 1; i++) {
      if (i >= 0 && i < widget.shorts.length) wanted.add(i);
    }

    // Dispose out-of-window controllers first.
    final toRemove =
        _controllers.keys.where((k) => !wanted.contains(k)).toList();
    for (final k in toRemove) {
      _controllers.remove(k)?.dispose();
    }

    // Create missing in-window controllers.
    // Neighbours start muted + autoPlay so they buffer silently.
    // The active index also starts muted; the page unmutes on first frame.
    for (final i in wanted) {
      if (_controllers.containsKey(i)) continue;
      final isActive = i == _currentIndex;
      // useHybridComposition: false → Virtual Display mode.
      // Without this, the WebView is a native Android View ABOVE Flutter's
      // canvas, making every Flutter overlay (thumbnail, progress bar, play
      // icon) invisible beneath it. VD mode renders to a GPU texture that
      // Flutter composites correctly with its own widgets.
      _controllers[i] = YoutubePlayerController(
        initialVideoId: widget.shorts[i].id,
        flags: const YoutubePlayerFlags(
          mute: true,
          loop: true,
          hideControls: true,
          enableCaption: false,
          useHybridComposition: false, // required for overlays — see above
        ),
      );
      // Neighbours: pause after a short warm so they buffer the first
      // segment without racing the active short's bandwidth.
      if (!isActive) {
        Future.delayed(const Duration(milliseconds: 900), () {
          final c = _controllers[i];
          if (c == null) return;
          // Only pause if this index is still a neighbour (not now active).
          if (i != _currentIndex) {
            try {
              c.pause();
            } on Object catch (_) {}
          }
        });
      }
    }
  }

  YoutubePlayerController? _controllerFor(int index) => _controllers[index];

  // ── Rubber-band helper ───────────────────────────────────────────────────

  double _rubberBand(double rawOffset) {
    final max = _pageController.position.maxScrollExtent;
    if (rawOffset < 0) return rawOffset * _rubberBandFactor;
    if (rawOffset > max) return max + (rawOffset - max) * _rubberBandFactor;
    return rawOffset;
  }

  // ── Gesture handlers ────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails _) {
    // Field-only — no setState. Avoids a rebuild stutter at drag start.
    _isDragging = true;
    // Pause the active short immediately so swipe feels light.
    final active = _controllers[_currentIndex];
    try {
      active?.pause();
    } on Exception catch (_) {}
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_pageController.hasClients) return;
    final rawOffset = _pageController.offset - details.delta.dy;
    _pageController.jumpTo(_rubberBand(rawOffset));
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_pageController.hasClients) return;

    final velocity = details.primaryVelocity ?? 0.0;
    final page = _pageController.page ?? _currentIndex.toDouble();
    final pageFraction = page - _currentIndex;

    var targetPage = _currentIndex;

    if (velocity < -_velocityThreshold || pageFraction > _positionThreshold) {
      targetPage = (_currentIndex + 1).clamp(0, widget.shorts.length - 1);
    } else if (velocity > _velocityThreshold ||
        pageFraction < -_positionThreshold) {
      targetPage = (_currentIndex - 1).clamp(0, widget.shorts.length - 1);
    }

    if (targetPage != _currentIndex) {
      HapticFeedback.lightImpact();
    }

    _pageController
        .animateToPage(targetPage, duration: _snapDuration, curve: _snapCurve)
        .then((_) {
      if (mounted) setState(() => _isDragging = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mobile + Web: platform views steal vertical drags. Keep
    // NeverScrollableScrollPhysics and own swipes with GestureDetector.
    // Web YouTube embeds use pointer-events:none so this detector always wins.
    final pageView = PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.shorts.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
          _isDragging = false;
        });
        _syncControllerPool();
        unawaited(AdService.instance.onShortScrolled());
      },
      itemBuilder: (context, index) => _ShortPage(
        key: ValueKey(widget.shorts[index].id),
        video: widget.shorts[index],
        controller: _controllerFor(index),
        isActive: index == _currentIndex,
        autoPlayOnActivate:
            index != widget.initialIndex || widget.autoPlayFirst,
        pauseForScroll: _isDragging && index == _currentIndex,
      ),
    );

    final body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: pageView,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          body,

            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            if (widget.shorts.length > 1 &&
                _currentIndex == widget.initialIndex &&
                !_isDragging)
              const Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard_arrow_up_rounded,
                          color: Colors.white54, size: 22),
                      Text('Swipe for next',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual short page
// ─────────────────────────────────────────────────────────────────────────────

class _ShortPage extends StatefulWidget {
  final Video video;
  final YoutubePlayerController? controller;
  final bool isActive;
  final bool autoPlayOnActivate;
  final bool pauseForScroll;

  const _ShortPage({
    required this.video,
    required this.controller,
    required this.isActive,
    required this.autoPlayOnActivate,
    required this.pauseForScroll,
    super.key,
  });

  @override
  State<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends State<_ShortPage>
    with AutomaticKeepAliveClientMixin<_ShortPage>, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  bool _ready = false;
  bool _playing = false;
  bool _userStarted = false;
  bool _hasVideoStarted = false;
  bool _wasPlayingBeforeAd = false;
  bool _unmuted = false;
  double _progress = 0;

  bool _showPauseIcon = false;
  bool _showPlayFeedback = false;
  bool _showSeekLeft  = false;
  bool _showSeekRight = false;
  int _tapCount = 0;
  Timer? _pauseIconTimer;
  Timer? _playFeedbackTimer;
  Timer? _seekFeedbackTimer;

  int _lastMs = 0;
  YoutubePlayerController? _boundController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userStarted = true;
    _bindController(widget.controller);
    if (widget.isActive && widget.autoPlayOnActivate) {
      unawaited(EngagementService.instance.recordView(widget.video));
    }
  }

  void _bindController(YoutubePlayerController? c) {
    if (_boundController == c) return;
    _boundController?.removeListener(_onUpdate);
    _boundController = c;
    _boundController?.addListener(_onUpdate);
    // Reset frame/unmute state when a new controller is attached so the
    // thumbnail covers until THIS controller paints a frame.
    _hasVideoStarted = false;
    _unmuted = false;
    _ready = false;
  }

  @override
  void didUpdateWidget(_ShortPage old) {
    super.didUpdateWidget(old);

    if (widget.controller != old.controller) {
      _bindController(widget.controller);
    }

    if (widget.pauseForScroll && !old.pauseForScroll && widget.isActive) {
      _boundController?.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }

    if (!widget.isActive && old.isActive) {
      _boundController?.pause();
      // Mute when leaving so a background-buffered neighbour stays silent.
      try {
        _boundController?.mute();
      } on Exception catch (_) {}
      _unmuted = false;
      _pauseIconTimer?.cancel();
      if (mounted) {
        setState(() {
          _playing = false;
          _showPauseIcon = false;
        });
      }
      return;
    }

    if (widget.isActive && !old.isActive && widget.autoPlayOnActivate) {
      _userStarted = true;
      unawaited(EngagementService.instance.recordView(widget.video));
      // Prefer resume from the warm buffer. Only seek-to-zero when the
      // neighbour never painted a frame (cold) so we avoid a visible hitch
      // on already-buffered shorts.
      try {
        final c = _boundController;
        if (c == null) return;
        c.mute();
        if (!_hasVideoStarted) {
          c.seekTo(Duration.zero);
        }
        c.play();
      } on Exception catch (_) {}
    }

    if (!widget.pauseForScroll && old.pauseForScroll && widget.isActive) {
      if (_ready && _userStarted) {
        _boundController?.play();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive || !mounted) return;
    switch (state) {
      case AppLifecycleState.paused:
        _wasPlayingBeforeAd = _playing;
        if (_playing) _boundController?.pause();
      case AppLifecycleState.resumed:
        if (_wasPlayingBeforeAd && _ready) {
          _wasPlayingBeforeAd = false;
          _boundController?.play();
        }
      default:
        break;
    }
  }

  void _onUpdate() {
    if (!mounted || _boundController == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 66) return;
    _lastMs = now;

    final v = _boundController!.value;
    final ready = v.isReady;
    final playing = v.playerState == PlayerState.playing;
    final pos = v.position.inMilliseconds.toDouble();
    final dur = v.metaData.duration.inMilliseconds.toDouble();
    final prog = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

    final justStarted = playing && pos > 0 && !_hasVideoStarted;

    if (justStarted && widget.isActive && !_unmuted) {
      try {
        _boundController!.unMute();
        _unmuted = true;
      } on Exception catch (_) {}
    }

    if (ready != _ready ||
        playing != _playing ||
        (prog - _progress).abs() > 0.005 ||
        justStarted) {
      setState(() {
        _ready = ready;
        _playing = playing;
        _progress = prog;
        if (justStarted) _hasVideoStarted = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseIconTimer?.cancel();
    _playFeedbackTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    // Do NOT dispose the controller — the parent pool owns it.
    _boundController?.removeListener(_onUpdate);
    super.dispose();
  }

  void _seekRelative(int seconds) {
    if (!_hasVideoStarted) return;
    if (kIsWeb) {
      WebYoutubePlayer.seekTo(widget.video.id, seconds);
    } else {
      final c = _boundController;
      if (c == null) return;
      final pos    = c.value.position;
      final target = pos + Duration(seconds: seconds);
      c.seekTo(target.isNegative ? Duration.zero : target);
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

  void _togglePlay() {
    if (_boundController == null) return;
    _userStarted = true;
    _tapCount++;
    final wasPlaying = _playing;
    if (wasPlaying) {
      _boundController!.pause();
      _pauseIconTimer?.cancel();
      _playFeedbackTimer?.cancel();
      setState(() {
        _playing = false;
        _showPauseIcon = true;
        _showPlayFeedback = false;
      });
      _pauseIconTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showPauseIcon = false);
      });
    } else {
      _boundController!.play();
      _playFeedbackTimer?.cancel();
      _pauseIconTimer?.cancel();
      setState(() {
        _playing = true;
        _showPauseIcon = false;
        _showPlayFeedback = true;
      });
      _playFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showPlayFeedback = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final controller = _boundController;

    // Persistent play button when paused after start (YouTube Shorts style).
    final showPersistentPlay =
        _hasVideoStarted && !_playing && !_showPauseIcon && !_showPlayFeedback;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),

          // Web: official YouTube embed (v9 package has no reliable web player).
          if (kIsWeb && widget.isActive)
            WebYoutubePlayer(
              videoId: widget.video.id,
              autoPlay: widget.autoPlayOnActivate || _userStarted,
              loop: true,
              isShort: true,
            )
          else if (!kIsWeb && controller != null)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  // 9:16 Shorts content sits in the CENTER of the YouTube
                  // 16:9 IFrame. To make that content fill the screen width,
                  // the IFrame must be (16/9)² times the screen width tall
                  // and (16/9) times the screen width wide. FittedBox.cover
                  // then scales and clips so the 9:16 content fills 100% of
                  // the portrait screen — same behaviour as TikTok/Reels.
                  width: size.height * (16 / 9),
                  height: size.height,
                  child: YoutubePlayer(
                    controller: controller,
                    thumbnail: const ColoredBox(color: Color(0xFF000000)),
                    onReady: () {
                      if (!mounted) return;
                      setState(() => _ready = true);
                      if (widget.isActive &&
                          !widget.pauseForScroll &&
                          (widget.autoPlayOnActivate || _userStarted)) {
                        try {
                          controller
                            ..mute()
                            ..play();
                        } on Object catch (_) {}
                      }
                    },
                    bufferIndicator: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

          // Web: treat embed as started so UI overlays don't block forever.
          if (kIsWeb && widget.isActive && !_hasVideoStarted)
            Builder(builder: (_) {
              Future.microtask(() {
                if (mounted && !_hasVideoStarted) {
                  setState(() {
                    _hasVideoStarted = true;
                    _playing = true;
                    _ready = true;
                    _unmuted = true;
                  });
                }
              });
              return const SizedBox.shrink();
            }),

          // ── Thumbnail (AnimatedOpacity crossfade) ──────────────────
          // opacity=1.0 until _hasVideoStarted (first decoded frame),
          // then fades to 0.0 over 150 ms on mobile / 600 ms on web.
          // Gives the platform view time to paint a real frame before the
          // thumbnail is gone — no gray-flash transition.
          // _hasVideoStarted is reset to false in _bindController whenever
          // the controller changes (swipe to next short), so the thumbnail
          // returns immediately for the incoming short — correct UX.
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _hasVideoStarted ? 0.0 : 1.0,
              duration: kIsWeb
                  ? const Duration(milliseconds: 600)
                  : const Duration(milliseconds: 150),
              child: CachedNetworkImage(
                imageUrl: widget.video.thumbnailHd,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                memCacheWidth: 720,
                memCacheHeight: 405,
                errorWidget: (_, __, ___) => CachedNetworkImage(
                  imageUrl: widget.video.thumbnailMq,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  memCacheWidth: 720,
                  memCacheHeight: 405,
                ),
              ),
            ),
          ),

          LayoutBuilder(
            builder: (_, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              onDoubleTapDown: (d) {
                _seekRelative(
                    d.localPosition.dx < constraints.maxWidth / 2 ? -10 : 10);
              },
              onDoubleTap: () {},
              child: const SizedBox.expand(),
            ),
          ),

          // Seek feedback overlays
          if (_showSeekLeft)
            Align(
              alignment: Alignment.centerLeft,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.replay_10_rounded,
                          color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 6),
                    const Text('-10s', style: TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          if (_showSeekRight)
            Align(
              alignment: Alignment.centerRight,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.forward_10_rounded,
                          color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 6),
                    const Text('+10s', style: TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),

          // Spinner only until first decoded frame.
          if (!_hasVideoStarted)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),

          if (_showPauseIcon)
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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pause_rounded,
                        color: Colors.white, size: 38),
                  ),
                ),
              ),
            ),

          if (_showPlayFeedback)
            Center(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_tapCount + 10000),
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 230),
                  curve: Curves.easeOutBack,
                  builder: (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 38),
                  ),
                ),
              ),
            ),

          // Persistent play when paused (YouTube Shorts pattern).
          if (showPersistentPlay)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 38),
                ),
              ),
            ),

          // FinReels watermark for Shorts — right-side bar design.
          // YouTube logo is usually off-screen (clipped by FittedBox 9:16 crop),
          // so this is primarily branding. Shown while the short is active and
          // has started; sits just above the bottom title / action bar.
          if (_hasVideoStarted && widget.isActive)
            const Positioned(
              right: 0,
              bottom: 100,
              child: FinReelsWatermark(),
            ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation(AppTheme.gold),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
