# Visual Source Audit

## Exact book-cover source policy

Open Library’s Covers API documents the stable image pattern `https://covers.openlibrary.org/b/{key}/{value}-{size}.jpg`, where keys include ISBN, OLID, and cover ID, and sizes are S, M, and L. Its guidance says public-facing pages should point directly to `covers.openlibrary.org`; adding `?default=false` makes an unavailable cover return HTTP 404 instead of a blank image, which lets the app advance to an ordered fallback candidate. Source: https://openlibrary.org/dev/docs/api/covers

Internet Archive’s Metadata API is keyed by a unique item identifier and provides public item metadata through its REST endpoint. This supports identifier-specific archive thumbnail candidates, but the app must not infer an identifier or substitute a generic title search. Source: https://archive.org/developers/metadata.html

## Repository audit findings on 2026-08-24

The General catalog contains 7,344 books. The existing deterministic cover audit found 7,159 books with cover metadata and 185 without verified cover candidates; its sampled HTTP report found 81 of 263 sampled books with no working candidate. The broader 81-file resource audit contained 10,477 books and 2,150 without cover metadata before the new enrichment run.

The guarded all-catalog enrichment run scanned the 2,150 unresolved records. It added 1,110 exact Project Gutenberg ID-derived cover sets and 59 title-matched, trusted source-page images. It left 981 unresolved records unchanged rather than guessing a cover. The app-side `BookCoverImage` widget was also updated so Open Library blank-cover responses become detectable failures and ordered exact candidates can be attempted.

## Blog thumbnail policy

Blog RSS/Atom parsing now preserves ordered candidates from image enclosures, `media:content`, `media:thumbnail`, and first images found in `content:encoded`, `description`, `content`, or `summary`. Relative candidates are resolved against the feed URL and invalid/data/tracking candidates are discarded. The new `BlogThumbnailImage` widget retries those candidates before showing a branded article placeholder.
