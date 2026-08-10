// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Official YouTube IFrame embed for Flutter web (reliable playback).
///
/// Critical requirements for postMessage control (confirmed vs YT IFrame API):
/// 1. `enablejsapi=1` in the embed URL
/// 2. `origin` matching the host page
/// 3. After iframe load, send a "listening" handshake so YT accepts commands
/// 4. `allow="autoplay"` on the iframe element
/// 5. pointer-events:none so Flutter owns all taps (no escape to youtube.com)
///
/// Without the listening handshake, playVideo/pauseVideo are ignored and the
/// embed sits on a loading surface forever.
Widget buildWebYoutubePlayer({
  required String videoId,
  required bool autoPlay,
  required bool mute,
  required bool loop,
  required bool isShort,
}) {
  final origin = web.window.location.origin;
  final params = <String, String>{
    if (autoPlay) 'autoplay': '1',
    if (mute) 'mute': '1',
    if (loop) 'loop': '1',
    if (loop) 'playlist': videoId,
    'playsinline': '1',
    'rel': '0',
    'modestbranding': '1',
    'controls': '0',
    'fs': '0',
    'disablekb': '1',
    'iv_load_policy': '3',
    'cc_load_policy': '0',
    'enablejsapi': '1',
    'origin': origin,
  };
  final qs = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  // youtube.com embed (not nocookie) is more reliable for enablejsapi handshake
  // on some browsers; origin is still locked to this host.
  final src = 'https://www.youtube.com/embed/$videoId?$qs';

  final viewType =
      'finreels-yt-$videoId-${DateTime.now().microsecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = src
      ..id = 'yt-player-$videoId'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000000'
      ..style.pointerEvents = 'none'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
      ..allowFullscreen = false;
    iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
    iframe.setAttribute('loading', 'eager');
    iframe.setAttribute(
      'sandbox',
      'allow-scripts allow-same-origin allow-presentation',
    );

    // Handshake: tell YT we are listening so it accepts subsequent commands.
    // Retry a few times because the iframe script may not be ready on first load.
    void sendListening() {
      try {
        final payload =
            '{"event":"listening","id":"$videoId","channel":"widget"}';
        iframe.contentWindow?.postMessage(payload.toJS, '*'.toJS);
      } on Object {
        // ignore
      }
    }

    iframe.onLoad.listen((_) {
      sendListening();
      // Extra retries while YT JS boots inside the frame.
      web.window.setTimeout((() {
        sendListening();
        if (autoPlay) {
          _postCommand(iframe, 'playVideo');
          if (!mute) _postCommand(iframe, 'unMute');
        }
      }).toJS, 400);
      web.window.setTimeout((() {
        sendListening();
        if (autoPlay) {
          _postCommand(iframe, 'playVideo');
          if (!mute) _postCommand(iframe, 'unMute');
        }
      }).toJS, 1200);
    });

    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}

void _postCommand(web.HTMLIFrameElement iframe, String func) {
  try {
    final payload = '{"event":"command","func":"$func","args":""}';
    iframe.contentWindow?.postMessage(payload.toJS, '*'.toJS);
  } on Object {
    // ignore
  }
}

/// Send a YT iframe API command (playVideo / pauseVideo / unMute / mute).
void webYoutubeCommand(String videoId, String func) {
  try {
    final frames = web.document.querySelectorAll('iframe');
    final len = frames.length;
    for (var i = 0; i < len; i++) {
      final el = frames.item(i);
      if (el == null) continue;
      final iframe = el as web.HTMLIFrameElement;
      if (!iframe.src.contains(videoId)) continue;
      // Re-assert listening, then command.
      final listen =
          '{"event":"listening","id":"$videoId","channel":"widget"}';
      iframe.contentWindow?.postMessage(listen.toJS, '*'.toJS);
      final payload = '{"event":"command","func":"$func","args":""}';
      iframe.contentWindow?.postMessage(payload.toJS, '*'.toJS);
    }
  } on Object {
    // Embed may not be ready yet.
  }
}
