# Fix web_jsonp analyze errors

## What failed
```
error • deleteProperty isn't defined for Window  (web_jsonp_web.dart)
error • JSON isn't defined through prefix web   (web_jsonp_web.dart)
```

`package:web`'s Window is not the same API as the previous draft used.
Correct interop (from dart:js_interop_unsafe):

- `JSObject.setProperty` / `JSObject.delete` (not deleteProperty)
- Convert JS values with `JSAny.dartify()` (no web.JSON.stringify)

## Copy into your repo
```
lib/utils/web_jsonp_web.dart
lib/utils/web_jsonp.dart
lib/utils/web_jsonp_stub.dart
lib/services/connectivity_service.dart   (optional, quiets 2 infos)
```

Remaining items in the log are **info**-only on older screens and do not fail
`flutter analyze --no-fatal-infos`.
