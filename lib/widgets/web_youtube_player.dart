import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web_youtube_player_stub.dart'
    if (dart.library.html) 'web_youtube_player_web.dart' as impl;

/// In-platform YouTube player for Flutter web via the official embed iframe
/// (youtube-nocookie.com). Browsers require muted autoplay; user can unmute
/// with the native YT controls after a gesture.
class WebYoutubePlayer extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return impl.buildWebYoutubePlayer(
      videoId: videoId,
      autoPlay: autoPlay,
      mute: mute,
      loop: loop,
      isShort: isShort,
    );
  }
}
