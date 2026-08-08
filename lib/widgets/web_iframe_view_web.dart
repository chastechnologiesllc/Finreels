// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// In-app iframe for blogs / books on Flutter web.
///
/// No restrictive sandbox (it blanked many publishers). Content stays inside
/// FinReels — there is no external-tab CTA.
Widget buildWebIframe(String url, {String? title}) {
  final viewType =
      'finreels-iframe-${url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#ffffff'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen'
      ..allowFullscreen = true;
    // Keep navigation inside the iframe (no top-level redirect out of FinReels).
    iframe.setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
    iframe.setAttribute('loading', 'eager');
    // Do NOT set sandbox — Gutenberg, Archive.org, Google Books, and many
    // blog CDNs fail or render blank under sandbox restrictions.
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
