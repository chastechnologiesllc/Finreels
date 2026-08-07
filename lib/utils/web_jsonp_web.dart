// ignore_for_file: avoid_web_libraries_in_flutter
// Web-only file (conditional export). JSONP needs script-tag injection.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Browser JSONP helper. Bypasses CORS for APIs that support callback=.
Future<Map<String, dynamic>> fetchJsonp(String url) {
  final completer = Completer<Map<String, dynamic>>();
  final cbName =
      'finreels_jsonp_${DateTime.now().microsecondsSinceEpoch}';

  void cleanup() {
    web.window.deleteProperty(cbName.toJS);
    web.document.getElementById(cbName)?.remove();
  }

  // Global callback invoked by the remote script.
  web.window.setProperty(
    cbName.toJS,
    ((JSAny? data) {
      try {
        final jsonStr = (web.JSON.stringify(data) as JSString).toDart;
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;
        if (!completer.isCompleted) completer.complete(decoded);
      } on Object catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      } finally {
        cleanup();
      }
    }).toJS,
  );

  final sep = url.contains('?') ? '&' : '?';
  final script = web.HTMLScriptElement()
    ..id = cbName
    ..async = true
    ..src = '$url${sep}callback=$cbName';

  script.onerror = (web.Event event) {
    cleanup();
    if (!completer.isCompleted) {
      completer.completeError(Exception('JSONP load failed for $url'));
    }
  }.toJS;

  web.document.head!.append(script);

  return completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      cleanup();
      throw TimeoutException('JSONP timed out for $url');
    },
  );
}
