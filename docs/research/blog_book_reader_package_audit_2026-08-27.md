# Rumuo blog and book reader package audit — 2026-08-27

## Verified package findings

- `pdfrx` pub.dev page: version shown as 2.5.0 on 2026-08-27; supports Android, iOS, Web, Windows, macOS, and Linux. It provides `PdfViewer.asset`, `PdfViewer.file`, `PdfViewer.data`, and `PdfViewer.uri`, uses PDFium on native builds, and documents text selection, search, outlines, dark/night mode, loading indicators, and page layout/customization. Source: https://pub.dev/packages/pdfrx
- `flutter_epub_viewer` pub.dev page: version shown as 2.0.0; supports Android, iOS, macOS, and Web. It uses epub.js/iframe behavior on Web and supports EPUB loading from URLs, assets, or data, text selection, search, highlighting, and chapter navigation. The page explicitly warns that `EpubSource.fromUrl` on Web requires permissive CORS headers and that the EPUB iframe composites above Flutter, so overlay controls must stay outside the viewer rectangle. Source: https://pub.dev/packages/flutter_epub_viewer

## Repository findings

- Rumuo already depends on `flutter_epub_viewer`, `flutter_pdfview`, `flutter_inappwebview`, `web`, and custom Web iframe/PDF widgets. Adding packages without resolving current routing/rendering would be premature.
- `BlogChannelScreen` currently shows a five-item shimmer while `_articles` is empty. Its shimmer is made from a `DecoratedBox` with `RumuoShimmer.fillColor(context)` and a `16/10` placeholder. If the fetch never completes or returns no articles, the page can look like a blank grey surface without an explicit fallback until the async path settles.
- `BlogChannelScreen` depends on `context.watch<FeedProvider>()`; a route outside the provider tree would fail before rendering, so route/provider placement must be verified in the app shell.
- `web_iframe_view_web.dart` creates a new timestamped platform-view type and returns a raw iframe with a white background. The repository’s Web YouTube player uses a stable platform-view wrapper and an explicit colored backing surface to avoid grey/white platform-view flashes; the same defensive pattern is relevant to Web document views.
- `BookDetailScreen` already routes known Gutenberg/Global Grey EPUBs to `flutter_epub_viewer` on native and to HTML URL transformations on Web; bundled PDFs use `flutter_pdfview` on native and a custom Web PDF blob view. Verified category books with `freeSourceUrl` are generally routed through `BlogReaderScreen`, which means HTML/PDF/EPUB behavior varies by caller.
- `SavedScreen` reportedly routes saved verified books directly to `BlogReaderScreen` instead of `BookDetailScreen`, so book fixes must cover saved-book navigation as well as the main catalog route.

## Screenshot interpretation

- The first screenshot shows a uniform grey body with no visible Flutter AppBar/content, consistent with a Web platform-view/bootstrap or unresolved loading surface rather than a normal populated Blog Channel list.
- The second screenshot shows a book opened as raw HTML inside a dark/black Web surface. Text and a blue selection overlay are visible, while the page’s link/metadata content is visually intrusive. This supports moving book reading away from generic article HTML where a structured document reader is available, and applying explicit reader CSS/background control when HTML is the only compatible fallback.

## Research direction

1. First prove and fix Blog Channel lifecycle/rendering on Web: ensure a deterministic non-grey loading state, surface errors, render cached/seed data immediately, and avoid unstable platform-view construction where applicable.
2. Normalize book URL/format detection and centralize routing for EPUB, PDF, HTML, and plain text across catalog and saved-book entry points.
3. Keep existing EPUB support unless a verified package replacement is justified by actual CI/API compatibility; consider `pdfrx` only if its Web/native support meaningfully removes the current PDF split and passes the project’s Flutter 3.44.0 Android/Web workflows.
4. Use reader-specific CSS for HTML book fallback: opaque background, readable text color, controlled link styling, and removal/hiding of publisher metadata when it is not part of the actual book body.
5. Validate Web and Android in GitHub Actions; iOS remains unbuilt in the available CI unless an iOS workflow exists.

## References

[1]: https://pub.dev/packages/pdfrx "pdfrx — Flutter package"
[2]: https://pub.dev/packages/flutter_epub_viewer "flutter_epub_viewer — Flutter package"

## Live deployment verification

- The canonical deployment `https://chastechnologiesllc.github.io/Rumuo/` bootstrapped in the browser and showed the Rumuo onboarding shell.
- The exact screenshot hostname `https://stechnologiesllc.github.io/Rumuo/` returned GitHub Pages `404 — There isn't a GitHub Pages site here.` This is a confirmed deployment-host mismatch and can independently explain a uniform grey/blank page if the screenshot was taken from that address. The app code still needs a defensive Blog Channel loading fix, but the screenshot URL must be corrected to the canonical host after deployment.

## Additional references

[3]: https://chastechnologiesllc.github.io/Rumuo/ "Canonical Rumuo GitHub Pages deployment"
[4]: https://stechnologiesllc.github.io/Rumuo/ "Screenshot hostname: GitHub Pages 404"

## Compatibility correction

- Direct pub.dev API metadata confirms `pdfrx` 2.5.0 requires Dart `^3.12.0` and Flutter `>=3.47.0`, which is incompatible with Rumuo’ Flutter 3.44.0 CI. The newest listed compatible line is `pdfrx` 2.4.8, requiring Flutter `>=3.41.0`; the implementation pins `pdfrx: ^2.4.8` rather than the latest incompatible release.
- `flutter_html` 3.0.0 requires Flutter `>=3.0.0` and supports Android, iOS, Web, Windows, macOS, and Linux, so it is compatible with the project’s Flutter 3.44.0 baseline.
- `flutter_epub_viewer` 2.0.0 requires Dart `>=3.8.0 <4.0.0`, adds Web/macOS support, and is compatible with the project’s Dart/Flutter baseline.

[5]: https://pub.dev/packages/flutter_html "flutter_html — Flutter package"
[6]: https://pub.dev/api/packages/pdfrx "pdfrx package metadata and SDK constraints"
[7]: https://pub.dev/packages/flutter_epub_viewer/changelog "flutter_epub_viewer 2.0.0 changelog"
