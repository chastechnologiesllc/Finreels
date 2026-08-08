// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Official YouTube IFrame embed for Flutter web.
///
/// - Muted autoplay required by browser policy (MDN).
/// - youtube-nocookie.com keeps playback inside our origin's iframe.
/// - Shorts: controls=0 so Flutter owns the chrome; long-form keeps controls.
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
    // Shorts: hide native chrome so PageView can scroll; long-form: show YT UI.
    'controls': isShort ? '0' : '1',
    'fs': isShort ? '0' : '1',
    'disablekb': isShort ? '1' : '0',
    'iv_load_policy': '3',
    'enablejsapi': '1',
    'origin': web.window.location.origin,
  };
  final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
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
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen'
      ..allowFullscreen = true;
    iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
    iframe.setAttribute('loading', 'eager');
    // Shorts: let Flutter gesture detectors win vertical scrolls by making
    // the iframe ignore pointer events. Flutter overlays handle play/pause.
    if (isShort) {
      iframe.style.pointerEvents = 'none';
    }
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
