import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web_youtube_player_stub.dart'
    if (dart.library.html) 'web_youtube_player_web.dart' as impl;

/// In-app YouTube player used by the web video surfaces.
///
/// Playback is owned by the official IFrame API implementation. The Flutter
/// layer owns play/pause, so taps never become browser navigation.
class WebYoutubePlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final bool mute;
  final bool loop;
  final bool isShort;

  const WebYoutubePlayer({
    required this.videoId,
    this.autoPlay = true,
    this.mute = true,
    this.loop = false,
    this.isShort = false,
    super.key,
  });

  static void command(String videoId, String func) {
    if (!kIsWeb) return;
    impl.webYoutubeCommand(videoId, func);
  }

  @override
  State<WebYoutubePlayer> createState() => _WebYoutubePlayerState();
}

class _WebYoutubePlayerState extends State<WebYoutubePlayer> {
  @override
  void dispose() {
    if (kIsWeb) {
      impl.disposeWebYoutubePlayer(widget.videoId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return impl.buildWebYoutubePlayer(
      videoId: widget.videoId,
      autoPlay: widget.autoPlay,
      mute: widget.mute,
      loop: widget.loop,
      isShort: widget.isShort,
    );
  }
}
