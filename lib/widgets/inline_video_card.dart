import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/channel.dart';
import '../models/video.dart';
import '../screens/channel_videos_screen.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fixes in this file:
//
// 1. NO BLACK FLASH (real fix — pre-warm the WebView before the tap)
//    The previous fix (keeping the thumbnail subtree always mounted, with
//    an opacity + grace-delay reveal) reduced the flash but did not fully
//    eliminate it, because the YouTube WebView's native platform-view
//    surface can render black for its first few frames at the OS
//    compositing level — something Flutter-side Opacity cannot always
//    fully mask, regardless of widget-tree structure.
//
//    The actual fix: the YoutubePlayerController is now created the moment
//    the card scrolls meaningfully into view (>30% visible), NOT at the
//    moment of tap — see _onVisibilityChanged. It's created with
//    autoPlay:false so nothing is audible/visible yet; this just lets the
//    native surface finish its own initialisation silently, hidden behind
//    the thumbnail, while the user is still scrolling or reading the
//    title. By the time they actually tap (_onTap), that surface has
//    almost always already finished warming up, so the reveal is instant.
//    A grace-delay+opacity reveal (_markReady/_revealPlayer) is kept as a
//    fallback for the rare case of a near-instant tap with no pre-warm
//    lead time. Pre-warmed-but-never-tapped controllers are disposed once
//    a card scrolls far enough off screen (<5% visible) to keep the
//    number of simultaneously-alive WebViews bounded in a long feed.
//
// 2. VIDEO PAUSE AD TRIGGER
//    Every time the user taps pause (the play/pause button or a tap on the
//    player area while playing), AdService.onVideoTapped() is called.
//    Ad fires every 2nd pause (interstitialCycleLength).
//    This is tracked inside YoutubePlayer via a controller listener that
//    watches for PlayerState transitions from playing → paused.
//
// 3. FULLSCREEN — no restart
//    YoutubePlayerBuilder moves the existing WebView into an Overlay.
//    Same controller, same position, zero restart.
//    We only set orientation in the callbacks.
//
// 4. YOUTUBE BRANDING COVERED
//    36 px black bar at the bottom of the player.
//    Flutter replay overlay covers end-screen cards.
//
// 5. NATIVE PLAY-BUTTON FLASH (real fix — hideControls:true)
//    youtube_player_flutter's own TouchShutter/PlayPauseButton overlay is
//    internal to the YoutubePlayer widget and is not driven by this card's
//    _revealPlayer state, so it could flash briefly whenever the package's
//    own control layer hadn't yet settled into PlayerState.playing at the
//    moment our AnimatedOpacity revealed it — regardless of reveal timing.
//    Fixed at the source via YoutubePlayerFlags(hideControls: true) in
//    _createController, which removes that native layer entirely. _onTap
//    now handles tap-to-pause/resume directly, since the native layer used
//    to own that gesture.
//
// 6. THUMBNAIL LINGERS AFTER SPINNER STOPS (real fix — reveal on position,
//    not state label)
//    _onControllerUpdate used to reveal Layer 1 as soon as PlayerState hit
//    "playing". That label can flip before the WebView has actually painted
//    a real frame, so the spinner would stop right on cue but the video
//    still wasn't visibly there yet — same static thumbnail, just now with
//    no spinner over it, until real frames caught up. Fixed by additionally
//    requiring v.position.inMilliseconds > 0 — proof of real, advancing
//    playback — before revealing, matching the pattern already proven in
//    shorts_player_screen.dart's _onUpdate/_hasVideoStarted.
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

  @override
  bool get wantKeepAlive => _expanded;

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
    if (!mounted || _controller == null || !_expanded) return;
    if (_isActive && _playerReady) {
      _controller!.play();
    } else if (!_isActive) {
      _controller!.pause();
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

  /// Creates the YouTube controller. [autoPlay] is false during silent
  /// pre-warming (see _onVisibilityChanged) and true for a direct tap with
  /// no pre-warm in progress yet.
  void _createController({required bool autoPlay, bool muted = true}) {
    if (_controller != null) return;
    // Pre-warm stays muted (no audio while scrolling). User-initiated
    // playback (autoPlay after tap) starts unmuted so the Videos-tab
    // feed matches channel-tab sound behaviour.
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

  /// Tears down a controller that was pre-warmed but never actually
  /// engaged with (user scrolled past without tapping). Keeps the number
  /// of simultaneously-alive WebViews bounded to roughly "however many
  /// cards are within about one screen height of the viewport" rather
  /// than accumulating one per card ever scrolled past in a long feed.
  void _disposeController() {
    _revealTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller     = null;
    _playerReady    = false;
    _revealPlayer   = false;
    _prevState      = PlayerState.unknown;
    if (mounted) setState(() {});
  }

  // ── Tap thumbnail → reveal player ───────────────────────────────────────

  void _onTap() {
    if (_controller == null) {
      // User tapped with no pre-warm — start unmuted with sound.
      _createController(autoPlay: true, muted: false);
      _startSoundRetries();
    } else if (!_expanded) {
      // Pre-warmed (was muted). Unmute + play from the start with sound.
      try {
        _controller!
          ..unMute()
          ..setVolume(100)
          ..seekTo(Duration.zero)
          ..play();
      } catch (_) {}
      _startSoundRetries();
    } else if (!_ended) {
      // Already expanded: toggle if playing, otherwise FORCE retry play.
      // Critical: when stuck on thumbnail after spinner, _revealPlayer may
      // still be false — previous code ignored taps in that state.
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
    if (mounted) setState(() { _expanded = true; _ended = false; });
    updateKeepAlive();
    widget.activeVideoNotifier.value = widget.video.id;
  }

  void _onReplay() {
    if (_controller == null) return;
    setState(() => _ended = false);
    _controller!
      ..seekTo(Duration.zero)
      ..play();
  }

  // ── Visibility: pre-warm ahead of tap, pause off-screen, clean up ──────────
  //
  // This is the REAL fix for the black-flash issue. Creating the YouTube
  // WebView only at the moment of tap meant the native platform-view
  // surface's own initialisation (which can render black for its first few
  // frames at the OS compositing level — something Flutter-side opacity
  // cannot fully mask) happened RIGHT WHEN the user expected to see video.
  // By instead creating the controller (silently, muted-by-default-via-
  // autoPlay:false) the moment the card scrolls meaningfully into view —
  // well before the user has decided to tap — that initialisation happens
  // hidden behind the thumbnail while the user is still scrolling/reading.
  // By the time they actually tap, the surface has almost always already
  // finished warming up, so the transition is instant.

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final frac = info.visibleFraction;

    // Pre-warm: silently create the controller once the card is
    // significantly visible, even before any tap.
    if (_controller == null && frac > 0.3) {
      _createController(autoPlay: false);
    }

    // Free resources for cards that were pre-warmed but never tapped, once
    // they've scrolled well off screen — keeps WebView count bounded
    // regardless of how long the feed is.
    if (_controller != null && !_expanded && frac < 0.05) {
      _disposeController();
      return;
    }

    if (_controller == null || !_expanded) return;
    if (frac < 0.2) {
      _controller!.pause();
    } else if (frac >= 0.5 && _isActive && _playerReady) {
      _controller!.play();
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
    final media = AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 0: thumbnail — always mounted, never rebuilt on tap.
            CachedNetworkImage(
              imageUrl: widget.video.thumbnailHd,
              fit: BoxFit.cover,
              memCacheWidth: 720,
              memCacheHeight: 405,
              placeholder: (_, __) => Shimmer.fromColors(
                baseColor:      const Color(0xFF1E1E1E),
                highlightColor: const Color(0xFF2C2C2C),
                child: const ColoredBox(color: Colors.white),
              ),
              errorWidget: (_, __, ___) => CachedNetworkImage(
                imageUrl: widget.video.thumbnailMq,
                fit: BoxFit.cover,
                memCacheWidth: 720,
                memCacheHeight: 405,
                placeholder: (_, __) => Shimmer.fromColors(
                  baseColor:      const Color(0xFF1E1E1E),
                  highlightColor: const Color(0xFF2C2C2C),
                  child: const ColoredBox(color: Colors.white),
                ),
                errorWidget: (_, __, ___) =>
                    ColoredBox(color: AppTheme.surfaceElevated(context)),
              ),
            ),

            // Layer 1: player — only inserted once the controller exists.
            // CRITICAL: wrapped in IgnorePointer when not visible (opacity 0).
            // AnimatedOpacity at 0.0 does NOT remove the widget from Flutter's
            // hit-test tree — the WebView inside still intercepts ALL touch
            // events (including vertical scroll drags) even when completely
            // invisible. This is why the feed hangs while scrolling past cards
            // that were pre-warmed: their hidden WebViews consume every scroll
            // gesture before the ListView can claim it. IgnorePointer fixes
            // this definitively — when hidden, the entire player layer
            // receives NO pointer events, so the ListView scrolls freely.
            if (_controller != null)
              IgnorePointer(
                // Block touch to the WebView whenever it's not visible to the
                // user. Only allow touch when fully revealed (expanded + ready).
                ignoring: !(_expanded && _revealPlayer),
                child: AnimatedOpacity(
                  opacity:  (_expanded && _revealPlayer) ? 1.0 : 0.0,
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

            // Layer 2: spinner — only while the user is actively waiting
            // for the reveal (after tap, before _revealPlayer latches).
            // Never shown during silent pre-warm.
            if (_expanded && _controller != null && !_revealPlayer && !_ended)
              const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.gold, strokeWidth: 2.5),
              ),

            // Layer 3: play button
            // • Not expanded yet → initial play affordance
            // • Expanded but not playing (and not ended) → retry play so the
            //   user is never stuck on a dead thumbnail after a failed start
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

            // Layer 4: FinReels cover (rounded) while YT logo is expected.
            if (_expanded &&
                _controller != null &&
                !_ended &&
                _revealPlayer &&
                (_showYtCover || !_isPlaying))
              // Video tab 
              Positioned(
                right: 30,
                bottom: 18,
                child: _InlineFinReelsWatermark(),
              ),

            // Layer 5: our end screen hides YouTube's recommendation cards.
            if (_ended) _buildEndOverlay(),
          ],
        ),
      ),
    );

    // VisibilityDetector only matters once a player exists — wrapping it
    // unconditionally is harmless and keeps the key stable across rebuilds.
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

/// Theme-aware sharp-corner cover for the YouTube logo region (inline feed).
class _InlineFinReelsWatermark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xF2000000) : const Color(0xF2FFFFFF);
    final fg = isDark ? AppTheme.gold : const Color(0xFF1A1A1A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/app_icon.png',
            width: 14,
            height: 14,
            errorBuilder: (_, __, ___) => Icon(
              Icons.play_arrow_rounded,
              color: fg,
              size: 14,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'FinReels',
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
