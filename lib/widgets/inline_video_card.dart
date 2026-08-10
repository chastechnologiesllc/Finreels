import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
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
import 'web_youtube_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fixes in this file (memory-safe feed playback — Aug 2026):
//
// 0. GRAY / EMPTY VIDEO BOXES AFTER SCROLLING (primary crash)
//    Root cause: pre-warming a YoutubePlayerController (native WebView) for
//    every card that crossed 30% visibility, plus KeepAlive holding every
//    previously-tapped card forever. Android/iOS media resources and
//    platform-view slots were exhausted after a few scrolls; later cards
//    then failed to render and showed only gray/black empty boxes.
//
//    Fix:
//    • Default state is ALWAYS a static thumbnail. No controller is created
//      until the user taps.
//    • At most one active expanded player in the feed at a time
//      (activeVideoNotifier). When a new card claims the slot, the previous
//      one fully tears down its WebView via _tearDownPlayer().
//    • Visibility < ~15% also forces full teardown + return to thumbnail.
//    • wantKeepAlive is true only while this card is both expanded AND the
//      current active video — so ListView can recycle and free resources.
//
// 1. NO BLACK FLASH on first play
//    Thumbnail stays mounted. Player is revealed only after position > 0
//    (real frames). Black thumbnail on YoutubePlayer hides the init surface.
//
// 2. VIDEO PAUSE AD TRIGGER
//    playing → paused transitions call AdService.onVideoTapped().
//
// 3. FULLSCREEN — no restart
//    YoutubePlayerBuilder moves the existing WebView into an Overlay.
//
// 4. YOUTUBE BRANDING COVERED
//    FinReels watermark + end-screen overlay.
//
// 5. NATIVE PLAY-BUTTON FLASH
//    hideControls: true; we own tap-to-pause/resume.
//
// 6. THUMBNAIL LINGERS AFTER SPINNER
//    Reveal only when PlayerState.playing AND positionMs > 0.
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
  bool _revealPlayer = false; // true only after onReady + grace delay
  bool _expanded     = false; // true once the user has tapped
  bool _ended        = false;
  bool _isPlaying    = false; // mirrors PlayerState for watermark timing
  /// True for ~4s after play starts — matches when YT logo is typically visible.
  bool _showYtCover  = false;
  Timer? _revealTimer;
  Timer? _soundRetryTimer;
  Timer? _ytCoverTimer;
  int _soundRetryCount = 0;

  /// Tracks the previous PlayerState so we can detect playing → paused.
  PlayerState _prevState = PlayerState.unknown;

  bool get _isActive =>
      widget.activeVideoNotifier.value == widget.video.id;

  // CRITICAL: only keep the State alive while this card is the active
  // expanded player. Previously wantKeepAlive=_expanded left every tapped
  // card (and its WebView) resident forever as the user scrolled a long
  // feed → native media resources exhausted → subsequent cards rendered
  // as empty gray boxes. Now we drop KeepAlive the moment the card is
  // no longer active so ListView can recycle it and free the WebView.
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
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  /// youtube_player_flutter often ignores mute:false / a single unMute()
  /// until a later play/pause cycle (known package quirk). Force sound on
  /// with unMute + setVolume and a short retry burst after user expands.
  void _forceSoundOn() {
    final c = _controller;
    if (c == null) return;
    try {
      c.unMute();
      c.setVolume(100);
    } catch (_) {}
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
    // YouTube logo (controls=0 / hideControls): visible on pause, at start,
    // and briefly after play begins, then often fades. Mirror that window.
    _ytCoverTimer?.cancel();
    if (mounted) setState(() => _showYtCover = true);
    _ytCoverTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showYtCover = false);
    });
  }

  // ── Play / pause coordination ─────────────────────────────────────────────

  void _onActiveChanged() {
    if (!mounted) return;
    if (!_expanded || _controller == null) {
      // KeepAlive may need to drop when another card becomes active.
      updateKeepAlive();
      return;
    }
    if (_isActive && _playerReady) {
      try {
        _controller!.play();
      } catch (_) {}
    } else if (!_isActive) {
      // Another video took the active slot. Pause immediately and fully
      // tear down this WebView so we never hold more than ~1 live player
      // in the feed. This is the primary fix for the gray-box crash.
      _tearDownPlayer();
    }
  }

  /// Called the moment the YouTube IFrame API reports ready (via either the
  /// onReady callback OR the controller listener — both funnel through here
  /// so there is exactly one reveal mechanism, not two competing ones).
  void _markReady() {
    if (!mounted || _playerReady) return;
    setState(() => _playerReady = true);
    if (_expanded && _isActive) {
      try {
        _controller?.play();
        _forceSoundOn();
      } catch (_) {}
    }

    // Do NOT reveal the player layer until frames paint (position > 0).
    // A short grace that only forces play keeps the spinner + thumbnail up
    // so we never end up expanded with no play button and a dead surface.
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _revealPlayer || !_expanded) return;
      try {
        _controller?.play();
        _forceSoundOn();
      } catch (_) {}
    });
    // Last-resort reveal at 2.5s so a stalled stream still becomes interactive
    // (retry play button is shown whenever expanded && !playing).
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted || _revealPlayer || !_expanded) return;
      setState(() => _revealPlayer = true);
    });
  }

  int _lastCardUpdateMs = 0;

  void _onControllerUpdate() {
    if (!mounted) return;

    // Rate-limit to 15 calls/sec — the listener fires on every WebView tick.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastCardUpdateMs < 66) return;
    _lastCardUpdateMs = nowMs;
    final v     = _controller!.value;
    final ready = v.isReady;

    if (ready != _playerReady) _markReady();

    final currentState = v.playerState;
    final positionMs    = v.position.inMilliseconds;

    // PRIMARY reveal trigger: reveal only once the video is ACTUALLY
    // decoding and painting frames — not merely once PlayerState reports
    // "playing". PlayerState.playing is a JS-side state label that can flip
    // before the underlying WebView has actually painted a single real
    // frame, especially on a slower device or connection — so revealing on
    // the label alone could make Layer 1 "visible" (opacity animating to 1)
    // while what's actually behind it is still a static thumbnail (this
    // app's own, or the package's own — either way, not yet real video):
    // the spinner stops, but nothing visibly changes for a stretch, which
    // reads as "the thumbnail is stuck." positionMs advancing past zero is
    // proof frames are actually being decoded, not just that the player
    // intends to play — the same, stronger signal already used for exactly
    // this purpose in shorts_player_screen.dart's _onUpdate/_hasVideoStarted.
    if (currentState == PlayerState.playing &&
        positionMs > 0 &&
        !_revealPlayer &&
        _expanded) {
      _revealTimer?.cancel();
      _forceSoundOn();
      setState(() {
        _revealPlayer = true;
        _isPlaying = true;
      });
      _armYtCover();
    }

    final playing = currentState == PlayerState.playing;
    if (playing != _isPlaying && _revealPlayer) {
      setState(() => _isPlaying = playing);
      if (playing) {
        _armYtCover();
        _forceSoundOn();
      } else {
        // Paused — YT logo reappears; keep our cover visible.
        _ytCoverTimer?.cancel();
        if (mounted) setState(() => _showYtCover = true);
      }
    }

    // Detect playing → paused transition to trigger ad.
    if (_prevState == PlayerState.playing &&
        currentState == PlayerState.paused) {
      unawaited(AdService.instance.onVideoTapped());
    }
    _prevState = currentState;
  }

  // ── Controller lifecycle ─────────────────────────────────────────────────

  /// Creates the YouTube controller only on explicit user interaction.
  ///
  /// We deliberately do NOT pre-warm controllers while scrolling. Each
  /// YoutubePlayerController owns a platform WebView that is extremely
  /// heavy on Android/iOS memory and decoder slots. Pre-warming every card
  /// that crossed 30% visibility previously exhausted the native media
  /// stack after only a few scrolls, leaving subsequent cards as empty
  /// gray boxes. Thumbnails are the placeholder; the player is created
  /// lazily on tap.
  void _createController({required bool autoPlay, bool muted = false}) {
    if (_controller != null) return;
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.id,
      flags: YoutubePlayerFlags(
        autoPlay: autoPlay,
        mute: muted,
        enableCaption: false,
        hideControls: true,
      ),
    )..addListener(_onControllerUpdate);
    if (mounted) setState(() {});
  }

  /// Full teardown: dispose controller, clear all player state, return the
  /// card to a pure static thumbnail. Called when the card loses the
  /// active slot or scrolls substantially off-screen.
  void _tearDownPlayer() {
    _revealTimer?.cancel();
    _soundRetryTimer?.cancel();
    _ytCoverTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    try {
      _controller?.pause();
    } catch (_) {}
    _controller?.dispose();
    _controller     = null;
    _playerReady    = false;
    _revealPlayer   = false;
    _expanded       = false;
    _ended          = false;
    _isPlaying      = false;
    _showYtCover    = false;
    _prevState      = PlayerState.unknown;
    if (mounted) {
      setState(() {});
      updateKeepAlive();
    }
  }

  // ── Tap thumbnail → reveal player ───────────────────────────────────────

  void _onTap() {
    if (kIsWeb) {
      // Web: no mobile controller. Toggle local play state + postMessage.
      final willPlay = !_isPlaying || !_expanded;
      if (mounted) {
        setState(() {
          _expanded = true;
          _ended = false;
          _revealPlayer = true;
          _isPlaying = willPlay;
          if (willPlay) _showYtCover = true;
        });
        updateKeepAlive();
      }
      if (willPlay) {
        WebYoutubePlayer.command(widget.video.id, 'playVideo');
        WebYoutubePlayer.command(widget.video.id, 'unMute');
        _armYtCover();
      } else {
        WebYoutubePlayer.command(widget.video.id, 'pauseVideo');
      }
      widget.activeVideoNotifier.value = widget.video.id;
      return;
    }

    if (_controller == null) {
      // Lazy create on first tap — start with sound.
      _createController(autoPlay: true, muted: false);
      _startSoundRetries();
    } else if (!_ended) {
      // Already has a controller: toggle play/pause or force retry.
      final state = _controller!.value.playerState;
      if (state == PlayerState.playing && _revealPlayer) {
        _controller!.pause();
      } else {
        try {
          _controller!
            ..unMute()
            ..setVolume(100)
            ..play();
        } catch (_) {
          try {
            _controller!.play();
          } catch (_) {}
        }
        _startSoundRetries();
      }
    }
    if (mounted) {
      setState(() {
        _expanded = true;
        _ended = false;
      });
      updateKeepAlive();
    }
    // Claiming the active slot will cause any previous active card to
    // tear itself down via _onActiveChanged.
    widget.activeVideoNotifier.value = widget.video.id;
  }

  void _onReplay() {
    if (_controller == null) return;
    setState(() => _ended = false);
    try {
      _controller!
        ..seekTo(Duration.zero)
        ..play();
    } catch (_) {}
  }

  // ── Visibility: pause / dispose only when truly off-screen ────────────────
  //
  // Policy:
  // • Default = static thumbnail. Create WebView only on tap.
  // • While expanded + active: pause when mostly off-screen, resume when
  //   mostly visible.
  // • Hard teardown only when nearly invisible (<5%) so a small scroll
  //   does not force a cold restart (which caused long gray flash).
  // • Losing the active slot still tears down immediately (see _onActiveChanged).

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final frac = info.visibleFraction;

    if (_controller == null) return;

    // Truly off-screen → free the WebView.
    if (frac < 0.05) {
      _tearDownPlayer();
      return;
    }

    if (!_expanded) return;

    if (frac < 0.30) {
      try {
        _controller!.pause();
      } catch (_) {}
    } else if (frac >= 0.50 && _isActive && _playerReady) {
      try {
        _controller!.play();
      } catch (_) {}
    }
  }

  // ── Fullscreen — orientation only ─────────────────────────────────────────

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
                          Text(widget.channel.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.gold)),
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

  // ── Media area — ALWAYS mounted, never torn down ───────────────────────────
  //
  // This single widget handles every state (thumbnail-only, loading,
  // playing, ended). The Stack and its thumbnail Image layer persist for the
  // entire lifetime of this card — only the player layer is conditionally
  // inserted on top once the user taps. This is the structural fix for the
  // black-flash issue: no subtree is ever unmounted+remounted on tap.

  Widget _buildMediaArea(BuildContext context) {
    // True only while real video frames are on screen (playing + revealed).
    // When false we keep the thumbnail (or a black cover) on top so the user
    // never sees the native WebView's gray/white init or pause surface.
    final showLiveVideo = _revealPlayer && _isPlaying && !_ended;

    final media = AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 0: black base (never gray).
            const ColoredBox(color: Color(0xFF000000)),

            // Layer 1: YouTube player (mobile). Parked off-screen until
            // first frame, then full-size. Web uses its own embed below.
            if (!kIsWeb && _controller != null && _revealPlayer)
              YoutubePlayerBuilder(
                onEnterFullScreen: _onEnterFullScreen,
                onExitFullScreen: _onExitFullScreen,
                player: YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: false,
                  progressIndicatorColor: AppTheme.gold,
                  progressColors: const ProgressBarColors(
                    playedColor: AppTheme.gold,
                    handleColor: AppTheme.gold,
                  ),
                  thumbnail: const ColoredBox(color: Color(0xFF000000)),
                  bufferIndicator: const SizedBox.shrink(),
                  onReady: _markReady,
                  onEnded: (_) {
                    if (mounted) setState(() => _ended = true);
                  },
                ),
                builder: (context, player) => player,
              )
            else if (!kIsWeb && _controller != null && !_revealPlayer)
              Positioned(
                left: -10000,
                top: 0,
                width: 1,
                height: 1,
                child: IgnorePointer(
                  child: YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: false,
                    thumbnail: const ColoredBox(color: Color(0xFF000000)),
                    bufferIndicator: const SizedBox.shrink(),
                    onReady: _markReady,
                  ),
                ),
              ),

            // Layer 1b: Web embed — only after user expanded.
            if (kIsWeb && _expanded)
              Positioned.fill(
                child: WebYoutubePlayer(
                  videoId: widget.video.id,
                  autoPlay: true,
                  mute: false,
                ),
              ),

            // Layer 2: THUMBNAIL COVER — stays on top until live frames,
            // and returns on pause so the user never sees a gray box.
            // This is the real fix for the white/gray flash on press & pause.
            if (!showLiveVideo && !_ended)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: widget.video.thumbnailHd,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  memCacheWidth: 720,
                  memCacheHeight: 405,
                  placeholder: (_, __) => const ColoredBox(color: Color(0xFF000000)),
                  errorWidget: (_, __, ___) => CachedNetworkImage(
                    imageUrl: widget.video.thumbnailMq,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    memCacheWidth: 720,
                    memCacheHeight: 405,
                    errorWidget: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF000000)),
                  ),
                ),
              ),

            // Layer 3: spinner only while waiting for first frame after tap.
            if (_expanded &&
                !kIsWeb &&
                _controller != null &&
                !_revealPlayer &&
                !_ended)
              const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.gold, strokeWidth: 2.5),
              ),

            // Layer 4: Flutter play button (never YT native).
            // Shown when not expanded, or expanded but paused / not yet live.
            if (!_ended && (!showLiveVideo || !_expanded))
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 34),
                ),
              ),

            // Layer 5: FinReels watermark while YT logo is expected.
            if (_expanded &&
                !_ended &&
                showLiveVideo &&
                (_showYtCover || !_isPlaying))
              LayoutBuilder(
                builder: (context, constraints) {
                  final shortSide = constraints.maxWidth < constraints.maxHeight
                      ? constraints.maxWidth
                      : constraints.maxHeight;
                  final inset = (shortSide * 0.055).clamp(10.0, 48.0);
                  return Positioned(
                    right: inset,
                    bottom: (inset * 0.55).clamp(8.0, 28.0),
                    child: const _InlineFinReelsWatermark(),
                  );
                },
              ),

            // Layer 6: end screen.
            if (_ended) _buildEndOverlay(),
          ],
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
      CachedNetworkImage(
        imageUrl: widget.video.thumbnailHd,
        fit: BoxFit.cover,
        memCacheWidth: 720,
        memCacheHeight: 405,
        errorWidget: (_, __, ___) => CachedNetworkImage(
          imageUrl: widget.video.thumbnailMq,
          fit: BoxFit.cover,
          memCacheWidth: 720,
          memCacheHeight: 405,
          errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
        ),
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

/// Theme-aware cover for the YouTube logo region (inline feed).
/// Sized slightly larger than the native YT logo so relative positioning
/// still fully covers it across densities and card widths.
class _InlineFinReelsWatermark extends StatelessWidget {
  const _InlineFinReelsWatermark();
  @override
  Widget build(BuildContext context) {
    // Always dark translucent + gold — never light-theme white (0xF2FFFFFF).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xCC0D0D0D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/app_icon.png',
            width: 14,
            height: 14,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.play_arrow_rounded,
              color: AppTheme.gold,
              size: 14,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'FinReels',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
