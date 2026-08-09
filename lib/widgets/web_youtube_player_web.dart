// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Official YouTube IFrame embed for Flutter web.
///
/// LOCKED IN PLATFORM (no "Watch on YouTube" escape):
/// - pointer-events: none — all taps stay in Flutter
/// - controls=0, fs=0, disablekb=1, modestbranding=1, rel=0
/// - sandbox without allow-top-navigation / allow-popups
/// - youtube-nocookie + origin bound to this host
/// Playback is muted autoplay where required; Flutter owns chrome.
Widget buildWebYoutubePlayer({
  required String videoId,
  required bool autoPlay,
  required bool mute,
  required bool loop,
  required bool isShort,
}) {
  final params = <String, String>{
    if (autoPlay) 'autoplay': '1',
    if (mute) 'mute': '1',
    if (loop) 'loop': '1',
    if (loop) 'playlist': videoId,
    'playsinline': '1',
    'rel': '0',
    'modestbranding': '1',
    // No native YT chrome — channel/title links would open youtube.com.
    'controls': '0',
    'fs': '0',
    'disablekb': '1',
    'iv_load_policy': '3',
    'cc_load_policy': '0',
    'enablejsapi': '1',
    'origin': web.window.location.origin,
  };
  final qs = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  final src = 'https://www.youtube-nocookie.com/embed/$videoId?$qs';

  final viewType =
      'finreels-yt-$videoId-${DateTime.now().microsecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = src
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000000'
      // Critical: Flutter receives all taps — no navigation to YouTube.
      ..style.pointerEvents = 'none'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen'
      ..allowFullscreen = false;
    iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
    iframe.setAttribute('loading', 'eager');
    // Block top-level navigation from the frame.
    iframe.setAttribute(
        'sandbox', 'allow-scripts allow-same-origin allow-presentation');
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}

/// Send a YT iframe API command (playVideo / pauseVideo) via postMessage.
void webYoutubeCommand(String videoId, String func) {
  try {
    final frames = web.document.querySelectorAll('iframe');
    final len = frames.length;
    for (var i = 0; i < len; i++) {
      final el = frames.item(i);
      if (el == null) continue;
      final iframe = el as web.HTMLIFrameElement;
      if (!iframe.src.contains(videoId)) continue;
      final payload = '{"event":"command","func":"$func","args":""}';
      iframe.contentWindow?.postMessage(payload.toJS, '*'.toJS);
    }
  } on Object {
    // Embed may not be ready yet.
  }
}
