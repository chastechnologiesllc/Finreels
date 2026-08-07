import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

/// Browser JSONP helper. Bypasses CORS for APIs that support callback=.
Future<Map<String, dynamic>> fetchJsonp(String url) {
  final completer = Completer<Map<String, dynamic>>();
  final cbName =
      'finreels_jsonp_${DateTime.now().microsecondsSinceEpoch}';

  js.context[cbName] = (dynamic data) {
    try {
      final jsonStr =
          js.context['JSON'].callMethod('stringify', [data]) as String;
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      if (!completer.isCompleted) completer.complete(decoded);
    } catch (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    } finally {
      js.context.deleteProperty(cbName);
      html.document.getElementById(cbName)?.remove();
    }
  };

  final sep = url.contains('?') ? '&' : '?';
  final script = html.ScriptElement()
    ..id = cbName
    ..async = true
    ..src = '$url${sep}callback=$cbName';

  script.onError.listen((_) {
    js.context.deleteProperty(cbName);
    script.remove();
    if (!completer.isCompleted) {
      completer.completeError(Exception('JSONP load failed for $url'));
    }
  });

  html.document.head!.append(script);

  return completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      js.context.deleteProperty(cbName);
      script.remove();
      throw TimeoutException('JSONP timed out for $url');
    },
  );
}
