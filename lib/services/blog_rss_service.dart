import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../data/resource_category_data.dart';
import 'feed_snapshot_service.dart';
import 'user_profile_service.dart';

/// A single parsed blog article from an RSS/Atom feed.
class BlogArticle {
  final String title;
  final String url;
  final String sourceName;
  /// The feed or catalog URL that produced this article. This is kept
  /// separately from [sourceName] so punctuation, aliases, and feed URLs do
  /// not fragment one source into multiple channel pages.
  final String? sourceUrl;
  final String? thumbnailUrl;
  final List<String> thumbnailFallbackUrls;
  final DateTime publishedAt;
  final String excerpt;

  /// Which of the 60 categories this feed is tagged to, if any — see
  /// assets/data/resources/{categoryId}.json, loaded by
  /// ResourceCategoryData. Null for the 5 general-purpose feeds below.
  final String? categoryId;

  const BlogArticle({
    required this.title,
    required this.url,
    required this.sourceName,
    required this.publishedAt,
    this.sourceUrl,
    this.thumbnailUrl,
    this.thumbnailFallbackUrls = const [],
    this.excerpt = '',
    this.categoryId,
  });

  BlogArticle copyWith({
    String? thumbnailUrl,
    List<String>? thumbnailFallbackUrls,
  }) {
    return BlogArticle(
      title: title,
      url: url,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      publishedAt: publishedAt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailFallbackUrls:
          thumbnailFallbackUrls ?? this.thumbnailFallbackUrls,
      excerpt: excerpt,
      categoryId: categoryId,
    );
  }
}

/// Business, wealth and personal-growth RSS sources.
/// Replaces the previous news-heavy lineup (MarketWatch, Reuters).
const List<Map<String, String>> kBlogFeeds = [
  {
    'name': 'Entrepreneur',
    'url': 'https://www.entrepreneur.com/latest.rss',
  },
  {
    'name': 'Inc. Magazine',
    'url': 'https://www.inc.com/rss/',
  },
  {
    'name': 'Forbes Business',
    'url': 'https://www.forbes.com/business/feed/',
  },
  {
    'name': 'Fast Company',
    'url': 'https://www.fastcompany.com/rss',
  },
  {
    'name': 'Seth Godin',
    'url': 'https://seths.blog/feed/',
  },
];

/// [kBlogFeeds] (the 5 general-purpose feeds) plus every category-tagged
/// blog verified so far (see assets/data/resources/{categoryId}.json) for
/// ONLY the categories the person currently has selected
/// (UserProfileService) — general feeds are always included since their
/// categoryId is null.
///
/// This is the same "general always, category-specific only if selected"
/// rule ChannelData.eagerFor already applies to channels, for exactly the
/// same two reasons:
///  1. Correctness — without this, a fashion designer's Blogs tab would
///     include every other started category's blogs too (a barber's, a
///     doctor's, ...), not just general + their own.
///  2. Scale — as more of the 60 categories reach their full 10 blogs
///     each, an unscoped list heads toward ~600 RSS feeds fetched on
///     every single visit to the Blogs tab, for every person, regardless
///     of what they actually do. Scoping keeps each person's fetch count
///     bounded by (5 general + 10 per category they picked), not by how
///     much of the whole 60-category dataset happens to exist.
///
/// Browsing a category from Discover/CategoryDetailScreen — where any of
/// the 60 must be viewable even if it isn't the person's own selection —
/// deliberately does NOT go through this. See [fetchForCategory] below,
/// which mirrors how ChannelVideosScreen fetches one channel directly
/// instead of going through the same eager-scoped list FeedProvider uses.
List<Map<String, String>> get combinedBlogFeeds {
  final selected = UserProfileService.instance.selectedCategoryIds;
  final scoped = ResourceCategoryData.verifiedBlogs.where((b) {
    final categoryId = b['categoryId'];
    return categoryId == null || selected.contains(categoryId);
  });
  return [...kBlogFeeds, ...scoped];
}

/// Argument bundle for [BlogRssService._smartMixArticles], which runs inside
/// a [compute] isolate where [UserProfileService.instance] is not available.
/// Carrying the selected IDs as plain data is the correct cross-isolate pattern.
class _SmartMixArgs {
  final List<BlogArticle> articles;
  final Set<String> selectedCategoryIds;
  const _SmartMixArgs({required this.articles, required this.selectedCategoryIds});
}

class BlogRssService {
  BlogRssService._();
  static final BlogRssService instance = BlogRssService._();

  List<BlogArticle>? _cache;
  DateTime? _cacheTime;
  static const _cacheTtl = Duration(minutes: 10);

  bool get _isCacheFresh =>
      _cache != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTtl;

