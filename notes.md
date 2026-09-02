# Rumuo platform-lock + white-wash fixes

Applies on **Android, iOS, and Web**.

## What was wrong

1. **White wash over video**
   - `youtube_player_flutter` v9 paints a light loading surface if `thumbnail` is unset.
   - `AnimatedOpacity(0)` does **not** hide Android platform views (WebView still shows).
   - Light-theme Rumuo chip used near-white `0xF2FFFFFF`.

2. **"Watch on YouTube"**
   - Native YT chrome / logo / end cards can push users off-app.
   - Web already used `pointer-events:none` + `controls=0`; kept and documented.

## What this package changes

### White wash (all platforms)
- `thumbnail: ColoredBox(color: Color(0xFF000000))` on every `YoutubePlayer`
- Full-size player only after real frames (`_revealPlayer`); pre-warm is 1×1 off-screen
- Watermark always dark + gold (never white plate)
- Shimmer under video is black

### Locked in Rumuo (playback stays in-app)
- Mobile: `hideControls: true`, `enableCaption: false` (Android + iOS)
- Web: `controls=0`, `fs=0`, `disablekb=1`, `modestbranding=1`, `rel=0`
- Web: iframe `pointer-events: none`, sandbox **without** top-navigation/popups
- Web: `youtube-nocookie` + `origin` = this host
- Custom end overlay instead of YT end-screen recommendations
- Rumuo chip over native YT logo region (bottom-right)

### Not changed on purpose
- **Share** still can include a YouTube link so users can share a video link.
  That is share, not in-player "Watch on YouTube".
- Blog/book external free sources still open in browser when that is the source type.

## Files
```
lib/widgets/inline_video_card.dart
lib/widgets/web_youtube_player.dart
lib/widgets/web_youtube_player_stub.dart
lib/widgets/web_youtube_player_web.dart
lib/screens/video_player_screen.dart
lib/screens/shorts_player_screen.dart
```

> `lib/screens/video_landscape_screen.dart` was listed here but has been
> deleted — see "Audit fixes" below; `video_player_screen.dart` now handles
> landscape in-place and this file had zero imports left.

Full rebuild after applying (asset/player changes need more than hot reload).

---

## Audit fixes (round 2)

Systematic audit of the full codebase — every change below is grounded in
the actual file content, no guessing.

### Files deleted

| File | Reason |
|------|--------|
| `lib/screens/video_landscape_screen.dart` | Dead code — `VideoPlayerScreen` handles landscape in-place via `_isLandscape`; this file had zero imports anywhere in the project. |
| `android/app/src/main/kotlin/com/chastech/rumuo/MainActivity.kt` | Stale package from an earlier rename. `applicationId` is `com.chastechgroup.rumuo`; the `com.chastech` tree registered its own MethodChannel under the wrong package, which could shadow the correct implementation and break the Play Store / sideload detection used by the Paystack billing rail. |
| `android/app/src/main/kotlin/com/chastech/rumuo/MainApplication.kt` | Same stale package — deleted with the directory above. |
| `rumuo_test.dart` *(project root)* | Flutter scaffold leftover. `flutter test` only looks under `test/`; this file was never executed. The real test suite is at `test/rumuo_test.dart`. |

### Files modified

