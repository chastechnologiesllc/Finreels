import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;

/// Web YouTube player backed by the official YouTube IFrame API.
///
/// The old implementation manually registered HTML iframes and sent raw
/// postMessage commands. That left playback state disconnected from Flutter
/// and, on some browsers, produced an iframe that rendered but never started.
/// The maintained IFrame package owns the player lifecycle and works on web,
/// Android and iOS using the same YouTube API model.
final Map<String, yt.YoutubePlayerController> _controllers = {};

Widget buildWebYoutubePlayer({
  required String videoId,
  required bool autoPlay,
  required bool mute,
  required bool loop,
  required bool isShort,
}) {
  final controller = _controllers.putIfAbsent(
    videoId,
    () => yt.YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: autoPlay,
      params: yt.YoutubePlayerParams(
        mute: mute,
        loop: loop,
        enableCaption: false,
        showControls: false,
        showFullscreenButton: false,
        playsInline: true,
        privacyEnhancedMode: true,
        pointerEvents: yt.PointerEvents.none,
        enableKeyboard: false,
        videoStateUpdateInterval: 100,
      ),
      credentialless: false,
    ),
  );

  return ColoredBox(
    color: Colors.black,
    child: yt.YoutubePlayer(
      controller: controller,
      aspectRatio: 16 / 9,
      autoFullScreen: false,
      enableFullScreenOnVerticalDrag: false,
      keepAlive: true,
      thumbnailQuality: yt.ThumbnailQuality.high,
      thumbnailFormat: yt.ThumbnailFormat.webp,
    ),
  );
}

/// Flutter-owned controls call the real IFrame API controller directly.
/// No browser navigation or YouTube URL is opened.
void webYoutubeCommand(String videoId, String func) {
  final controller = _controllers[videoId];
  if (controller == null) return;

  switch (func) {
    case 'playVideo':
      controller.playVideo();
      break;
    case 'pauseVideo':
      controller.pauseVideo();
      break;
    case 'unMute':
      controller.unMute();
      break;
    case 'mute':
      controller.mute();
      break;
    case 'stopVideo':
      controller.stopVideo();
      break;
  }
}

/// Releases a web player when its owning widget is removed.
Future<void> disposeWebYoutubePlayer(String videoId) async {
  final controller = _controllers.remove(videoId);
  if (controller != null) await controller.close();
}
