# Rumuo System Optimization Audit

## Baseline

The repository is clean on `main` at commit `c92e5d4`. The CI baseline has previously passed Flutter analysis, tests, Web release build, GitHub Pages deployment, Android production APK packaging, and Android production AAB packaging.

The project is a Flutter 3.44.x application targeting Web, Android, and iOS. It uses Provider, SharedPreferences, Hive, HTTP/RSS feeds, cached network images, WebView/iframe integrations, YouTube playback plugins, AdMob, in-app purchases, notifications, WorkManager, and EPUB/PDF readers.

## Initial findings

| Area | Finding | Risk | Planned treatment |
|---|---|---|---|
| Flutter Web SEO | Flutter Web is optimized for app-centric experiences rather than static, text-rich SEO pages. The current app is an app-centric feed, but its HTML shell should still have complete metadata and correct install/deep-link behavior. | Search engines may index only the shell rather than article/book content. | Preserve useful shell metadata; do not claim full document SEO from a Canvas/Flutter app. |
| Responsive behavior | Web manifest declares `portrait-primary`; Android manifest and startup code lock the main app to portrait, while the player temporarily enables landscape. | Tablets, foldables, desktop windows, and split-screen use may be constrained. | Audit layout readiness before changing the product’s portrait-first navigation policy. Remove only locks that are safe and independently validated. |
| Shimmer/loading | Direct shimmer calls were distributed across shared loader, BlogFeedScreen, ChannelVideosScreen, BookCoverImage, BlogThumbnailImage, VideoThumbnailImage, and search. | Inconsistent animation/contrast and duplicated palette logic. | Centralize treatment with `RumuoShimmer` and one stronger theme-aware palette. |
| Feed startup | FeedProvider reads all cached channels sequentially, then refreshes many channels concurrently. | Startup and refresh can spend unnecessary time in serial disk reads and issue high concurrent network load. | Consider parallel cache reads and bounded network concurrency, preserving current stale-cache behavior. |
| RSS parsing | RSS XML parsing already uses `compute`, which is good for UI responsiveness. Web RSS uses two concurrent CORS proxies per channel and retries. | Proxy races can create high request fan-out in browsers. | Measure/limit concurrency carefully; preserve fallback behavior. |
| Blog hydration | Up to 40 article pages may be hydrated concurrently when candidates are sparse. | Large burst of browser/native requests and possible battery/network cost. | Introduce bounded hydration concurrency and retain candidate limits. |
| Connectivity | The service has periodic checks plus connectivity-change checks without an in-flight guard. | Overlapping probes can waste battery and create duplicate HTTP traffic. | Add a single-flight/debounce guard and preserve offline overlay semantics. |
| Android architectures | Release config includes ARMv7 and ARM64 only; x86/x86_64 are excluded intentionally. | Chromebook/emulator compatibility is limited. | Document the trade-off and assess whether x86 release support is required before changing package size/compatibility. |
| Web workflow | `build_web.yml` has a suspiciously escaped concurrency group string and deploys the app shell to GitHub Pages. | CI cancellation may not group runs as intended. | Validate and correct workflow syntax if confirmed. |

## Research anchors

Flutter’s official performance guidance recommends minimizing expensive work in `build()`, using `const` widgets, using lazy list/grid builders, avoiding unnecessary opacity/clipping, and targeting frame work within the 16 ms budget [1]. Flutter’s adaptive-design guidance recommends using available window constraints rather than device-type assumptions, avoiding orientation-locked layouts where possible, supporting mouse/trackpad/keyboard input, and preserving list/app state across size changes [2]. Flutter’s Web FAQ states that Flutter Web is intended for app-centric experiences and does not naturally produce the document structure required for traditional SEO; static/document-like content should use HTML or a DOM-oriented framework [3].

## References

[1]: https://docs.flutter.dev/perf/best-practices "Flutter performance best practices"
[2]: https://docs.flutter.dev/ui/adaptive-responsive/best-practices "Flutter best practices for adaptive design"
[3]: https://docs.flutter.dev/platform-integration/web/faq "Flutter Web FAQ"

## Additional verified findings

The application had several safe optimization opportunities that did not require changing the content model. `ConnectivityService` could run overlapping five-second and thirty-second probes when connectivity events and timers coincided. `AdBlockService` could accumulate connectivity listeners and overlap its neutral/ad endpoint probes if initialized more than once or triggered near a timer boundary. `FeedProvider` loaded cached channel entries serially and launched all selected channel refreshes at once. `BlogRssService` could hydrate up to 40 article pages concurrently. The expanded channel-history path had no short-lived in-memory cache and could re-scrape a channel on repeated visits.