| File | What changed |
|------|--------------|
| `ios/Runner/Info.plist` | Added `UIInterfaceOrientationLandscapeLeft` and `UIInterfaceOrientationLandscapeRight` to both `UISupportedInterfaceOrientations` (iPhone) and `UISupportedInterfaceOrientations~ipad`. Without these entries `SystemChrome.setPreferredOrientations()` is silently ignored by iOS — the fullscreen landscape toggle in `VideoPlayerScreen` and `ShortsPlayerScreen` was completely broken on every iOS device. |
| `ios/Runner/AppDelegate.swift` | Added `application(_:supportedInterfaceOrientationsFor:) → .all` override. This is the second half of the iOS landscape fix — Flutter's orientation API is routed through this delegate method, so it must return `.all` for `setPreferredOrientations` to have any effect. |
| `lib/data/channel_data.dart` | `combined` and `byId` were live getters that allocated a fresh `List` / `Map` on every call. Both are called inside `ListView.builder` and `GridView.builder` itemBuilders (i.e. per scroll frame) and `byId` calls `combined` internally, so every scroll frame was paying for a full channel-list rebuild. Fixed with nullable static caches (`_combinedCache`, `_byIdCache`) and a `static invalidateCache()` method. |
| `lib/data/resource_category_data.dart` | Calls `ChannelData.invalidateCache()` at the end of `_loadVerifiedResources()` so the next access to `combined` / `byId` picks up the full verified channel set. |
| `lib/widgets/web_youtube_player_web.dart` | `viewType` was `'rumuo-yt-$videoId-${DateTime.now().microsecondsSinceEpoch}'` — a new unique key on every call. `ui_web.platformViewRegistry.registerViewFactory` inserts into a permanent global registry with no unregister API, so every rebuild leaked one factory entry. Fixed: `viewType = 'rumuo-yt-$videoId'` (stable), guarded by a top-level `Set<String>` so `registerViewFactory` is called at most once per video ID. Stale `// ignore_for_file: avoid_web_libraries_in_flutter` comment also removed (file uses `dart:js_interop` + `package:web`, not `dart:html`). |
| `lib/services/ad_service.dart` | Removed `_bannerAd`, `_bannerReady`, `_loadBanner()`, and the `bannerAd` legacy getter. `LabelledBannerAd` and `StickyBannerBar` each own their own `BannerAd` instance; the one in `AdService` was loaded and retried on failure but its `AdWidget` was never placed in the widget tree — a phantom ad request consuming an impression slot every session. |
| `lib/providers/feed_provider.dart` | Removed `_isBlog()` method; `FeedTab.blogs` branch in `_compute()` now returns `const []`; `allVideos` getter excludes `FeedTab.blogs` from its `FeedTab.values` loop. The Blogs tab in `home_screen.dart` routes directly to `BlogFeedScreen` (which reads `BlogRssService`), so FeedProvider's blog-filtered YouTube list was computed but never displayed anywhere. Excluding it from `allVideos` also unblocks the deep-link loading check, which previously stalled waiting for a list that would always be empty. |
| `android/app/src/main/AndroidManifest.xml` | Removed `android:usesCleartextTraffic="true"` — every endpoint (YouTube RSS, blog RSS, Paystack, AdMob) uses HTTPS; the flag was a broad security hole. Removed `SCHEDULE_EXACT_ALARM` (triggers a mandatory user-permission dialog on Android 12) and `USE_EXACT_ALARM` (requires Play Store policy approval on API 33+); WorkManager uses inexact alarms by default and neither permission is required for 15-minute periodic tasks. |
| `lib/config/app_config.dart` | Removed `admobAppId` getter — AdMob SDK reads the App ID from `AndroidManifest.xml` (`com.google.android.gms.ads.APPLICATION_ID` meta-data) and `Info.plist` (`GADApplicationIdentifier`) directly; the Dart getter was never called and its iOS branch returned the Android ID anyway. |
| `pubspec.yaml` | Removed `in_app_purchase_storekit: ^0.3.17` — `in_app_purchase` is a federated plugin that brings in its own iOS implementation (`in_app_purchase_storekit`) as a transitive dependency; listing the platform implementation explicitly can cause version constraint conflicts. |

### AdSense (web) — intentionally kept as test

`web/index.html` and `lib/config/app_config.dart` still use the Google
AdSense **test** publisher ID (`ca-pub-3940256099942544`) and
`adsenseTestMode = true`. This is deliberate — the web AdSense integration
is still being worked on. When ready to go to production:

1. Replace `client=ca-pub-3940256099942544` in `web/index.html` with the
   real production publisher ID.
2. Update `adsenseClientId` and `adsenseTestSlot` in `app_config.dart`
   with the real values.
3. Set `adsenseTestMode = false` in `app_config.dart`.

