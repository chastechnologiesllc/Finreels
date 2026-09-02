import 'package:web/web.dart' as web;

/// Tells the static HTML boot screen that Flutter has reached the first usable
/// app state. This keeps the HTML screen visible through Flutter engine startup
/// instead of hiding it on the first transparent Flutter frame.
void markWebBootReady() {
  try {
    web.window.dispatchEvent(web.Event('rumuo-app-ready'));
  } on Object {
    // The HTML boot layer has its own timeout fallback, so this signal is
    // intentionally best-effort and must never affect app startup.
  }
}