The Web shell lacked an explicit viewport meta tag and canonical URL. The PWA manifest locked orientation to `portrait-primary`, while the native bootstrap globally locked the main application to portrait even though iOS declared landscape support and player routes already managed temporary orientation changes. The Android activity also declared a global portrait lock. The Web Actions workflow contained an incorrectly escaped concurrency group expression, and the Android workflow used the deprecated `actions/setup-java@v4` action.

Planned safe changes are limited to single-flight/debounced service work, bounded concurrency, short-lived history caching, correct Web shell metadata and PWA scope, orientation-policy consistency, and CI maintenance. No title-only cover matching, content-source removal, or browser-specific unsupported API is being introduced.

## Web accessibility and search research

Flutter Web translates its internal Semantics tree into an accessible HTML DOM, but the accessibility tree is opt-in for performance reasons unless the user enables it or the app calls `SemanticsBinding.instance.ensureSemantics()` [4]. Flutter’s accessibility checklist recommends testing TalkBack and VoiceOver, maintaining at least 4.5:1 contrast for normal text where applicable, keeping tappable targets at least 48 by 48 pixels, and testing large text/display scale factors [5].

Google Search processes JavaScript in crawl, render, and index phases, but server-side or static rendering is still faster and more reliable for crawlers; Google also recommends canonical URLs in the original HTML, crawlable links with `href`, meaningful status codes, fingerprinted assets for cache invalidation, and lazy-loading images appropriately [6]. Google describes dynamic rendering as a temporary workaround and recommends server-side/static rendering or hydration instead [7]. Because Rumuo is an app-centric Flutter Web experience deployed as a static shell, the safe scope is improving shell metadata, PWA scope, browser startup, accessibility semantics, and asset delivery—not claiming that dynamic in-app feed content is fully SEO-indexable by every search engine.

[4]: https://docs.flutter.dev/ui/accessibility/web-accessibility "Flutter Web accessibility"
[5]: https://docs.flutter.dev/ui/accessibility "Flutter accessibility release checklist"
[6]: https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics "Google JavaScript SEO basics"
[7]: https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering "Google dynamic rendering guidance"

## Accessibility and native platform audit results

Rumuo already uses standard Material controls for most interactive elements and has explicit semantics on the custom floating navigation bar. The Web bootstrap now enables Flutter’s semantics DOM by default, improving screen-reader discoverability while accepting the documented Web accessibility-tree overhead. Existing minimum tap-target and large-text behavior should still be verified manually with TalkBack, VoiceOver, browser zoom, and OS display scaling because static analysis cannot certify visual accessibility.

The iOS target is already set to iOS 13, disables deprecated bitcode, and declares portrait plus landscape orientations. Android targets SDK 36, has a minimum SDK of 23, enables hardware acceleration and Java 17, and intentionally ships ARMv7 and ARM64 release slices. x86/x86_64 release support remains excluded to keep phone/tablet artifacts smaller; that is a packaging trade-off rather than a runtime defect for physical ARM phones and tablets. Android cleartext support remains enabled because the legal/free resource catalog still contains legacy HTTP sources; those sources should be migrated individually only after confirming HTTPS availability and content identity.

## Implemented optimization set

The implementation adds single-flight connectivity probes, idempotent and single-flight ad-block detection, memoized AdService startup, bounded feed refresh workers, parallel cache hydration, bounded blog-page hydration workers, and a ten-minute in-memory cache for expanded channel history. It also prevents duplicate notification deep-link scheduling, bounds Shorts page retention to the active/warm-neighbour window, hardens empty video thumbnail inputs, and guards malformed native channel IDs.

The adaptive-device changes remove the global portrait lock from the main Flutter bootstrap and Android activity, restore all four orientations when leaving player routes, and retain route-level portrait/landscape behavior where the media experience needs it. The Web shell now includes viewport, canonical, robots, application-name, relative PWA scope, install identity, language, and crawler files. Web semantics are enabled at startup for screen-reader support. CI concurrency is corrected for Web and added to Android; Android uses `actions/setup-java@v5`.

Regression coverage now includes the shared shimmer animation period, both light/dark shimmer build paths, and the empty video-ID thumbnail fallback. Flutter analyzer, widget tests, Web release build, Android APK/AAB packaging, and real-device accessibility/orientation checks remain necessary validation layers; iOS native packaging requires a macOS runner and is not available in the current Linux CI workflow.
