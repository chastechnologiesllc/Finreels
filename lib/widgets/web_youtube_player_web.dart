// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// YouTube embed for Flutter web — respects real browser autoplay rules.
///
/// Gray-flash fixes vs earlier versions
/// ─────────────────────────────────────
/// 1. registerViewFactory now returns a black <div> wrapper around the
///    <iframe> so the flutter-managed container element is never transparent.
///    (Previously the iframe element itself was returned directly; the
///    Flutter-managed outer <flt-platform-view> div had no background, showing
///    white/gray for a frame on light-theme pages before the iframe painted.)
///
/// 2. buildWebYoutubePlayer returns a ColoredBox(black) below HtmlElementView
///    so even the Flutter canvas layer beneath the platform-view is black.
///
/// 3. web/index.html adds `flt-platform-view { background:#000 }` as a belt-
///    and-suspenders CSS rule (works even before the factory fires).
///
/// Other invariants kept from prior version
/// ─────────────────────────────────────────
/// • Stable viewType per videoId (no DateTime → no infinite iframe reload)
/// • Always mute=1 + autoplay=1 in the URL (Chrome/Safari require mute)
/// • Listening handshake + delayed playVideo/unMute retries
/// • Window message listener for YT onReady / infoDelivery
/// • No sandbox attribute (blocks YT player scripts)
final Set<String> _registered = <String>{};
final Map<String, web.HTMLIFrameElement> _iframes = {};
bool _messageHooked = false;

void _ensureMessageHook() {
  if (_messageHooked) return;
  _messageHooked = true;
  web.window.addEventListener(
    'message',
    ((web.Event e) {
      try {
        final me = e as web.MessageEvent;
        final data = me.data;
        if (data == null) return;
        final raw = data.dartify();
        final text = raw is String ? raw : raw?.toString() ?? '';
        if (!text.contains('onReady') &&
            !text.contains('infoDelivery') &&
            !text.contains('initialDelivery')) {
          return;
        }
        for (final entry in _iframes.entries) {
          _kick(entry.value, entry.key, unmute: true);
        }
      } on Object {
        // ignore unrelated messages
      }
    }).toJS,
  );
}

Widget buildWebYoutubePlayer({
  required String videoId,
  required bool autoPlay,
  required bool mute,
  required bool loop,
  required bool isShort,
}) {
  _ensureMessageHook();
  final origin = web.window.location.origin;
  final params = <String, String>{
    'autoplay': autoPlay ? '1' : '0',
    'mute': '1', // always muted in URL — browser policy; we unmute via postMessage
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
    'widget_referrer': origin,
  };
  final qs = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  // youtube-nocookie.com bypasses Google Workspace YouTube restrictions
  final src = 'https://www.youtube-nocookie.com/embed/$videoId?$qs';
  final viewType = 'finreels-yt-v2-$videoId';

  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      // ── Black container div ─────────────────────────────────────────────
      // The Flutter engine wraps whatever element we return here inside its
      // own <flt-platform-view> div. That outer div has no background by
      // default; returning a plain <iframe> meant a white/gray flash was
      // visible for a frame before the iframe's black background painted.
      // Wrapping in a black <div> ensures no background colour gap.
      final container = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000000'
        ..style.overflow = 'hidden'
        ..style.position = 'relative';

      final iframe = web.HTMLIFrameElement()
        ..src = src
        ..id = 'yt-$videoId'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000000'
        ..style.pointerEvents = 'none'
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..allowFullscreen = false;
      iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
      iframe.setAttribute('loading', 'eager');

      container.append(iframe);
      _iframes[videoId] = iframe;

      void listenAndPlay() {
        _post(
          iframe,
          '{"event":"listening","id":"$videoId","channel":"widget"}',
        );
        _kick(iframe, videoId, unmute: !mute);
      }

      iframe.onLoad.listen((_) {
        listenAndPlay();
        web.window.setTimeout(listenAndPlay.toJS, 300.toJS);
        web.window.setTimeout(listenAndPlay.toJS, 800.toJS);
        web.window.setTimeout(listenAndPlay.toJS, 1600.toJS);
        web.window.setTimeout(listenAndPlay.toJS, 3200.toJS);
      });

      return container;
    });
  }

  // ColoredBox(black) sits on the Flutter canvas layer directly beneath the
  // platform-view slot, adding a second line of defence against any gap.
  return ColoredBox(
    color: const Color(0xFF000000),
    child: HtmlElementView(viewType: viewType),
  );
}

void _kick(
  web.HTMLIFrameElement iframe,
  String videoId, {
  required bool unmute,
}) {
  _post(
    iframe,
    '{"event":"listening","id":"$videoId","channel":"widget"}',
  );
  _post(iframe, '{"event":"command","func":"playVideo","args":[]}');
  if (unmute) {
    _post(iframe, '{"event":"command","func":"unMute","args":[]}');
    _post(iframe, '{"event":"command","func":"setVolume","args":[100]}');
  }
}

void _post(web.HTMLIFrameElement iframe, String json) {
  try {
    iframe.contentWindow?.postMessage(json.toJS, '*'.toJS);
  } on Object {
    // Cross-origin timing; retries handle this.
  }
}

void webYoutubeCommand(String videoId, String func) {
  try {
    final known = _iframes[videoId];
    if (known != null) {
      _post(
        known,
        '{"event":"listening","id":"$videoId","channel":"widget"}',
      );
      if (func == 'setVolume') {
        _post(known, '{"event":"command","func":"setVolume","args":[100]}');
      } else {
        _post(known, '{"event":"command","func":"$func","args":[]}');
      }
      return;
    }
    final frames = web.document.querySelectorAll('iframe');
    final len = frames.length;
    for (var i = 0; i < len; i++) {
      final el = frames.item(i);
      if (el == null) continue;
      final iframe = el as web.HTMLIFrameElement;
      if (!iframe.src.contains(videoId)) continue;
      _iframes[videoId] = iframe;
      _post(
        iframe,
        '{"event":"listening","id":"$videoId","channel":"widget"}',
      );
      if (func == 'setVolume') {
        _post(iframe, '{"event":"command","func":"setVolume","args":[100]}');
      } else {
        _post(iframe, '{"event":"command","func":"$func","args":[]}');
      }
    }
  } on Object {
    // ignore
  }
}
