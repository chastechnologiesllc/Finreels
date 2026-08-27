# FinReels Blogs Tab Performance and Relevance Audit

## Verified findings

FinReels currently uses a selection-scoped aggregate blog feed: five general feeds are always included, while category-tagged feeds are included only when their category ID is selected. The service already performs bounded feed fetching, snapshot fallback, RSS/Atom parsing, thumbnail candidate hydration, a ten-minute in-memory cache, and a 3:1 selected-category-to-general interleave.

The main performance defect is in `FeedProvider.setTab`: every time the Blogs tab is selected, it calls `BlogRssService.instance.clearCache()`. That defeats the service’s ten-minute cache on ordinary tab re-entry and forces another network fetch before the tab can render. Category changes should continue clearing the cache, because the selected feed set changes, but ordinary tab selection should preserve the cache.

The current Blogs UI waits for `BlogRssService.fetchAll()` before it receives any articles. The bundled snapshot is already memoized and suitable for fast first paint, so the next implementation should expose a category-scoped local seed or cached result immediately, then refresh live RSS in the background and atomically merge the result.

Blog thumbnail parsing already collects enclosure, media, HTML, Open Graph, Twitter, and first-image candidates, adds image-proxy alternatives, and uses `cached_network_image` with a shared 30-day cache. The remaining optimization target is to avoid hydrating article pages before first paint: thumbnail metadata enrichment should be bounded and performed after visible cached/snapshot articles are shown. Fixed 16:9 constraints and decode-size limits should remain.

For feed relevance, the design will preserve a two-stage pipeline: retrieve candidate articles cheaply, then rank with selected-category relevance and source diversity while keeping a smaller, date-ordered general pool visible. This follows the documented multi-stage ranking pattern used by large feeds, where candidate retrieval, scoring, and contextual diversity are separate steps rather than one expensive operation [1].

Flutter’s official performance guidance recommends lazy list builders, minimizing expensive work in `build()`, using `const` widgets, avoiding unnecessary clipping/opacity, and targeting frame work under 16 ms [2]. Flutter’s image guidance confirms network images should be handled through image widgets and placeholders; FinReels’ existing cached image widget will be retained and tightened rather than replaced [3].

## Sources

[1]: https://tech.facebook.com/engineering/2021/1/news-feed-ranking/ "How does News Feed predict what you want to see? — Tech at Meta"
[2]: https://docs.flutter.dev/perf/best-practices "Performance best practices — Flutter documentation"
[3]: https://docs.flutter.dev/cookbook/images/cached-images "Display images from the internet — Flutter documentation"
