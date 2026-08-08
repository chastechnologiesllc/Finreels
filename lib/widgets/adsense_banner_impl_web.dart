// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Injects the AdSense loader once and mounts an <ins class="adsbygoogle"> unit.
Widget buildAdSenseUnit({
  required String clientId,
  required String slotId,
  required bool testMode,
}) {
  final existing = web.document.querySelector(
    'script[src*="pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"]',
  );
  if (existing == null) {
    final script = web.HTMLScriptElement()
      ..async = true
      ..src =
          'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$clientId'
      ..crossOrigin = 'anonymous';
    web.document.head?.append(script);
  }

  final viewType =
      'finreels-adsense-$slotId-${DateTime.now().microsecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final ins = web.document.createElement('ins') as web.HTMLElement;
    ins.className = 'adsbygoogle';
    ins.style.display = 'block';
    ins.style.width = '100%';
    ins.style.height = '100%';
    ins.setAttribute('data-ad-client', clientId);
    ins.setAttribute('data-ad-slot', slotId);
    ins.setAttribute('data-ad-format', 'auto');
    ins.setAttribute('data-full-width-responsive', 'true');
    if (testMode) {
      ins.setAttribute('data-adtest', 'on');
    }

    Future.microtask(() {
      final s = web.HTMLScriptElement()
        ..text = '(adsbygoogle = window.adsbygoogle || []).push({});';
      web.document.body?.append(s);
      s.remove();
    });

    return ins;
  });

  return HtmlElementView(viewType: viewType);
}
