

## 2026-08-24 Web thumbnail/shimmer audit

The YouTube Data API documents that video resources may expose `default`, `medium`, `high`, `standard`, and `maxres` thumbnail objects, each with its own URL and dimensions; availability varies by resource and source resolution. The app currently constructs `maxresdefault.jpg` and `mqdefault.jpg` directly from the video ID, but the primary `InlineVideoCard` placeholder is a solid dark `ColoredBox`, and its terminal error widget is a dark surface. This explains why failed Web image requests appear as large black thumbnail blocks rather than a loading shimmer or a visible fallback.

The YouTube IFrame API documentation confirms that a player can load a video by ID and that the player itself loads a thumbnail when a video is cued. It does not document a guaranteed public “first frame image” endpoint. Therefore, the app will use the documented/commonly available YouTube image variants in bounded order, including the default/standard-style image endpoints as best-effort candidates; it will not claim that every video has a retrievable exact first-frame still. If all image candidates fail, the UI will show a themed non-black fallback with the video title/channel rather than a broken or opaque black rectangle.

The oEmbed specification permits providers to return a `thumbnail_url` for a video, but using YouTube oEmbed as a runtime fallback would add an extra network request and can be restricted by CORS/browser policy in the current no-backend architecture. It is documented as a future metadata hydration option, not silently treated as a guaranteed client-side fallback.

References:
- https://developers.google.com/youtube/v3/docs/thumbnails
- https://developers.google.com/youtube/iframe_api_reference
- https://oembed.com/


## Book-cover fallback research

Open Library's Covers API explicitly supports ISBN, OCLC, LCCN, OLID, and cover-ID lookup with S/M/L sizes and recommends `?default=false` when an absent cover should return 404 instead of a blank image. It also cautions against crawling the API and recommends the public cover URL or bulk archive data for large-scale access. The existing exact-edition policy is therefore retained: cover candidates are generated only from supplied ISBN/OLID/cover identifiers or trusted edition-specific URLs; title-only searches are not converted into guessed covers.

Google Books public Volume resources expose `imageLinks` at several sizes and `industryIdentifiers`, and their public list/get methods do not require authentication. However, a Google Books image URL is only suitable as an exact-edition fallback when the catalog record has been matched by ISBN/volume ID; it must not replace a cover with an unrelated title-only search result. The current resource model does not yet store ISBN/Google volume IDs, so future catalog enrichment should add those identifiers before automated Google Books cover hydration.

References:
- https://openlibrary.org/dev/docs/api/covers
- https://openlibrary.org/dev/docs/api/search
- https://developers.google.com/books/docs/v1/reference/volumes


## Proxy delivery research

wsrv.nl documents itself as a free image cache/resize service that can fetch an HTTPS origin, cache the result, and serve it over HTTPS. It supports common image formats and requires URL-encoding the origin URL when it contains query parameters. Its FAQ also states that origin-domain filtering and per-visitor request limits exist, so it is a best-effort transport rather than a guaranteed CDN. The implementation will keep direct source URLs first and use a bounded second proxy candidate, never treating a proxy response as evidence that a cover or thumbnail is the exact edition.

References:
- https://wsrv.nl/docs/
- https://wsrv.nl/faq/
- https://github.com/weserv/images
