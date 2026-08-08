// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Registers a unique iframe view factory and returns an HtmlElementView.
Widget buildWebIframe(String url, {String? title}) {
  final viewType =
      'finreels-iframe-${url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
      ..allowFullscreen = true;
    iframe.setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
    iframe.setAttribute(
      'sandbox',
      'allow-scripts allow-same-origin allow-popups allow-forms allow-presentation',
    );
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
