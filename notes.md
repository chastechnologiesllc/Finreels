# Web playback / content fix

## Diagnosed from screenshots + code

1. **Videos stuck on spinner** — Browsers block **unmuted autoplay**. Player started with `mute: false` on web.
2. **Shorts don’t scroll** — Mobile uses `NeverScrollableScrollPhysics` + custom vertical drag (needed because Android WebView steals gestures). On **web**, that custom drag fights the YouTube iframe → scroll broken. Web now uses native `PageScrollPhysics`.
3. **Blogs empty** — `BlogRssService.fetchAll` fired many feeds in parallel via JSONP; free rss2json rate-limits → empty list. Web now fetches **sequentially**.
4. **Blog reader / book PDF-EPUB** — `InAppWebView` / `flutter_pdfview` / epub widgets are mobile-oriented; on web open via **url_launcher** (new tab) with a clear CTA.
5. **Platform icons** — `web/favicon.png`, `web/icons/*`, `manifest.json` theme set to FinReels gold (`#F5A623`) and launcher-derived icons.

## Android / iOS
Unchanged paths (mute off for long-form, custom shorts gestures, in-app WebView/PDF/EPUB).

## Copy into repo
```
lib/screens/shorts_player_screen.dart
lib/screens/video_player_screen.dart
lib/screens/blog_reader_screen.dart
lib/screens/book_detail_screen.dart
lib/services/blog_rss_service.dart
web/index.html
web/manifest.json
web/favicon.png
web/icons/Icon-192.png
web/icons/Icon-512.png
web/icons/Icon-maskable-192.png
web/icons/Icon-maskable-512.png
```

## After deploy
Hard-refresh the site. Tap once on a video to unmute. Swipe shorts vertically. Open Blogs and wait (sequential load is slower but fills). Books: “Open book” on web.
