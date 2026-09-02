// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// In-app iframe for blogs / books on Flutter web.
///
/// When [htmlContent] is supplied the HTML is served from a blob: URL so the
/// browser never sees the original site's X-Frame-Options header.
/// blob: URLs are same-origin to the app — framing restrictions don't apply.
///
/// When [htmlContent] is null the [url] is loaded directly (books on sources
/// that already permit framing: Gutenberg, blob PDF assets, etc.).
Widget buildWebIframe(String url, {String? title, String? htmlContent}) {
  final viewType =
      'rumuo-iframe-${url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';

  // Derive the iframe src — either a fresh blob URL or the raw URL.
  final String iframeSrc;
  if (htmlContent != null && htmlContent.isNotEmpty) {
    // Wrap HTML in a Blob and create an object URL.  The blob is
    // same-origin so X-Frame-Options on the original site is irrelevant.
    final jsParts = [htmlContent.toJS as JSAny].toJS;
    final blob = web.Blob(
      jsParts,
      web.BlobPropertyBag(type: 'text/html; charset=utf-8'),
    );
    iframeSrc = web.URL.createObjectURL(blob);
    // Note: we intentionally do not revoke the blob URL here because
    // doing so inside the factory callback would blank the iframe.
    // Memory is reclaimed on page reload / tab close.
  } else {
    iframeSrc = url;
  }

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = iframeSrc
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#ffffff'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen'
      ..allowFullscreen = true;
    iframe.setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
    iframe.setAttribute('loading', 'eager');
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
