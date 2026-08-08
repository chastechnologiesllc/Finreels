// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Official YouTube IFrame embed. Muted autoplay is required by browsers
/// (MDN autoplay policy). Uses youtube-nocookie for privacy-enhanced mode.
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
    if (loop) 'playlist': videoId, // required for loop to work
    'playsinline': '1',
    'rel': '0',
    'modestbranding': '1',
    'controls': '1',
    'enablejsapi': '1',
    'origin': web.window.location.origin,
  };
  final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
  final src = 'https://www.youtube-nocookie.com/embed/$videoId?$qs';

  final viewType =
      'finreels-yt-$videoId-${DateTime.now().microsecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = src
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
      ..allowFullscreen = true;
    iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
    iframe.setAttribute('loading', 'eager');
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
