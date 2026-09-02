# Channel, Blog, and Channel-History Research Report

**Date:** 2026-08-23
**Repository:** Rumuo
**Scope:** Existing 80 categories plus General

## Result

The category catalog was audited before integration. The existing taxonomy contains 80 category JSON files plus `_general.json`. Each specialized category now has at least 20 channel records and 20 blog records: the original ten records plus a researched second set of ten or more. `_general.json` now contains exactly ten broad educational channels and ten broad learning blogs, keeping General useful as a discovery bucket while category files hold the specialized sources.

The first research pass resolved 127 YouTube handles to real channel IDs by fetching the channel’s own YouTube page and extracting the canonical `UC...` identifier. It also checked 102 blog or publication URLs. Invalid placeholder channel records, including search phrases such as `search start digital agency Nigeria`, were removed rather than being presented as channels. An orphaned car-hire filename was consolidated into the canonical taxonomy filename, and stale category IDs were normalized against `resource_categories.json`.

The new source pools broaden the catalog beyond business commentary. Depending on category, additions include university open-learning channels, open courseware, medical education, legal education, engineering, agricultural extension, psychology, culinary technique, craft trades, photography, design, and software development. General sources include OpenLearn, MIT OpenCourseWare, YaleCourses, Stanford Online, Khan Academy, CrashCourse, TED-Ed, SciShow, 3Blue1Brown, and The School of Life. These were selected because their published descriptions and official sites demonstrate educational or professional learning coverage rather than only promotional business content [1] [2] [3].

## Blog-feed correction

The JSON catalog previously included many legitimate publication homepages, but the runtime parser expected the stored URL itself to return RSS or Atom XML. The `BlogRssService` now accepts either a raw feed or an HTML publication page. When it receives HTML, it reads declared `rel="alternate"` links with RSS, Atom, or XML MIME types and tries conventional `/feed/`, `/feed`, `/rss.xml`, `/feed.xml`, and `/atom.xml` paths as bounded fallbacks. It never invents article URLs. The same discovery behavior is used through the two existing CORS proxy alternatives on web builds.

## Channel-history correction

YouTube’s official channel Atom feed is a notification-style feed containing only the newest 15 uploads [4]. That is the root cause of the previous per-channel 15-item ceiling; the channel screen did not impose the limit. The channel screen now keeps the official RSS result as a verified seed, then requests the channel’s public Videos page. It extracts only video renderers tied to that channel, deduplicates by YouTube video ID, and follows the public web client’s continuation endpoint on native builds when a continuation token and client key are available. The implementation stops after 12 continuation pages or 300 unique items per channel to protect mobile memory, network usage, and public-source rate limits. The aggregated home feed remains RSS-first and lightweight; the expanded history is requested when a user opens a channel.

The official, fully supported alternative for exhaustive channel-history retrieval is the YouTube Data API: resolve the channel’s uploads playlist and paginate `playlistItems.list` with `nextPageToken` [5]. Rumuo does not currently ship a YouTube API key, so the implementation uses RSS plus the public channel page/continuation path without embedding a private credential. If an API key is added later, it should replace the undocumented continuation path for guaranteed supported pagination.

## Validation

The final audit confirmed 81 JSON files, 1,747 channel records, and 1,709 blog records. All specialized category files meet the 20-channel/20-blog target, and General contains 10 channels and 10 blogs. Channel IDs are valid `UC...` identifiers, duplicate IDs and duplicate blog URLs inside a file were removed, and category IDs match the canonical taxonomy. The repository passes `git diff --check`. Dart formatting and Flutter analysis could not be run in the sandbox because Dart/Flutter tooling is not installed.

## References

[1]: https://www.youtube.com/user/OUlearn "OpenLearn from The Open University"

[2]: https://www.youtube.com/yalecourses "YaleCourses official YouTube channel"

[3]: https://ocw.mit.edu/ "MIT OpenCourseWare"

[4]: https://www.wprssaggregator.com/youtube-rss-feed/ "YouTube RSS feed limitation overview"

[5]: https://developers.google.com/youtube/v3/docs/playlistItems/list "YouTube Data API playlistItems.list documentation"
