# Rumuo Project Requirements Audit

**Audit date:** 2026-08-28
**Repository:** `chastechnologiesllc/Rumuo`
**Audited branch:** `main`

## Scope and result

The audit covered the accumulated requirements for the shared Flutter application: responsive Web/Android/iOS behavior, navigation, onboarding and profile personalization, universal search, videos and Shorts, Blogs, books and reading, bookmarks, notifications, media caching, thumbnail fallbacks, data integrity, and CI validation.

The project is structurally ready for shared Flutter delivery. Web and Android workflows already validate analysis, tests, and release artifacts. The repository does not contain the generated `ios/Runner.xcodeproj` host project, so the macOS iOS workflow bootstraps that generated host project with `flutter create` when absent, disables Swift Package Manager for the current CI user because `google_mobile_ads` is CocoaPods-only while `webview_flutter_wkwebview` also exposes SwiftPM integration, removes the generated template test, and then runs Flutter analysis, tests, `flutter build ios --release --no-codesign --config-only`, and an explicit unsigned `xcodebuild` compile. This validates the shared iOS build path without claiming code signing, simulator, or physical-device execution.

## Verified requirements

| Area | Verified implementation | Status |
|---|---|---|
| Shared platform code | Flutter/Dart code is shared across Web, Android, and iOS; no unguarded `dart:io` imports were found in `lib`. Platform-specific browser/native code is isolated behind conditional files or `kIsWeb`. | Pass |
| Web deployment | GitHub Pages uses `/Rumuo/` base href and deploys the release Web build from `main`. | Pass |
| Android delivery | Android manifest includes network, notification, boot, wake-lock, and billing permissions; workflow produces universal APK and AAB. | Pass |
| iOS delivery | iOS deployment target is 14.0, required by the pinned `workmanager_apple` plugin; orientation, Workmanager registration, plugin registration, and ATS policy are present. CI bootstraps the missing generated Xcode host when necessary, disables Swift Package Manager for the CocoaPods-only plugin mix, then compiles iOS without signing. | Pass with generated-host and device/archive limitations |
| Navigation | Main shell, channels, saved, profile, video player, Blog Channel, book detail, reader, search, and notification deep-link routes are present and use shared model contracts. | Pass |
| Search | Universal search indexes categories, channels, blogs, books, videos, Shorts, and playbooks; progressive result batches and no old 120-result cap are covered by tests. | Pass |
| Bookmarks | Saved content covers videos, Shorts, blogs, and books through the shared provider/bookmark model. | Pass |
| Blogs | Selected-category feeds are scoped, category lanes are balanced, general articles remain visible as a secondary lane, feed cache is retained on tab re-entry, and source diversity separates repeats across the scroll. | Pass |
| Blog thumbnails | RSS enclosure/media/HTML/Open Graph/Twitter candidates, proxy alternatives, disk cache, shimmer, bounded retries, fixed aspect ratio, and branded fallback are present. | Pass |
| Books | Verified books route through format-aware detail and reader paths; Gutenberg URLs map to readable bodies; HTML/TXT are sanitized and rendered with controlled colors; PDFs use `pdfrx`; EPUBs use `flutter_epub_viewer`. | Pass |
| Notifications | Browser permission path, Android/iOS local notifications, Workmanager background checks, notification inbox, and cold-start deep links are implemented. | Pass; iOS App Open ad unit remains configuration-dependent |
| Data integrity | Catalog validator confirms 20,000 book records, 18,155 distinct source URLs, 1,845 duplicate source URLs, and 17,642 keyword-bearing records. | Pass |
| Media fallback policy | Literal asset references resolve, raw `Image.network`/`NetworkImage` usage was not found in the audited UI paths, and clickable source labels contain no underlines. | Pass |

## Remaining external configuration

The production iOS App Open ad unit is intentionally unset because an AdMob iOS unit ID cannot be safely invented. Debug iOS uses Google’s test unit, while production iOS falls back to no App Open ad. A real iOS App Open unit must be supplied in `lib/config/app_config.dart` when the AdMob account configuration is available.

The new iOS workflow bootstraps `ios/Runner.xcodeproj` when it is absent, uses the project’s iOS 14 minimum, disables Swift Package Manager for this CI build because the current plugin mix resolves through CocoaPods, prepares the Flutter configuration, and compiles with Xcode signing variables disabled; it does not replace committing a generated Xcode host project, Apple signing, App Store provisioning, simulator testing, or testing on physical browsers/devices. Browser compatibility is covered by the Flutter Web build and shared code review, but no automated matrix of every browser engine is claimed.

## Local checks performed

`git diff --check`, JSON parsing for all data files, the repository catalog validator, literal asset-reference checks, stale PDF API scans, direct network-image scans, platform-conditional scans, and workflow-content assertions passed during the audit.

## References

[1]: https://docs.flutter.dev/perf/best-practices "Performance best practices — Flutter documentation"
[2]: https://docs.flutter.dev/cookbook/images/cached-images "Display images from the internet — Flutter documentation"
[3]: https://tech.facebook.com/engineering/2021/1/news-feed-ranking/ "How does News Feed predict what you want to see? — Tech at Meta"


## Follow-up source and book audit

A second source-level audit was performed after the initial full-project validation. The declared blog catalog contained 443 unique source URLs. Direct verification found 99 feeds that returned XML directly, 277 HTML source pages, 84 HTML pages advertising an RSS/Atom alternate, 55 HTTP 403 responses, 57 HTTP 404 responses, and 60 network/DNS/TLS failures. The original bundled snapshot contained 166 articles from only 11 source names, 95 without a thumbnail URL, and only 3 with fallback candidates.

The feed pipeline was corrected to preserve the verified catalog URL as stable source identity, prefer URL-specific matching over display-name matching, normalize duplicate feed URLs, expand RSS/Atom autodiscovery and conventional feed candidates, parse namespace-agnostic `media:thumbnail`, `media:content`, and enclosure elements, and recognize lazy image attributes, responsive `srcset`, Open Graph, and Twitter image metadata. The regenerated snapshot now contains 2,136 articles from 163 source names, including 1,970 category-tagged records; 626 records carry fallback thumbnail candidates. A remaining missing-thumbnail count is expected because many public providers block automated requests, publish no image metadata, or expose content through JavaScript-only pages. Those records continue to use the branded fallback rather than a fabricated image.

Book verification found 984 of 20,000 records initially had neither a cover URL nor an exact candidate. Source-page metadata and exact Internet Archive identifiers added verified candidates to 85 records, reducing the uncovered count to 899. The shared cover widget now derives additional candidates only from exact Internet Archive item identifiers or Project Gutenberg edition identifiers; it does not perform generic title-only cover searches. The reader now tries mapped readable content before the original landing page, preserving the verified source as the final fallback.

The external behavior assumptions used for the feed changes are based on the [RSS Advisory Board autodiscovery specification](https://www.rssboard.org/rss-autodiscovery) and [Media RSS specification](https://www.rssboard.org/media-rss). Browser and provider restrictions remain external limitations: CI can verify the shared Flutter build, but no automated check can guarantee that every publisher permits access from every browser, network, or device.
