# Rumuo — Changes This Session

14 files modified, 1 file deleted. Extract this zip's `Rumuo/` folder
over your existing project to apply.

## Deleted

- **`lib/screens/discover_screen.dart`** — fully built but had zero
  navigation entry points anywhere in the app. `ContentSearchScreen` already
  provides the same category-browsing path via `CategoryDetailScreen`, so
  nothing was orphaned by removing it.

## Modified

### `lib/screens/video_player_screen.dart`
Bookmark icon used `ValueListenableBuilder<int>` on a fresh, never-mutated
`ValueNotifier(0)` — it rebuilt once on mount and then never again, so the
icon didn't reflect saves. Replaced with `ListenableBuilder` on
`FeedProvider.instance`.

### `lib/screens/category_detail_screen.dart`
`_PlaybookCard` used `firstWhere` with no `orElse` — throws `StateError` and
crashes the screen if a category has no matching playbook entry. Replaced
with a null-safe `where().isEmpty` guard.

### `lib/utils/category_search.dart`
Doc comment referenced the now-deleted `discover_screen.dart` by name.
Updated to describe its actual sole remaining consumer
(`my_business_screen.dart`).

### `lib/config/app_config.dart`
All 5 iOS production ad unit IDs (banner, interstitial, rewarded,
rewardedInterstitial, and `nativeAdUnitId` — unused anywhere but had the
same bug) silently duplicated the Android production ID, which is invalid
in AdMob. Replaced with explicit `REPLACE_WITH_IOS_..._AD_UNIT_ID`
placeholders that fail safely (no-fill, not a crash) until real iOS units
are created.

### `lib/services/ad_service.dart`
3 of 5 tap-counter doc comments didn't match their actual
`AppConfig` thresholds (video/blog said "8, 16, 24", actually fire at
"4, 8, 12"; book said "4, 8, 12", actually fires at "6, 12, 18"). Corrected
all 3.

### `lib/screens/profile_screen.dart`
`_AppInfoCard`'s inner `Column` had no `crossAxisAlignment`, so the app
name/version text centered instead of left-aligning next to the icon. Added
`CrossAxisAlignment.start`.

### `android/app/src/main/AndroidManifest.xml`
Removed `USE_EXACT_ALARM` — confirmed unused anywhere in Dart or native
code (WorkManager only uses inexact `frequency`/`initialDelay` scheduling),
and it's a Play Store review risk for apps that aren't clock/alarm apps.
`SCHEDULE_EXACT_ALARM` (maxSdkVersion=32) left untouched — lower risk,
scoped to old API levels only.

### `lib/screens/privacy_policy_screen.dart`
Added disclosure that web users' blog/RSS requests route through
`corsproxy.io`/`api.allorigins.win` (not used on Android/iOS).

### `lib/screens/main_shell.dart`
Notification badge previously lived only in `HomeScreen`'s header, invisible
from Shorts/Saved/Profile tabs. Added a `Badge` + `ValueListenableBuilder`
on the Feed tab's bottom-nav icon (same `NotificationStore.unreadCount`
source), visible from every tab since the nav bar itself is always
rendered.

### `lib/screens/channels_screen.dart`
Bottom-nav Shorts had its own disconnected tap counter
(`interstitialEveryNChannelsPage = 12`), separate from the shared counter
`home_screen.dart`'s Shorts tab and `saved_screen.dart` both already used.
Now calls the shared `AdService.onShortTapped()` — also fixes a smaller bug
where the old path could fire an interstitial even with ads removed (paid).

### `lib/screens/book_detail_screen.dart`
Two real EPUB-reading gaps, both confirmed via full call-graph tracing:
- **Native**: a failed load spun forever with no escape. Added a 20s
  timeout (plain `Timer`, since `flutter_epub_viewer`'s API beyond what
  this codebase already uses couldn't be verified without network access)
  with Try Again / Open Source UI, and a `Key`-based forced remount for
  retry.
- **Web**: `.epub` URLs from hosts other than Gutenberg/Global Grey can
  render blank in the package's iframe view, with no reliable way to detect
  that from Flutter. Added a persistent "open in browser" action to the app
  bar so there's always an escape hatch.

### `lib/screens/book_content_reader_screen.dart`
**Root cause of the reported "book opens the website instead of the app"
bug.** The fetch tried up to 6 fallback URLs (2 sources × 2 CORS proxies,
plus 2 direct) **sequentially**, each with its own 18s timeout — one slow
proxy could burn the full 18s before the next candidate was even
attempted, so worst case was 4-6× the nominal timeout behind one static
spinner. Rewrote to race every candidate in parallel (`Completer`-based,
modeled directly on the already-proven pattern in
`RssService._tryFetchWeb()`), bumped the per-candidate timeout to 25s (safe
now that it's not multiplying), and made the loading message honest about
longer books taking a moment. Verified via direct fetch that the reported
URL itself works fine — the bug was purely in the fetch strategy, not the
content or the URL-mapping logic.

### `lib/screens/splash_screen.dart`
Tagline changed from "Opening your learning space…" to "Opening your
discovery screen…". Mobile splash duration extended 900ms → 1500ms
(deliberate choice, confirmed) — comment updated since it previously
argued against a longer hold.

### `web/index.html`
Same tagline change, kept in sync — this is a **second, independent**
copy of the same string; web never touches `splash_screen.dart` at all
(uses this static HTML boot screen instead), so this needed its own edit.
Web boot duration intentionally left untouched — stays tied to real
load/init time, no artificial hold added (confirmed).

## Flagged, not changed — needs your call

- **OpenStax entries (267)**: legitimate/free (Rice University, CC BY), but
  the catalog mostly stores landing pages, and even with a URL fix,
  `BookContentReaderScreen` only renders one page — OpenStax textbooks are
  multi-chapter. Needs real chapter navigation to be useful, not a quick
  patch.
- **Archive.org entries (135)**: mixed. Some are genuinely free; others
  (Rich Dad Poor Dad, The E-Myth Revisited, Profit First, Traction, The
  Personal MBA, The $100 Startup, and more) are actively-copyrighted
  commercial bestsellers under Archive.org's Controlled Digital Lending —
  confirmed via search, these require an account and time-limited
  borrowing, not open access. Some other entries have a non-functional
  placeholder URL (`https://archive.org` with no specific item). Not
  something to code around — needs a labeling/catalog decision.
- **Issues 14/15/16** from the original audit (deep-link books-tab gap,
  WebView pre-warm cap, playbook dead-end fallback) — never explicitly
  resolved either way in this session.
- **`_buildReader()`'s unmapped-URL fallback and `PdfDownloadService
  .downloadPdf()`'s unreachable web branch** — both confirmed dead code
  (can't currently fire given the call graph), harmless today, worth a
  cleanup pass sometime.
