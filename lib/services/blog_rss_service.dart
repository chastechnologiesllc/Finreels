import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../utils/web_jsonp.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../data/resource_category_data.dart';
import 'user_profile_service.dart';

/// A single parsed blog article from an RSS/Atom feed.
class BlogArticle {
  final String title;
  final String url;
  final String sourceName;
  final String? thumbnailUrl;
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
    this.thumbnailUrl,
    this.excerpt = '',
    this.categoryId,
  });
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
    'name': 'Forbes Entrepreneurs',
    'url': 'https://www.forbes.com/entrepreneurs/feed/',
  },
  {
    'name': 'Harvard Business Review',
    'url': 'https://feeds.hbr.org/harvardbusiness',
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

  /// Powers the aggregated, passive Blogs tab — general feeds plus
  /// whatever categories the person selected (see [combinedBlogFeeds]).
  /// Cached for 10 minutes; FeedProvider clears that cache the moment the
  /// person's category selection changes, so switching category never
  /// shows stale, wrongly-scoped articles for the rest of that window.
  Future<List<BlogArticle>> fetchAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheFresh) return _cache!;

    final futures = combinedBlogFeeds.map(
      (feed) => _fetchFeed(
        url: feed['url']!,
        sourceName: feed['name']!,
        categoryId: feed['categoryId'],
      ),
    );

    final results = await Future.wait(futures);
    final articles = results.expand((l) => l).toList();
    final selected = UserProfileService.instance.selectedCategoryIds;
    final mixed = await compute(
      _smartMixArticles,
      _SmartMixArgs(articles: articles, selectedCategoryIds: selected),
    );
    _cache = mixed;
    _cacheTime = DateTime.now();
    return mixed;
  }

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

    final futures = feeds.map(
      (feed) => _fetchFeed(
        url: feed['url']!,
        sourceName: feed['name']!,
        categoryId: feed['categoryId'],
      ),
    );
    final results = await Future.wait(futures);
    final articles = results.expand((l) => l).toList();
    return compute(_sortArticles, articles);
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
        'User-Agent': 'FinReels/1.0 (+com.chastechgroup.finreels)',
        'Accept': 'application/rss+xml, application/xml, text/xml',
      }).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return [];

      final body = response.body;
      return await compute<List<String>, List<BlogArticle>>(
        (args) => _parse(args[0], args[1], args[2].isEmpty ? null : args[2]),
        [body, sourceName, categoryId ?? ''],
      );
    } on Exception catch (e) {
      debugPrint('[BlogRssService] $sourceName failed: $e');
      return [];
    }
  }

  Future<List<BlogArticle>> _fetchFeedWeb({
    required String url,
    required String sourceName,
    String? categoryId,
  }) async {
    final api = Uri.parse(AppConfig.webRss2JsonEndpoint).replace(
      queryParameters: {'rss_url': url},
    );
    final data = await fetchJsonp(api.toString());
    if (data['status'] != 'ok') return [];
    final items = data['items'];
    if (items is! List) return [];

    final articles = <BlogArticle>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final link = ((map['link'] as String?) ?? '').trim();
      if (link.isEmpty) continue;
      final title = ((map['title'] as String?) ?? '').trim();
      if (title.isEmpty) continue;
      final pubStr = (map['pubDate'] as String?) ?? '';
      final publishedAt = DateTime.tryParse(pubStr) ?? DateTime.now();
      final thumb = (map['thumbnail'] as String?)?.trim();
      final excerpt = ((map['description'] as String?) ?? '')
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      articles.add(BlogArticle(
        title: title,
        url: link,
        sourceName: sourceName,
        publishedAt: publishedAt,
        thumbnailUrl: (thumb != null && thumb.isNotEmpty) ? thumb : null,
        excerpt: excerpt.length > 280 ? '${excerpt.substring(0, 280)}…' : excerpt,
        categoryId: categoryId,
      ));
    }
    return articles;
  }

  static List<BlogArticle> _parse(String body, String sourceName, [String? categoryId]) {
    try {
      final doc = XmlDocument.parse(body);

      // ── RSS 2.0 ──────────────────────────────────────────────────────────
      final rssItems = doc.findAllElements('item');
      if (rssItems.isNotEmpty) {
        return rssItems.map((item) {
          final link = _text(item, 'link') ?? _text(item, 'guid') ?? '';
          if (link.isEmpty) return null;

          // Thumbnail priority:
          // 1. <enclosure url="..." type="image/..."> — most explicit
          // 2. <media:content url="..."> — media RSS extension
          // 3. <media:thumbnail url="..."> — media RSS
          // 4. First <img src="..."> in <content:encoded> HTML — WordPress
          //    blogs always put images here even when they omit the above tags
          // 5. First <img src="..."> in <description> HTML — fallback
          var thumb = item.findElements('enclosure')
              .where((e) => (e.getAttribute('type') ?? '').startsWith('image'))
              .firstOrNull
              ?.getAttribute('url');

          if (thumb == null || thumb.isEmpty) {
            thumb = item.findElements('media:content')
                .where((e) => (e.getAttribute('medium') ?? '').contains('image') ||
                    (e.getAttribute('type') ?? '').startsWith('image') ||
                    (e.getAttribute('url') ?? '').contains(RegExp(r'\.(jpg|jpeg|png|webp|gif)', caseSensitive: false)))
                .firstOrNull
                ?.getAttribute('url');
          }
          if (thumb == null || thumb.isEmpty) {
            thumb = item.findElements('media:thumbnail').firstOrNull?.getAttribute('url');
          }
          // WordPress <content:encoded> — the body HTML almost always has
          // the featured image as the first <img>. Try this before giving up.
          if (thumb == null || thumb.isEmpty) {
            final contentEncoded = _text(item, 'content:encoded') ?? '';
            thumb = _firstImgSrc(contentEncoded);
          }
          // Last resort — description may also be HTML
          if (thumb == null || thumb.isEmpty) {
            final desc = _text(item, 'description') ?? '';
            thumb = _firstImgSrc(desc);
          }

          final pubStr = _text(item, 'pubDate') ?? '';
          final published = _parseRssDate(pubStr) ?? DateTime.now();

          return BlogArticle(
            title: _clean(_text(item, 'title') ?? 'Untitled'),
            url: link,
            sourceName: sourceName,
            thumbnailUrl: thumb,
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
          final link = entry.findElements('link').firstOrNull
              ?.getAttribute('href') ?? '';
          if (link.isEmpty) return null;

          // Atom feeds rarely carry media extensions but it costs nothing to try
          var thumb = entry.findElements('media:thumbnail').firstOrNull?.getAttribute('url');
          if (thumb == null || thumb.isEmpty) {
            thumb = entry.findElements('media:content')
                .where((e) => (e.getAttribute('medium') ?? '').contains('image') ||
                    (e.getAttribute('type') ?? '').startsWith('image'))
                .firstOrNull
                ?.getAttribute('url');
          }
          if (thumb == null || thumb.isEmpty) {
            final content = _text(entry, 'content') ?? _text(entry, 'summary') ?? '';
            thumb = _firstImgSrc(content);
          }

          final updStr =
              _text(entry, 'updated') ?? _text(entry, 'published') ?? '';
          final published = DateTime.tryParse(updStr) ?? DateTime.now();

          return BlogArticle(
            title: _clean(_text(entry, 'title') ?? 'Untitled'),
            url: link,
            sourceName: sourceName,
            thumbnailUrl: thumb,
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

  /// Extracts the first image URL from an HTML string.
  /// Works for WordPress content:encoded, description CDATA, and Atom content.
  static String? _firstImgSrc(String html) {
    if (html.isEmpty) return null;
    // Match both single and double quote variants.
    final match = RegExp(
      '''<img[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      final src = match.group(1) ?? '';
      // Skip tiny spacer/tracking images (1x1 px, data URIs, etc.)
      if (src.isNotEmpty &&
          !src.startsWith('data:') &&
          !src.contains('1x1') &&
          !src.contains('pixel') &&
          !src.contains('tracking')) {
        return src;
      }
    }
    return null;
  }

  static String? _text(XmlElement el, String tag) =>
      el.findElements(tag).firstOrNull?.innerText.trim();

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

  // ── Smart mix: 3-to-1 category vs general, no consecutive same source ───────

  /// Passed to [compute] because isolates can only receive plain data.
  static List<BlogArticle> _smartMixArticles(_SmartMixArgs args) {
    final articles   = args.articles;
    final selectedIds = args.selectedCategoryIds;

    // ── 1. Split into two pools, each sorted newest first ───────────────────
    final catPool = <BlogArticle>[];
    final genPool = <BlogArticle>[];
    for (final a in articles) {
      final isCat = a.categoryId != null && selectedIds.contains(a.categoryId);
      (isCat ? catPool : genPool).add(a);
    }
    catPool.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    genPool.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    // Fallback: no selection or no category articles → plain date sort
    if (selectedIds.isEmpty || catPool.isEmpty) {
      final all = [...genPool, ...catPool]
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return _diversifyBlogs(all);
    }

    // ── 2. 3:1 weighted interleave ───────────────────────────────────────────
    // 3 category articles, then 1 general, then 3 category, etc.
    final merged = <BlogArticle>[];
    var ci = 0;
    var gi = 0;
    while (ci < catPool.length || gi < genPool.length) {
      for (var slot = 0; slot < 3 && ci < catPool.length; slot++) {
        merged.add(catPool[ci++]);
      }
      if (gi < genPool.length) merged.add(genPool[gi++]);
    }

    // ── 3. Diversity pass — no two adjacent articles from the same source ────
    return _diversifyBlogs(merged);
  }

  /// No two adjacent articles share the same [sourceName].
  /// Same forward-scan rotation algorithm used by FeedProvider._diversify.
  static List<BlogArticle> _diversifyBlogs(List<BlogArticle> items) {
    if (items.length <= 1) return items;
    final out = List<BlogArticle>.from(items);
    final n   = out.length;
    for (var i = 1; i < n; i++) {
      if (out[i].sourceName != out[i - 1].sourceName) continue;
      var j = i + 1;
      while (j < n && out[j].sourceName == out[i - 1].sourceName) {
        j++;
      }
      if (j < n) {
        final swap = out.removeAt(j);
        out.insert(i, swap);
      }
    }
    return out;
  }

  void clearCache() {
    _cache = null;
    _cacheTime = null;
  }
}
