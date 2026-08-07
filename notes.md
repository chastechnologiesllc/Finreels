# Analyze fix (CI exit code 1)

## Cause
`flutter analyze --no-fatal-infos` still fails on **warnings**.
The failing warning was:

```
unused_import — package:path_provider in pdf_download_service.dart
```

## Fixed in this package
1. Removed unused `path_provider` import from `pdf_download_service.dart`
2. Import ordering in `rss_service.dart` / `blog_rss_service.dart`
3. Unnecessary `\\~` escapes in AdMob app IDs (`app_config.dart`)
4. JSONP helper migrated off deprecated `dart:html` / `dart:js` → `package:web` + `dart:js_interop`

## Dependency
Flutter already pulls `package:web` transitively. If analyze reports missing `package:web`, add under dependencies:

```yaml
  web: ^1.1.0
```

## Remaining infos (pre-existing screens — not fatal with --no-fatal-infos)
home_screen cacheExtent, notification_settings activeColor, shorts/video catch clauses, prefer_const_constructors, etc. Safe to leave; they do not fail CI with your current flags.

## Copy paths
```
lib/config/app_config.dart
lib/services/pdf_download_service.dart
lib/services/pdf_io_io.dart
lib/services/pdf_io_stub.dart
lib/services/connectivity_service.dart
lib/services/rss_service.dart
lib/services/blog_rss_service.dart
lib/services/ad_block_service.dart
lib/utils/web_jsonp.dart
lib/utils/web_jsonp_web.dart
lib/utils/web_jsonp_stub.dart
```
