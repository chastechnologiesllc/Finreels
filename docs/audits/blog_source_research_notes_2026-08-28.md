# Blog source research notes

## Verified external references

1. [RSS Advisory Board — RSS Autodiscovery](https://www.rssboard.org/rss-autodiscovery) states that publishers expose a feed in the HTML `<head>` with `rel="alternate"`, a feed MIME type such as `application/rss+xml`, and an `href`; relative hrefs must be resolved against the source page. A page may expose more than one feed, with the first normally being the main feed.
2. [RSS Advisory Board — Media RSS specification](https://www.rssboard.org/media-rss) states that `media:thumbnail` carries a representative image URL and that multiple thumbnails are ordered by importance. `media:content` and enclosure metadata are also part of the media model.

## Repository findings

- The verified catalog currently contains 1,709 blog records, 1,747 channel records, and 20,000 book records.
- Blog records are commonly homepage URLs rather than direct feeds, so successful autodiscovery is required rather than assuming `/feed` paths.
- `BlogRssService` currently supports only a narrow set of `<link>` attribute forms, a small conventional-path list, and a two-proxy race. It parses several image elements but does not yet handle all namespace/prefix/attribute order variations or lazy/image metadata patterns.
- `BlogThumbnailImage` expands each supplied image into direct plus two image proxy URLs, but when the catalog/snapshot has no usable image candidates it immediately reaches the branded fallback. It does not itself discover article-page images.
- Blog channel navigation in `BlogFeedScreen` and `CategoryDetailScreen` groups initial articles using exact display-name equality and often omits `sourceUrl`, despite `BlogChannelScreen`/`fetchForSource` supporting URL matching. This can fragment equivalent sources or make source pages depend on incomplete name matching.
- `ChannelData.combined` deduplicates YouTube channels by ID, but same-name/different-ID records exist and should not be merged blindly without verification. The source catalog should be measured by canonical source identity, not only display name.
- Book records with empty `coverUrl` and no `coverCandidates` are guaranteed to show the fallback under the current renderer. `BookCoverImage` intentionally does not perform title-only searches, so missing cover metadata must be repaired in verified catalog data or via a bounded, exact-identifier lookup layer.
- Book reader source ordering requires separate verification: the reader currently tries the original source before mapped readable URLs, which can allow a landing page to win over a readable text body.

## Working conclusion

The likely blog fallback causes are source feeds that fail autodiscovery/CORS or expose images in formats not currently parsed, combined with bounded hydration that only enriches a limited number of articles. The likely repeated-channel cause is source-name-only grouping plus many homepage records whose live fetches fail, leaving only the general feeds visible. Book cover fallbacks are partly deterministic catalog gaps, while book reader correctness requires preferring verified readable content over landing-page HTML.
