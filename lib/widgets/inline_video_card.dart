import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
// Gray-flash / white-flash root-cause analysis & fixes (Aug 2026)
//
// ROOT CAUSE — WHY THE GRAY APPEARED ON PLAY/PAUSE (mobile)
// ──────────────────────────────────────────────────────────
// Previous code used TWO different widget-tree structures depending on
// _revealPlayer:
//
//   _revealPlayer=false → Positioned(left:-10000, width:1, height:1)
//                           └─ IgnorePointer └─ YoutubePlayer(ctrl)
//   _revealPlayer=true  → YoutubePlayerBuilder
//                           └─ YoutubePlayer(ctrl)
//
// When _revealPlayer flipped true the widget TYPES changed (Positioned →
// YoutubePlayerBuilder). Flutter treats different parent types as different
// elements → it unmounted the old Positioned subtree and mounted a brand-new
// YoutubePlayerBuilder subtree. That mounted a BRAND-NEW platform view
// (WebView). The new WebView's first frame is always the native gray/white
// WebView background. At the same tick the thumbnail was removed
// (showLiveVideo = true). Result: one or more gray frames visible to the user.
//
// FIX A — Stable widget tree (no more parking)
// ─────────────────────────────────────────────
// YoutubePlayerBuilder is gone. YoutubePlayer lives at a FIXED position in
// the Stack whenever _controller != null. Flutter never unmounts it mid-play,
// so the platform view is created ONCE and reused for the whole session. No
// widget-type change → no second platform view → no gray frame.
//
// FIX B — AnimatedOpacity crossfade on the thumbnail
// ───────────────────────────────────────────────────
// The thumbnail layer no longer disappears abruptly. It uses AnimatedOpacity:
// • opacity=1.0  while !showLiveVideo  (thumbnail fully visible)
// • opacity=0.0  while  showLiveVideo  (thumbnail fades over 200 ms)
//
// When showLiveVideo first becomes true (position>0 && playing), the thumbnail
// starts at opacity 1.0 and fades out over 200 ms. The platform view has
// 200 ms of "breathing room" to render real video frames before the thumbnail
// is gone — even if there were a new platform view (from initial tap), the
// gray would never show through the semi-opaque thumbnail.
//
// On pause (showLiveVideo=false): thumbnail fades back IN over 200 ms,
// covering the YouTube logo/gray before it becomes visible.
//
// FIX C — useHybridComposition: false (Virtual Display mode)
// ──────────────────────────────────────────────────────────
// In Hybrid Composition (the default) the WebView is a native Android View
// placed ABOVE the Flutter surface; Flutter widgets (thumbnail, play button,
// watermark) are rendered on the Flutter canvas BELOW the WebView. They are
// invisible — they cannot overlay the WebView. Virtual Display (HC=false)
// renders the WebView to a GPU texture that Flutter composites like any other
// layer; Flutter overlays work correctly. This was already set here, kept.
//
// FIX D — Web: ColoredBox + black container div
// ─────────────────────────────────────────────
// See web_youtube_player_web.dart for the iframe-side fix.
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
  bool _isPlaying    = false; // mirrors PlayerState for watermark timing
  /// True for ~4 s after play starts — matches when YT logo is typically visible.
  bool _showYtCover  = false;
  Timer? _revealTimer;
  Timer? _soundRetryTimer;
  Timer? _ytCoverTimer;
  int _soundRetryCount = 0;

  PlayerState _prevState = PlayerState.unknown;

  bool get _isActive =>
      widget.activeVideoNotifier.value == widget.video.id;

  // KeepAlive only while this card is the ACTIVE expanded player.
  // Dropping it when inactive allows ListView to recycle the element and
  // free the WebView — the primary fix for gray-box exhaustion on long feeds.
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

  // ── Active-slot coordination ───────────────────────────────────────────────

  void _onActiveChanged() {
    if (!mounted) return;
    if (!_expanded || _controller == null) {
      updateKeepAlive();
      return;
    }
    if (_isActive && _playerReady) {
      try { _controller!.play(); } on Object catch (_) {}
    } else if (!_isActive) {
      _tearDownPlayer();
    }
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

    // Safety-net play retry 800 ms after onReady fires.
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _revealPlayer || !_expanded) return;
      try {
        _controller?.play();
        _forceSoundOn();
      } on Object catch (_) {}
    });
    // Last-resort: reveal after 2.5 s regardless of positionMs. Keeps the
    // player interactive even if the position-tick signal never arrives
    // (rare network stall). Thumbnail stays visible because showLiveVideo
    // checks _isPlaying which remains false until the controller reports it.
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted || _revealPlayer || !_expanded) return;
      setState(() => _revealPlayer = true);
    });
  }

  int _lastCardUpdateMs = 0;

  void _onControllerUpdate() {
    if (!mounted) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastCardUpdateMs < 66) return; // 15 fps cap
    _lastCardUpdateMs = nowMs;

    final v           = _controller!.value;
    final ready       = v.isReady;
    final currentState = v.playerState;
    final positionMs  = v.position.inMilliseconds;

    if (ready != _playerReady) _markReady();

    // PRIMARY reveal trigger: position > 0 proves real frames are decoded.
    // PlayerState.playing can fire before any frame is visible on screen —
    // using positionMs eliminates the gray-flash window.
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
        // Paused — YT logo reappears; thumbnail (AnimatedOpacity) will fade
        // back in, covering it. Keep YtCover active too for belt-and-suspenders.
        _ytCoverTimer?.cancel();
        if (mounted) setState(() => _showYtCover = true);
      }
    }

    // Ad trigger on playing → paused.
    if (_prevState == PlayerState.playing &&
        currentState == PlayerState.paused) {
      unawaited(AdService.instance.onVideoTapped());
    }
    _prevState = currentState;
  }

  // ── Controller lifecycle ───────────────────────────────────────────────────

  /// Creates the player controller only on first user tap.
  /// useHybridComposition: false → Virtual Display mode → Flutter overlays
  /// (thumbnail, play button, watermark) composite ABOVE the WebView texture.
  /// With HC=true (the package default) the WebView is a native Android View
  /// lifted above the Flutter canvas — all our overlay widgets are invisible.
  void _createController({required bool autoPlay, bool muted = false}) {
    if (_controller != null) return;
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.id,
      flags: YoutubePlayerFlags(
        autoPlay: autoPlay,
        mute: muted,
        enableCaption: false,
        hideControls: true,
        useHybridComposition: false, // required for Flutter overlays to work
      ),
    )..addListener(_onControllerUpdate);
    if (mounted) setState(() {});
  }

  /// Full teardown: dispose controller, reset all state, return to thumbnail.
  void _tearDownPlayer() {
    _revealTimer?.cancel();
    _soundRetryTimer?.cancel();
    _ytCoverTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    try { _controller?.pause(); } on Object catch (_) {}
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

  // ── Tap handler ───────────────────────────────────────────────────────────

  void _onTap() {
    if (kIsWeb) {
      final willPlay   = !_isPlaying || !_expanded;
      final firstExpand = !_expanded;
      if (mounted) {
        setState(() {
          _expanded     = true;
          _ended        = false;
          _revealPlayer = true;
          _isPlaying    = willPlay;
          if (willPlay) _showYtCover = true;
        });
        updateKeepAlive();
      }

      void sendPlay() {
        WebYoutubePlayer.command(widget.video.id, 'playVideo');
        WebYoutubePlayer.command(widget.video.id, 'unMute');
        WebYoutubePlayer.command(widget.video.id, 'setVolume');
      }

      if (willPlay) {
        _armYtCover();
        if (firstExpand) {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!mounted) return;
            sendPlay();
          });
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (!mounted) return;
            sendPlay();
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

    if (_controller == null) {
      _createController(autoPlay: true);
      _startSoundRetries();
    } else if (!_ended) {
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
      setState(() {
        _expanded = true;
        _ended    = false;
      });
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

  // ── Visibility ─────────────────────────────────────────────────────────────

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final frac = info.visibleFraction;

    if (_controller == null) return;

    if (frac < 0.05) {
      _tearDownPlayer();
      return;
    }

    if (!_expanded) return;

    if (frac < 0.30) {
      try { _controller!.pause(); } on Object catch (_) {}
    } else if (frac >= 0.50 && _isActive && _playerReady) {
      try { _controller!.play(); } on Object catch (_) {}
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

  // ── Media area ─────────────────────────────────────────────────────────────
  //
  // Widget-tree layout (mobile):
  //
  //   Stack (expand)
  //   ├─ Layer 0  ColoredBox(black)         — opaque black base, never gray
  //   ├─ Layer 1  YoutubePlayer             — always full-size when controller
  //   │            (Virtual Display mode)     exists; NEVER remounted to a
  //   │                                       different widget type mid-session
  //   ├─ Layer 2  AnimatedOpacity(thumbnail) — opacity 1.0 until showLiveVideo,
  //   │                                       then fades to 0.0 over 200 ms
  //   │                                       (platform view has 200 ms to
  //   │                                       paint real frames before exposed)
  //   ├─ Layer 3  Spinner                  — only while waiting for pos>0
  //   ├─ Layer 4  Play / pause button      — Flutter-owned, no YT native
  //   ├─ Layer 5  FinReels watermark       — covers YT logo region when visible
  //   └─ Layer 6  End-screen overlay

  Widget _buildMediaArea(BuildContext context) {
    // showLiveVideo: video is decoded, playing, and the platform view should
    // be the primary visual layer. Thumbnail fades out when this is true.
    final showLiveVideo = _revealPlayer && _isPlaying && !_ended;

    final media = AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [

            // ── Layer 0: opaque black base ────────────────────────────────
            const ColoredBox(color: Color(0xFF000000)),

            // ── Layer 1: YouTube player (mobile) — stable widget position ─
            // CRITICAL: this if-block is conditioned only on _controller != null.
            // We never switch between YoutubePlayerBuilder and a Positioned park
            // depending on _revealPlayer — that widget-type swap recreated the
            // platform view every time _revealPlayer flipped, causing the gray
            // flash. Now the same YoutubePlayer widget stays in the same Stack
            // slot for the entire session; only its controller changes.
            if (!kIsWeb && _controller != null)
              YoutubePlayer(
                controller: _controller!,
                // Black package-thumbnail covers iframe's own init surface.
                thumbnail: const ColoredBox(color: Color(0xFF000000)),
                bufferIndicator: const SizedBox.shrink(),
                onReady: _markReady,
                onEnded: (_) {
                  if (mounted) setState(() => _ended = true);
                },
              ),

            // ── Layer 1b: Web embed ───────────────────────────────────────
            if (kIsWeb && _expanded)
              Positioned.fill(
                child: WebYoutubePlayer(
                  videoId: widget.video.id,
                ),
              ),

            // ── Layer 2: Thumbnail (AnimatedOpacity crossfade) ────────────
            // Stays at opacity 1.0 until showLiveVideo, then fades to 0 over
            // 200 ms. The platform view has that 200 ms to render a real frame
            // before the thumbnail fully disappears — no gray flash even if a
            // new platform view was just created. When paused (showLiveVideo
            // goes false), thumbnail fades back IN, covering the YT gray
            // pause surface before it becomes visible.
            if (!_ended)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: showLiveVideo ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: CachedNetworkImage(
                    imageUrl: widget.video.thumbnailHd,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    memCacheWidth: 720,
                    memCacheHeight: 405,
                    placeholder: (_, __) =>
                        const ColoredBox(color: Color(0xFF000000)),
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
              ),

            // ── Layer 3: Spinner (mobile, waiting for first frame) ─────────
            if (_expanded &&
                !kIsWeb &&
                _controller != null &&
                !_revealPlayer &&
                !_ended)
              const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.gold, strokeWidth: 2.5),
              ),

            // ── Layer 4: Flutter play/pause button — NEVER the YT native ──
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

            // ── Layer 5: FinReels watermark ───────────────────────────────
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

            // ── Layer 6: end-screen overlay ────────────────────────────────
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

// ── FinReels watermark (inline card) ─────────────────────────────────────────

class _InlineFinReelsWatermark extends StatelessWidget {
  const _InlineFinReelsWatermark();
  @override
  Widget build(BuildContext context) {
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
