import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Flutter web's platform-view registry is process-wide and has no unregister
/// operation. Keep one factory per video id so rebuilds do not register an
/// unbounded number of factories.
final _registeredViewTypes = <String>{};

String _viewTypeFor(String videoId) => 'finreels-youtube-${Uri.encodeComponent(videoId)}';

/// Official YouTube iframe embed used only on Flutter web.
///
/// The iframe is deliberately non-interactive: Flutter owns the controls and
/// navigation, so YouTube's own links cannot take the user out of FinReels.
/// The iframe is also sandboxed without top-navigation/pop-up permissions.
Widget buildWebYoutubePlayer({
  required String videoId,
  required bool autoPlay,
  required bool mute,
  required bool loop,
  required bool isShort,
}) {
  final params = <String, String>{
    'autoplay': autoPlay ? '1' : '0',
    'mute': mute ? '1' : '0',
    'playsinline': '1',
    'controls': '0',
    'fs': '0',
    'disablekb': '1',
    'iv_load_policy': '3',
    'cc_load_policy': '0',
    'rel': '0',
    'enablejsapi': '1',
    // YouTube recommends binding IFrame API embeds to the host origin.
    'origin': web.window.location.origin,
    if (loop) 'loop': '1',
    if (loop) 'playlist': videoId,
  };

  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  final src = 'https://www.youtube-nocookie.com/embed/$videoId?$query';
  final viewType = _viewTypeFor(videoId);

  if (_registeredViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = src
        ..style.border = '0'
        ..style.margin = '0'
        ..style.padding = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.backgroundColor = '#000'
        // Flutter's GestureDetector receives every tap. This prevents native
        // YouTube title/logo/related-video links from navigating away.
        ..style.pointerEvents = 'none'
        ..allow = 'autoplay; encrypted-media; picture-in-picture'
        ..allowFullscreen = false;

      iframe.setAttribute('title', 'FinReels video player');
      iframe.setAttribute('loading', 'eager');
      iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
      // No allow-top-navigation, allow-top-navigation-by-user-activation,
      // allow-popups, or allow-popups-to-escape-sandbox. The embedded player
      // therefore cannot promote a YouTube link into a browser navigation.
      iframe.setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-presentation',
      );
      return iframe;
    });
  }

  return HtmlElementView(viewType: viewType);
}

/// Send an IFrame API command to the matching YouTube iframe.
/// `enablejsapi=1` + `origin` are required by YouTube's current API contract.
void webYoutubeCommand(String videoId, String func) {
  try {
    final frames = web.document.querySelectorAll('iframe');
    for (var i = 0; i < frames.length; i++) {
      final element = frames.item(i);
      if (element is! web.HTMLIFrameElement) continue;
      if (!element.src.contains('/embed/$videoId?')) continue;

      final message = '{"event":"command","func":"$func","args":[]}';
      element.contentWindow?.postMessage(message.toJS, web.window.location.origin.toJS);
    }
  } on Object {
    // The iframe may still be loading. A later user tap can retry the command.
  }
}