  /// Returns the quickest locally available article corpus for typeahead
  /// search. A fresh RSS result is returned immediately; otherwise the
  /// memoized bundled snapshot is used without starting live network work.
  Future<List<BlogArticle>> fetchSearchSeed() async {
    if (_isCacheFresh) return _cache!;
    return _loadSnapshotArticles();
  }

  /// Returns a fast category-scoped local corpus for the first paint. Fresh
  /// service cache wins; otherwise the bundled snapshot is filtered so only
  /// general articles and the viewer's selected categories are shown.
  Future<List<BlogArticle>> fetchLocalSeed() async {
    if (_isCacheFresh) return _cache!;
    final articles = await _loadSnapshotArticles();
    final selected = UserProfileService.instance.selectedCategoryIds;
    final scoped = articles.where((article) {
      return article.categoryId == null || selected.contains(article.categoryId);
    }).toList(growable: false);
    return prioritizeForSelection(scoped, selected);
  }

  /// Powers the aggregated, passive Blogs tab — general feeds plus
  /// whatever categories the person selected (see [combinedBlogFeeds]).
  /// Cached for 10 minutes; FeedProvider clears that cache the moment the
  /// person's category selection changes, so switching category never
  /// shows stale, wrongly-scoped articles for the rest of that window.
  Future<List<BlogArticle>> fetchAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheFresh) return _cache!;

    // Fetch the hard-coded general feeds and the verified catalog feeds on
    // every platform. Web requests still go through CORS proxies, while
    // native requests go directly to the source. Both paths use the same
    // bounded worker pool so a category selection cannot create an unbounded
    // request burst or silently drop all category blogs on Web.
    final feeds = _deduplicateFeeds(combinedBlogFeeds);
    final results = await _fetchFeedsBounded(feeds);
    final liveArticles = results.expand((l) => l).toList();
    final snapshotArticles = await _loadSnapshotArticles();
    final articles = _mergeArticles(liveArticles, snapshotArticles);
    final selected = UserProfileService.instance.selectedCategoryIds;
    final scoped = articles.where((article) {
      // Never let an unselected category leak into the general lane. General
      // means categoryId == null; selected category content is the priority
      // lane for this viewer.
      return article.categoryId == null || selected.contains(article.categoryId);
    }).toList(growable: false);
    final mixed = await compute(
      _smartMixArticles,
      _SmartMixArgs(articles: scoped, selectedCategoryIds: selected),
    );
    _cache = mixed;
    _cacheTime = DateTime.now();
    // Do not block first paint on article-page metadata lookups. RSS-provided
    // thumbnails are already usable; missing-image enrichment continues after
    // the list is visible and updates the same cache only if its scope is still
    // current.
    unawaited(_hydrateCacheInBackground(mixed, _cacheTime!));
    return mixed;
  }

  /// Fetches articles for one named blog source for its dedicated channel
  /// screen. This intentionally searches the complete verified source catalog,
  /// not only the viewer's selected categories, because a source opened from a
  /// card should remain browsable from anywhere in the app.
  Future<List<BlogArticle>> fetchForSource(
    String sourceName, {
    String? sourceUrl,
  }) async {
    final normalizedName = _sourceKey(sourceName);
    final normalizedUrl = _canonicalUrl(sourceUrl ?? '');
    if (normalizedName.isEmpty && normalizedUrl.isEmpty) return const [];

    final allSources = <Map<String, String>>[
      ...kBlogFeeds,
      ...ResourceCategoryData.verifiedBlogs
          .map((entry) => Map<String, String>.from(entry)),
    ];
    final urlMatches = normalizedUrl.isNotEmpty
        ? allSources
            .where((source) =>
                _canonicalUrl(source['url'] ?? '') == normalizedUrl)
            .toList(growable: false)
        : const <Map<String, String>>[];
    final matching = urlMatches.isNotEmpty
        ? urlMatches
        : allSources.where((source) {
            return normalizedName.isNotEmpty &&
                _sourceKey(source['name'] ?? '') == normalizedName;
          }).toList(growable: false);
    final feeds = _deduplicateFeeds(matching);
    final acceptedNames = <String>{
      if (normalizedName.isNotEmpty) normalizedName,
      for (final feed in feeds) _sourceKey(feed['name'] ?? ''),
    };
    final acceptedUrls = <String>{
      if (normalizedUrl.isNotEmpty) normalizedUrl,
      for (final feed in feeds) _canonicalUrl(feed['url'] ?? ''),
    }..remove('');

    List<BlogArticle> localArticles = const [];
    try {
      localArticles = [
        ...?_cache,
        ...await _loadSnapshotArticles(),
      ];
    } on Object catch (_) {
      // A failed snapshot should not prevent live source results.
    }

    bool belongsToSource(BlogArticle article) {
      if (normalizedUrl.isNotEmpty) {
        final articleUrl = _canonicalUrl(article.sourceUrl ?? '');
        return acceptedUrls.contains(articleUrl) ||
            (article.sourceUrl == null &&
                acceptedNames.contains(_sourceKey(article.sourceName)));
      }
      return acceptedNames.contains(_sourceKey(article.sourceName));
    }

    final fallback = mergeArticles(
      localArticles.where(belongsToSource),
      const <BlogArticle>[],
    );
    if (feeds.isEmpty) return compute(_sortArticles, fallback);

    final results = await _fetchFeedsBounded(feeds);
    final live = results.expand((list) => list).toList(growable: false);
    final articles = _mergeArticles(live, fallback);
    return compute(_sortArticles, articles);
  }

  /// Deterministic relevance/diversity ordering used by the Blogs tab and
  /// exposed for regression tests. Selected-category articles are prioritized;
  /// general articles remain visible but do not compete equally for the first
  /// positions.
  static List<BlogArticle> prioritizeForSelection(
    Iterable<BlogArticle> articles,
    Set<String> selectedCategoryIds,
  ) {
    return _smartMixArticles(
      _SmartMixArgs(
        articles: articles.toList(growable: false),
        selectedCategoryIds: selectedCategoryIds,
      ),
    );
  }

  /// Stable source key used for display-name matching across feed metadata and
  /// bundled records. Punctuation and repeated whitespace are insignificant.
  static String normalizeSourceName(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Merges a preferred (usually live) list with fallback records by article
  /// URL, retaining the first copy so fresh metadata wins over stale data.
  static List<BlogArticle> mergeArticles(
    Iterable<BlogArticle> preferred,
    Iterable<BlogArticle> fallback,
  ) {
    final byUrl = <String, BlogArticle>{};
    for (final article in [...preferred, ...fallback]) {
      if (article.url.isNotEmpty) byUrl.putIfAbsent(article.url, () => article);
    }
    return byUrl.values.toList(growable: false);
  }

  static String _sourceKey(String value) => normalizeSourceName(value);

  /// A stable source identity prefers the verified URL and falls back to the
  /// normalized display name when old snapshot records have no source URL.
  static String sourceIdentity(String sourceName, [String? sourceUrl]) {
    final url = _canonicalUrl(sourceUrl ?? '');
    return url.isNotEmpty ? 'url:$url' : 'name:${_sourceKey(sourceName)}';
  }

  static bool sameSource(BlogArticle first, BlogArticle second) =>
      sourceIdentity(first.sourceName, first.sourceUrl) ==
      sourceIdentity(second.sourceName, second.sourceUrl);

  /// Finds the first verified catalog URL for a display name. This is used
  /// when loading legacy snapshot articles that predate [BlogArticle.sourceUrl].
  static String? catalogUrlForSource(String sourceName) {
    final key = _sourceKey(sourceName);
    for (final source in [
      ...kBlogFeeds,
      ...ResourceCategoryData.verifiedBlogs,
    ]) {
      if (_sourceKey(source['name'] ?? '') == key) return source['url'];
    }
    return null;
  }

  static String _canonicalUrl(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'^www\.'), '')
      .replaceFirst(RegExp(r'/+$'), '');

  /// Fetches ONE category's own blogs directly — regardless of whether the
  /// person has that category selected. For CategoryDetailScreen (reached
  /// from Discover, browsing any of the 60), which must show a category's
  /// real content even when it isn't the viewer's own selection, exactly
  /// the same reasoning ChannelVideosScreen already applies by fetching a
  /// single channel's RSS directly instead of going through the
  /// selection-scoped aggregate. Not cached beyond the lifetime of the
  /// call — a category page's blog list is a handful of feeds, cheap
  /// enough to fetch fresh each visit.
  Future<List<BlogArticle>> fetchForCategory(String categoryId) async {
    final feeds = ResourceCategoryData.verifiedBlogs
        .where((b) => b['categoryId'] == categoryId)
        .toList();
    if (feeds.isEmpty) return const [];

    final results = await _fetchFeedsBounded(_deduplicateFeeds(feeds));
    final articles = results.expand((l) => l).toList();
    return compute(_sortArticles, articles);
  }

  Future<List<BlogArticle>> _loadSnapshotArticles() async {
    final raw = await FeedSnapshotService.instance.blogArticles();
    return raw.map((item) {
      final url = item['url'] as String? ?? '';
      final publishedAt = DateTime.tryParse(item['publishedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return BlogArticle(
        title: item['title'] as String? ?? 'Untitled',
        url: url,
        sourceName: item['sourceName'] as String? ?? 'Rumuo source',
        sourceUrl: item['sourceUrl'] as String? ??
            catalogUrlForSource(item['sourceName'] as String? ?? ''),
        publishedAt: publishedAt,
        thumbnailUrl: item['thumbnailUrl'] as String?,
        thumbnailFallbackUrls:
            (item['thumbnailFallbackUrls'] as List?)?.whereType<String>().toList(growable: false) ?? const [],
        excerpt: item['description'] as String? ?? '',
        categoryId: item['categoryId'] as String?,
      );
    }).where((article) => article.url.isNotEmpty).toList(growable: false);
  }

  List<BlogArticle> _mergeArticles(
    Iterable<BlogArticle> live,
    Iterable<BlogArticle> snapshot,
  ) =>
      mergeArticles(live, snapshot);

  List<Map<String, String>> _deduplicateFeeds(
      Iterable<Map<String, String>> feeds) {
    final seen = <String>{};
    return [
      for (final feed in feeds)
        if (feed['url'] != null &&
            seen.add(_canonicalUrl(feed['url']!)))
          feed,
    ];
  }

  Future<List<List<BlogArticle>>> _fetchFeedsBounded(
      List<Map<String, String>> feeds) async {
    if (feeds.isEmpty) return const [];
    final results = List<List<BlogArticle>>.filled(
      feeds.length,
      const <BlogArticle>[],
      growable: false,
    );
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= feeds.length) return;
        final feed = feeds[index];
        results[index] = await _fetchFeed(
          url: feed['url']!,
          sourceName: feed['name']!,
          categoryId: feed['categoryId'],
        );
      }
    }

    final workerCount = math.min(8, feeds.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results;
  }

  Future<List<BlogArticle>> _fetchFeed({
    required String url,
    required String sourceName,
    String? categoryId,
  }) async {
    try {
      if (kIsWeb) {
        return await _fetchFeedWeb(
          url: url,
          sourceName: sourceName,
          categoryId: categoryId,
        );
      }

      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Rumuo/1.0 (+com.chastechgroup.rumuo)',
        'Accept': 'application/rss+xml, application/xml, text/html;q=0.9',
      }).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return [];
      final body = response.body;
      if (_looksLikeXml(body)) {
          return await _parseBody(
            body,
            sourceName,
            categoryId,
            url,
            sourceIdentityUrl: url,
          );
      }

      // Many high-quality sources publish a homepage in their catalog rather
      // than a raw feed URL. Discover the declared RSS/Atom alternate, then
      // fetch that feed. This keeps the JSON human-friendly and makes the
      // source work on native builds without requiring a hard-coded /feed path.
      for (final discovered in _discoverFeedUrls(body, url)) {
        final feedResponse = await http.get(Uri.parse(discovered), headers: {
          'User-Agent': 'Rumuo/1.0 (+com.chastechgroup.rumuo)',
          'Accept': 'application/rss+xml, application/xml, text/xml',
        }).timeout(const Duration(seconds: 12));
        if (feedResponse.statusCode != 200 || !_looksLikeXml(feedResponse.body)) {
          continue;
        }
        final articles = await _parseBody(
          feedResponse.body,
          sourceName,
          categoryId,
          discovered,
          sourceIdentityUrl: url,
        );
        if (articles.isNotEmpty) return articles;
      }
      return [];
    } on Exception catch (e) {
      debugPrint('[BlogRssService] $sourceName failed: $e');
      return [];
    }
  }

  Future<List<BlogArticle>> _parseBody(
    String body,
    String sourceName,
    String? categoryId,
    String baseUrl, {
    String? sourceIdentityUrl,
  }) async {
    final articles = await compute<List<String>, List<BlogArticle>>(
      (args) => _parse(
        args[0],
        args[1],
        args[2].isEmpty ? null : args[2],
        args[3],
        args[4].isEmpty ? null : args[4],
      ),
      [body, sourceName, categoryId ?? '', baseUrl, sourceIdentityUrl ?? ''],
    );
    return articles;
  }

  /// Discovers RSS/Atom alternates from an HTML landing page and includes a
  /// small set of conventional feed paths as a fallback for sites that omit
  /// the HTML declaration. It never guesses article URLs.
  static List<String> _discoverFeedUrls(String html, String sourceUrl) {
    final found = <String>[];
    final tagPattern = RegExp(r'<link\b[^>]*>', caseSensitive: false);
    final attrPattern = RegExp(r"""([a-zA-Z:-]+)\s*=\s*["']([^"']+)["']""");
    for (final tag in tagPattern.allMatches(html)) {
      final raw = tag.group(0) ?? '';
      final attrs = <String, String>{
        for (final match in attrPattern.allMatches(raw))
          match.group(1)!.toLowerCase(): match.group(2)!,
      };
      final rel = (attrs['rel'] ?? '').toLowerCase();
      final type = (attrs['type'] ?? '').toLowerCase();
      if (rel.contains('alternate') &&
          (type.contains('rss') || type.contains('atom') || type.contains('xml'))) {
        final href = attrs['href'];
        if (href != null && href.isNotEmpty) {
          found.add(Uri.parse(sourceUrl).resolve(href).toString());
        }
      }
    }

    final base = Uri.parse(sourceUrl);
    final origin = '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    final conventional = <String>[
      '$origin/feed/',
      '$origin/feed',
      '$origin/rss',
      '$origin/rss.xml',
      '$origin/feed.xml',
      '$origin/atom.xml',
    ];
    if (!sourceUrl.contains('?')) {
      conventional.addAll([
        '$sourceUrl?format=rss',
        '$sourceUrl?output=1',
      ]);
    }
    found.addAll(conventional);
    return List.unmodifiable(found.toSet());
  }

  static bool _looksLikeXml(String body) {
    final trimmed = body.trimLeft().toLowerCase();
    return trimmed.startsWith('<?xml') ||
        trimmed.startsWith('<rss') ||
        trimmed.startsWith('<feed') ||
        trimmed.startsWith('<rdf:rdf');
  }

  Future<List<BlogArticle>> _fetchFeedWeb({
    required String url,
    required String sourceName,
    String? categoryId,
  }) async {
    final firstBody = await _fetchWebBody(url, sourceName);
    if (firstBody == null) return [];
    if (_looksLikeXml(firstBody)) {
      return _parseBody(
        firstBody,
        sourceName,
        categoryId,
        url,
        sourceIdentityUrl: url,
      );
    }

    // If the catalog URL is HTML, discover its declared RSS/Atom alternate
    // and fetch each candidate through the same two-proxy race.
    for (final discovered in _discoverFeedUrls(firstBody, url)) {
      final feedBody = await _fetchWebBody(discovered, sourceName);
      if (feedBody != null && _looksLikeXml(feedBody)) {
        final articles = await _parseBody(
          feedBody,
          sourceName,
          categoryId,
          discovered,
          sourceIdentityUrl: url,
        );
        if (articles.isNotEmpty) return articles;
      }
    }
    return [];
  }

  Future<String?> _fetchWebBody(String url, String sourceName) async {
    final encoded = Uri.encodeComponent(url);
    final proxyUrls = [
      'https://corsproxy.io/?url=$encoded',
      'https://api.allorigins.win/raw?url=$encoded',
    ];
    final completer = Completer<String?>();
    var pending = proxyUrls.length;
    for (final proxyUrl in proxyUrls) {
      unawaited(() async {
        try {
          final response = await http
              .get(Uri.parse(proxyUrl))
              .timeout(const Duration(seconds: 14));
          if (response.statusCode == 200 && response.body.length > 50 &&
              !completer.isCompleted) {
            completer.complete(response.body);
            return;
          }
        } on Object catch (e) {
          debugPrint('[BlogRssService] $sourceName via $proxyUrl: $e');
        }
        pending--;
        if (pending == 0 && !completer.isCompleted) completer.complete(null);
      }());
    }
    return completer.future;
  }

  Future<void> _hydrateCacheInBackground(
      List<BlogArticle> articles, DateTime cacheTime) async {
    try {
      final hydrated = await _hydrateThumbnailCandidates(articles);
      if (identical(_cache, articles) && _cacheTime == cacheTime) {
        _cache = List.unmodifiable(hydrated);
      }
    } on Object catch (e) {
      debugPrint('[BlogRssService] Background image enrichment failed: $e');
    }
  }

  Future<List<BlogArticle>> _hydrateThumbnailCandidates(
      List<BlogArticle> articles) async {
    final targets = articles
        .where((article) => article.thumbnailFallbackUrls.length < 2)
        .take(40)
        .toList(growable: false);
    if (targets.isEmpty) return articles;

    // Hydration visits article pages only to discover missing image metadata.
    // Keep the work bounded so a Blogs refresh cannot open 40 simultaneous
    // browser/native requests on a slower connection or lower-end device.
    var nextIndex = 0;
    Future<List<BlogArticle>> hydrateWorker() async {
      final output = <BlogArticle>[];
      while (true) {
        final index = nextIndex++;
        if (index >= targets.length) return output;
        output.add(await _hydrateArticleThumbnail(targets[index]));
      }
    }

    final workerCount = math.min(4, targets.length);
    final hydrated = (await Future.wait(
      List.generate(workerCount, (_) => hydrateWorker()),
    )).expand((batch) => batch);
    final byUrl = <String, BlogArticle>{
      for (final article in hydrated) article.url: article,
    };
    return [
      for (final article in articles) byUrl[article.url] ?? article,
    ];
  }

  Future<BlogArticle> _hydrateArticleThumbnail(BlogArticle article) async {
    try {
      final html = kIsWeb
          ? await _fetchWebBody(article.url, article.sourceName)
          : await _fetchNativeHtml(article.url);
      if (html == null || html.length < 50) return article;

      final raw = <String?>[
        ..._pageImageMetaCandidates(html),
        _firstImgSrc(html),
      ];
      final candidates = _normaliseThumbnailCandidates([
        article.thumbnailUrl,
        ...article.thumbnailFallbackUrls,
        ...raw,
      ], article.url);
      if (candidates.isEmpty) return article;
      return article.copyWith(
        thumbnailUrl: candidates.first,
        thumbnailFallbackUrls: candidates.skip(1).take(7).toList(growable: false),
      );
    } on Exception catch (e) {
      debugPrint('[BlogRssService] Article image lookup failed: $e');
      return article;
    }
  }

  Future<String?> _fetchNativeHtml(String url) async {
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'Rumuo/1.0 (+com.chastechgroup.rumuo)',
      'Accept': 'text/html;q=0.9',
    }).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 ||
        !response.headers['content-type'].toString().contains('text/html')) {
      return null;
    }
    return response.body;
  }

  static List<String> _pageImageMetaCandidates(String html) {
    final found = <String>[];
    final metaTags = RegExp(r'''<meta\b[^>]*>''', caseSensitive: false);
    final attribute = RegExp(
      r'''([a-zA-Z:-]+)\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final tag in metaTags.allMatches(html)) {
      final attrs = <String, String>{
        for (final match in attribute.allMatches(tag.group(0) ?? ''))
          match.group(1)!.toLowerCase(): match.group(2)!,
      };
      final marker = (attrs['property'] ?? attrs['name'] ?? '').toLowerCase();
      final value = attrs['content']?.trim() ?? '';
      if ((marker == 'og:image' ||
              marker == 'twitter:image' ||
              marker == 'twitter:image:src') &&
          value.isNotEmpty) {
        found.add(value);
      }
    }

    final linkTags = RegExp(r'''<link\b[^>]*>''', caseSensitive: false);
    final imageLink = RegExp(
      r'''rel\s*=\s*["'](?:image_src|image)["']''',
      caseSensitive: false,
    );
    final href = RegExp(
      r'''href\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final tag in linkTags.allMatches(html)) {
      final raw = tag.group(0) ?? '';
      if (!imageLink.hasMatch(raw)) continue;
      final value = href.firstMatch(raw)?.group(1);
      if (value != null && value.isNotEmpty) found.add(value);
    }
    return found;
  }

  static List<BlogArticle> _parse(
    String body,
    String sourceName,
    String? categoryId,
    String baseUrl,
    String? sourceIdentityUrl,
  ) {
    try {
      final doc = XmlDocument.parse(body);

      // ── RSS 2.0 ──────────────────────────────────────────────────────────
      final rssItems = doc.findAllElements('item');
      if (rssItems.isNotEmpty) {
        return rssItems.map((item) {
          final rawLink = _text(item, 'link') ?? _text(item, 'guid') ?? '';
          final link = _resolveHttpUrl(rawLink, baseUrl);
          if (link.isEmpty) return null;

          // Keep every image candidate in priority order. The card advances
          // through this list when an RSS provider URL is broken or blocked.
          final rawThumbs = <String?>[
            for (final e in _elementsByLocalName(item, 'enclosure'))
              if (_looksLikeImageElement(e))
                _imageAttribute(e),
            for (final e in _elementsByLocalName(item, 'content'))
              if (_looksLikeImageElement(e)) _imageAttribute(e),
            for (final e in _elementsByLocalName(item, 'thumbnail'))
              _imageAttribute(e),
            _firstImgSrc(_text(item, 'content:encoded') ?? ''),
            _firstImgSrc(_text(item, 'description') ?? ''),
          ];
          final thumbnailCandidates =
              _normaliseThumbnailCandidates(rawThumbs, baseUrl);

          final pubStr = _text(item, 'pubDate') ?? '';
          final published = _parseRssDate(pubStr) ?? DateTime.now();

          return BlogArticle(
            title: _clean(_text(item, 'title') ?? 'Untitled'),
            url: link,
            sourceName: sourceName,
            sourceUrl: sourceIdentityUrl ?? baseUrl,
            thumbnailUrl: thumbnailCandidates.isEmpty
                ? null
                : thumbnailCandidates.first,
            thumbnailFallbackUrls: thumbnailCandidates.length > 1
                ? thumbnailCandidates.skip(1).toList(growable: false)
                : const [],
            publishedAt: published,
            excerpt: _clean(_text(item, 'description') ?? ''),
            categoryId: categoryId,
          );
        }).whereType<BlogArticle>().toList();
      }

      // ── Atom ─────────────────────────────────────────────────────────────
      final atomEntries = doc.findAllElements('entry');
      if (atomEntries.isNotEmpty) {
        return atomEntries.map((entry) {
          final rawLink = entry.findElements('link').firstOrNull
                  ?.getAttribute('href') ??
              '';
          final link = _resolveHttpUrl(rawLink, baseUrl);
          if (link.isEmpty) return null;

          // Keep every Atom image candidate in priority order so the card can
          // fall back when a feed URL is unavailable.
          final rawThumbs = <String?>[
            for (final e in _elementsByLocalName(entry, 'thumbnail'))
              _imageAttribute(e),
            for (final e in _elementsByLocalName(entry, 'content'))
              if (_looksLikeImageElement(e)) _imageAttribute(e),
            _firstImgSrc(_text(entry, 'content') ?? ''),
            _firstImgSrc(_text(entry, 'summary') ?? ''),
          ];
          final thumbnailCandidates =
              _normaliseThumbnailCandidates(rawThumbs, baseUrl);

          final updStr =
              _text(entry, 'updated') ?? _text(entry, 'published') ?? '';
          final published = DateTime.tryParse(updStr) ?? DateTime.now();

          return BlogArticle(
            title: _clean(_text(entry, 'title') ?? 'Untitled'),
            url: link,
            sourceName: sourceName,
            sourceUrl: sourceIdentityUrl ?? baseUrl,
            thumbnailUrl: thumbnailCandidates.isEmpty
                ? null
                : thumbnailCandidates.first,
            thumbnailFallbackUrls: thumbnailCandidates.length > 1
                ? thumbnailCandidates.skip(1).toList(growable: false)
                : const [],
            publishedAt: published,
            excerpt: _clean(_text(entry, 'summary') ?? ''),
            categoryId: categoryId,
          );
        }).whereType<BlogArticle>().toList();
      }
    } on Exception catch (e) {
      debugPrint('[BlogRssService] Parse error for $sourceName: $e');
    }
    return [];
  }

  static String _resolveHttpUrl(String value, String baseUrl) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final base = Uri.tryParse(baseUrl);
    if (base == null) return '';
    final resolved = base.resolve(trimmed);
    if (resolved.scheme != 'http' && resolved.scheme != 'https') return '';
    return resolved.toString();
  }

  static List<String> _normaliseThumbnailCandidates(
      Iterable<String?> raw, String baseUrl) {
    final out = <String>[];
    final base = Uri.tryParse(baseUrl);
    if (base == null) return out;
    for (final candidate in raw) {
      final value = candidate?.trim() ?? '';
      if (value.isEmpty || value.startsWith('data:')) continue;
      final resolved = base.resolve(value).toString();
      final uri = Uri.tryParse(resolved);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        continue;
      }
      final lower = resolved.toLowerCase();
      if (lower.contains('1x1') || lower.contains('pixel') ||
          lower.contains('tracking') || lower.contains('spacer')) {
        continue;
      }
      if (!out.contains(resolved)) out.add(resolved);
    }
    return out;
  }

  /// Extracts the first image URL from an HTML string.
  /// Works for WordPress content:encoded, description CDATA, and Atom content.
  static String? _firstImgSrc(String html) {
    if (html.isEmpty) return null;
    final tagPattern = RegExp(r'<(?:img|source)\b[^>]*>', caseSensitive: false);
    final attributePattern = RegExp(
      r'''(?:src|data-src|data-lazy-src|data-original)\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final tag in tagPattern.allMatches(html)) {
      final raw = tag.group(0) ?? '';
      final direct = attributePattern.firstMatch(raw)?.group(1) ?? '';
      if (direct.isNotEmpty && _isUsableImageUrl(direct)) return direct;
      final srcset = RegExp(
        r'''srcset\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(raw)?.group(1);
      if (srcset != null) {
        for (final candidate in srcset.split(',')) {
          final value = candidate.trim().split(RegExp(r'\s+')).first;
          if (_isUsableImageUrl(value)) return value;
        }
      }
    }
    return null;
  }

  static bool _isUsableImageUrl(String value) {
    final lower = value.toLowerCase();
    return !lower.startsWith('data:') &&
        !lower.contains('1x1') &&
        !lower.contains('pixel') &&
        !lower.contains('tracking') &&
        !lower.contains('spacer');
  }

  static Iterable<XmlElement> _elementsByLocalName(
      XmlElement root, String name) sync* {
    final target = name.split(':').last.toLowerCase();
    for (final node in root.descendants) {
      if (node is XmlElement && node.name.local.toLowerCase() == target) {
        yield node;
      }
    }
  }

  static String? _text(XmlElement el, String tag) =>
      _elementsByLocalName(el, tag).firstOrNull?.innerText.trim();

  static String? _imageAttribute(XmlElement element) {
    for (final name in const ['url', 'href', 'src']) {
      final value = element.getAttribute(name)?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static bool _looksLikeImageElement(XmlElement element) {
    final value = _imageAttribute(element) ?? '';
    final type = (element.getAttribute('type') ?? '').toLowerCase();
    final medium = (element.getAttribute('medium') ?? '').toLowerCase();
    return value.isNotEmpty &&
        (element.name.local.toLowerCase() == 'thumbnail' ||
            medium == 'image' ||
            type.startsWith('image') ||
            RegExp(r'\.(jpg|jpeg|png|webp|gif)(?:[?#].*)?$',
                    caseSensitive: false)
                .hasMatch(value));
  }

  static String _clean(String raw) => raw
      .replaceAll(RegExp('<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static DateTime? _parseRssDate(String s) {
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final trimmed = s.replaceFirst(RegExp(r'^[A-Za-z]+,\s*'), '');
    return DateTime.tryParse(trimmed);
  }

  static List<BlogArticle> _sortArticles(List<BlogArticle> articles) =>
      articles..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

  // ── Smart mix: 4-to-1 category vs general, no consecutive same source ───────

  /// Passed to [compute] because isolates can only receive plain data.
  static List<BlogArticle> _smartMixArticles(_SmartMixArgs args) {
    final articles   = args.articles;
    final selectedIds = args.selectedCategoryIds;

    // ── 1. Split into category lanes and a smaller general lane ─────────────
    final categoryPools = <String, List<BlogArticle>>{};
    final genPool = <BlogArticle>[];
    for (final a in articles) {
      final categoryId = a.categoryId;
      if (categoryId != null && selectedIds.contains(categoryId)) {
        categoryPools.putIfAbsent(categoryId, () => []).add(a);
      } else {
        genPool.add(a);
      }
    }
    for (final pool in categoryPools.values) {
      pool.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    }
    genPool.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    // Round-robin selected category lanes so one prolific category cannot
    // crowd every other selected category out of the priority pool.
    final catPool = <BlogArticle>[];
    final categoryIds = categoryPools.keys.toList(growable: false);
    var categoryIndex = 0;
    while (categoryPools.isNotEmpty) {
      if (categoryIndex >= categoryIds.length) categoryIndex = 0;
      final categoryId = categoryIds[categoryIndex++];
      final pool = categoryPools[categoryId];
      if (pool == null || pool.isEmpty) {
        categoryPools.remove(categoryId);
        continue;
      }
      catPool.add(pool.removeAt(0));
    }

    // Fallback: no selection or no category articles → plain date sort
    if (selectedIds.isEmpty || catPool.isEmpty) {
      final all = [...genPool, ...catPool]
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return _diversifyBlogs(all);
    }

    // ── 2. 4:1 weighted interleave ───────────────────────────────────────────
    // Four category articles, then one general article, then repeat.
    final merged = <BlogArticle>[];
    var ci = 0;
    var gi = 0;
    while (ci < catPool.length || gi < genPool.length) {
      for (var slot = 0; slot < 4 && ci < catPool.length; slot++) {
        merged.add(catPool[ci++]);
      }
      if (gi < genPool.length) merged.add(genPool[gi++]);
    }

    // ── 3. Diversity pass — no two adjacent articles from the same source ────
    return _diversifyBlogs(merged);
  }

  /// Separates repeated sources throughout the feed, not only when two
  /// adjacent cards happen to match. With four or more distinct sources, a
  /// source gets a three-card recency window; when fewer sources exist, the
  /// strongest possible spacing is used without dropping any articles.
  static List<BlogArticle> _diversifyBlogs(List<BlogArticle> items) {
    if (items.length <= 1) return items;
    final distinctSources = {
      for (final article in items) normalizeSourceName(article.sourceName),
    }..remove('');
    final minGap = math.min(3, math.max(0, distinctSources.length - 1));
    if (minGap == 0) return List<BlogArticle>.from(items);

    final remaining = List<BlogArticle>.from(items);
    final output = <BlogArticle>[];
    final recentSources = <String>[];
    while (remaining.isNotEmpty) {
      var candidateIndex = remaining.indexWhere((article) {
        final source = normalizeSourceName(article.sourceName);
        return !recentSources.contains(source);
      });

      // If every remaining source is in the recency window, choose the one
      // whose prior occurrence is oldest. This keeps the feed deterministic
      // and makes the best possible choice for a small-source feed.
      if (candidateIndex < 0) {
        var oldestDistance = -1;
        for (var i = 0; i < remaining.length; i++) {
          final source = normalizeSourceName(remaining[i].sourceName);
          final distance = recentSources.length -
              recentSources.lastIndexOf(source);
          if (distance > oldestDistance) {
            oldestDistance = distance;
            candidateIndex = i;
          }
        }
      }

      final selected = remaining.removeAt(candidateIndex);
      output.add(selected);
      recentSources.add(normalizeSourceName(selected.sourceName));
      if (recentSources.length > minGap) recentSources.removeAt(0);
    }
    return output;
  }

  void clearCache() {
    _cache = null;
    _cacheTime = null;
  }
}
