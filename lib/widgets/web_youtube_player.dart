import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web_youtube_player_stub.dart'
    if (dart.library.html) 'web_youtube_player_web.dart' as impl;

/// In-platform YouTube player for Flutter web via the official embed iframe
/// (youtube-nocookie.com). Embed uses pointer-events:none so channel/title
/// taps never leave FinReels. Flutter owns play/pause and channel navigation.
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

  /// Send playVideo / pauseVideo to the embed (web only).
  static void command(String videoId, String func) {
    if (!kIsWeb) return;
    impl.webYoutubeCommand(videoId, func);
  }

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
