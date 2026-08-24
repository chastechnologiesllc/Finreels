import '../data/category_playbook_data.dart';
import '../data/channel_data.dart';
import '../data/resource_category_data.dart';
import '../models/channel.dart';
import '../models/resource_category.dart';
import '../models/video.dart';
import 'blog_rss_service.dart';

/// The kinds of records that can be returned by the homepage search.
enum PlatformSearchKind { short, video, blog, book, category, channel, blogSource }

/// A searchable record from either the bundled catalogue or a live feed.
///
/// [payload] is deliberately retained so the UI can route the result to the
/// existing detail screen without duplicating catalogue parsing logic.
class PlatformSearchDocument {
  final String id;
  final PlatformSearchKind kind;
  final String title;
  final String body;
  final String source;
  final String canonicalKey;
  final String? url;
  final DateTime date;
  final Object payload;
  final List<String> titleAliases;
  final double relevance;

  const PlatformSearchDocument({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.source,
    required this.canonicalKey,
    required this.date,
    required this.payload,
    this.url,
    this.titleAliases = const [],
    this.relevance = 0,
  });

  PlatformSearchDocument withRelevance(double value) => PlatformSearchDocument(
        id: id,
        kind: kind,
        title: title,
        body: body,
        source: source,
        canonicalKey: canonicalKey,
        url: url,
        date: date,
        payload: payload,
        titleAliases: titleAliases,
        relevance: value,
      );
}

/// Builds the app-wide search corpus from every source the app knows about.
///
/// Static catalogue records are loaded once after [ResourceCategoryData.load].
/// Feed videos and fetched blog articles are supplied at query time because
/// they are network/cache state, not bundled catalogue state.
class PlatformSearchIndex {
  PlatformSearchIndex._();
  static final PlatformSearchIndex instance = PlatformSearchIndex._();

  static const _epoch = DateTime(2000);
  static const _stopWords = {
    'a', 'an', 'and', 'are', 'for', 'from', 'how', 'in', 'of', 'on', 'or',
    'the', 'to', 'what', 'with',
  };

  Future<void>? _ready;
  List<PlatformSearchDocument> _staticDocuments = const [];

  Future<void> ensureReady() {
    return _ready ??= _buildStaticIndex();
  }

  /// Exposed for tests and for a future catalogue refresh after an asset
  /// update. It does not clear any network caches.
  Future<void> rebuild() async {
    _ready = null;
    await ensureReady();
  }

  Future<void> _buildStaticIndex() async {
    await ResourceCategoryData.load();
    final documents = <PlatformSearchDocument>[];
    final categoriesById = {
      for (final category in ResourceCategoryData.all) category.id: category,
    };

    for (final category in ResourceCategoryData.all) {
      final moduleText = <String>[];
      for (final code in [
        category.dontKnowModule,
        ...?category.dontKnowModules,
      ]) {
        if (code == null) continue;
        final module = ResourceCategoryData.modules
            .where((candidate) => candidate.code.toLowerCase() == code.toLowerCase())
            .firstOrNull;
        if (module != null) {
          moduleText.add('${module.name} ${module.description}');
        }
      }
      final qaText = category.businessQA
              ?.expand((qa) => [qa.question, qa.answer])
              .join(' ') ??
          '';
      final researchText = <String>[
        category.shortDescription,
        ...?category.skillQuestions,
        qaText,
        ...?category.businessQuestions,
        category.realProblem ?? '',
        category.dontKnowFact ?? '',
        ...moduleText,
      ].where((text) => text.trim().isNotEmpty).join(' ');
      final aliases = category.searchKeywords;
      documents.add(PlatformSearchDocument(
        id: 'category:${category.id}',
        kind: PlatformSearchKind.category,
        title: category.name,
        body: researchText,
        source: category.section.label,
        canonicalKey: 'category:${category.id}',
        date: _epoch,
        payload: category,
        titleAliases: aliases,
      ));
    }

    // Generated category playbooks are real in-app research documents. They
    // remain searchable even though the Books tab intentionally does not dump
    // every category's playbook into a selection-scoped feed.
    for (final playbook in CategoryPlaybookData.videos) {
      documents.add(PlatformSearchDocument(
        id: 'playbook:${playbook.id}',
        kind: PlatformSearchKind.book,
        title: playbook.title,
        body: playbook.description,
        source: playbook.channelName,
        canonicalKey: 'playbook:${playbook.id}',
        date: playbook.publishedAt,
        payload: playbook,
      ));
    }

    final seenChannels = <String>{};
    for (final channel in ChannelData.combined) {
      if (!seenChannels.add(channel.id)) continue;
      final categoryName = categoryNameFor(channel.resourceCategoryId, categoriesById);
      documents.add(PlatformSearchDocument(
        id: 'channel:${channel.id}',
        kind: PlatformSearchKind.channel,
        title: channel.name,
        body: '${channel.handle} ${channel.description} ${channel.focus} '
            '${channel.category} $categoryName',
        source: '${channel.category} · ${channel.focus}',
        canonicalKey: 'channel:${channel.id}',
        date: _epoch,
        payload: channel,
        titleAliases: [channel.handle],
      ));
    }

    final seenBlogSources = <String>{};
    final blogSources = <Map<String, String>>[
      ...kBlogFeeds,
      ...ResourceCategoryData.verifiedBlogs,
    ];
    for (final source in blogSources) {
      final name = source['name']?.trim() ?? '';
      final url = source['url']?.trim() ?? '';
      if (name.isEmpty || url.isEmpty) continue;
      final key = _canonicalUrl(url);
      if (!seenBlogSources.add(key)) continue;
      final categoryName = categoryNameFor(source['categoryId'], categoriesById);
      documents.add(PlatformSearchDocument(
        id: 'blog-source:$key',
        kind: PlatformSearchKind.blogSource,
        title: name,
        body: '${source['focus'] ?? ''} ${source['region'] ?? ''} $categoryName',
        source: categoryName.isEmpty ? 'Blog source' : 'Blog · $categoryName',
        canonicalKey: 'blog-source:$key',
        url: url,
        date: _epoch,
        payload: source,
      ));
    }

    final seenBooks = <String>{};
    for (final book in ResourceCategoryData.verifiedBooks) {
      final key = _bookKey(book);
      if (!seenBooks.add(key)) continue;
      final categoryName = categoryNameFor(book.categoryId, categoriesById);
      documents.add(PlatformSearchDocument(
        id: 'verified-book:$key',
        kind: PlatformSearchKind.book,
        title: book.title,
        body: '${book.author} ${book.freeSourceNote ?? ''} $categoryName',
        source: book.author,
        canonicalKey: 'book:$key',
        url: book.freeSourceUrl,
        date: _epoch,
        payload: book,
        titleAliases: [book.author],
      ));
    }

    _staticDocuments = List.unmodifiable(documents);
  }

  /// Searches static catalogue documents plus the currently loaded dynamic
  /// content. A result must match at least one meaningful term; records that
  /// match every term receive a substantial coverage boost.
  List<PlatformSearchDocument> search({
    required String query,
    List<Video> videos = const [],
    List<Video> books = const [],
    List<BlogArticle> articles = const [],
    int limit = 120,
  }) {
    final raw = query.trim();
    if (raw.isEmpty) return const [];
    final documents = <PlatformSearchDocument>[..._staticDocuments];
    final seen = <String>{for (final doc in documents) doc.canonicalKey};

    for (final video in videos) {
      final key = 'video:${video.id}';
      if (!seen.add(key)) continue;
      documents.add(PlatformSearchDocument(
        id: key,
        kind: video.isShort ? PlatformSearchKind.short : PlatformSearchKind.video,
        title: video.title,
        body: video.description,
        source: '${video.channelName} ${video.channelId}',
        canonicalKey: key,
        date: video.publishedAt,
        payload: video,
        titleAliases: [video.channelName],
      ));
    }

    // FeedProvider intentionally selection-scopes its book tab. The static
    // verified-book documents above keep all verified books discoverable; the
    // dynamic list is still needed for bundled books and generated playbooks.
    for (final book in books) {
      if (book.channelId == 'verified_book') continue;
      final key = 'book:${book.id}';
      if (!seen.add(key)) continue;
      documents.add(PlatformSearchDocument(
        id: key,
        kind: PlatformSearchKind.book,
        title: book.title,
        body: book.description,
        source: book.channelName,
        canonicalKey: key,
        date: book.publishedAt,
        payload: book,
        titleAliases: [book.channelName],
      ));
    }

    for (final article in articles) {
      final key = 'blog:${_canonicalUrl(article.url)}';
      if (!seen.add(key)) continue;
      documents.add(PlatformSearchDocument(
        id: key,
        kind: PlatformSearchKind.blog,
        title: article.title,
        body: article.excerpt,
        source: article.sourceName,
        canonicalKey: key,
        url: article.url,
        date: article.publishedAt,
        payload: article,
      ));
    }

    final scored = <_ScoredDocument>[];
    for (final document in documents) {
      final score = _score(raw, document);
      if (score > 0) scored.add(_ScoredDocument(document, score));
    }
    scored.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) return scoreOrder;
      final dateOrder = b.document.date.compareTo(a.document.date);
      if (dateOrder != 0) return dateOrder;
      return a.document.title.toLowerCase().compareTo(b.document.title.toLowerCase());
    });
    return [
      for (final item in scored.take(limit))
        item.document.withRelevance(item.score),
    ];
  }

  static double _score(String rawQuery, PlatformSearchDocument document) {
    final normalizedQuery = _normalize(rawQuery);
    if (normalizedQuery.isEmpty) return 0;
    final queryTokens = _tokens(normalizedQuery);
    if (queryTokens.isEmpty) return 0;

    final title = _normalize(document.title);
    final aliases = _normalize(document.titleAliases.join(' '));
    final body = _normalize(document.body);
    final source = _normalize(document.source);
    final allText = '$title $aliases $body $source';
    final titleTokens = _tokens(title);
    final allTokens = _tokens(allText);
    final phrases = RegExp(r'"([^"]+)"')
        .allMatches(rawQuery)
        .map((match) => _normalize(match.group(1) ?? ''))
        .where((phrase) => phrase.isNotEmpty)
        .toList();

    double score = 0;
    final exactTitle = title == normalizedQuery;
    if (exactTitle) score += 250;
    if (title.contains(normalizedQuery) && normalizedQuery.length >= 2) score += 120;
    for (final phrase in phrases) {
      if (title.contains(phrase)) score += 160;
      if (allText.contains(phrase)) score += 35;
    }

    var matched = 0;
    for (final term in queryTokens) {
      final titleMatch = _termMatches(term, titleTokens, title);
      final aliasMatch = _termMatches(term, _tokens(aliases), aliases);
      final sourceMatch = _termMatches(term, _tokens(source), source);
      final bodyMatch = _termMatches(term, _tokens(body), body);
      if (!titleMatch && !aliasMatch && !sourceMatch && !bodyMatch) continue;
      matched++;
      if (titleMatch) score += titleTokens.contains(term) ? 62 : 34;
      if (aliasMatch) score += 48;
      if (sourceMatch) score += 24;
      if (bodyMatch) score += 14;
      if (allTokens.contains(term)) score += 5;
    }

    if (matched == 0) return 0;
    if (matched == queryTokens.length) score += 90;
    else if (queryTokens.length > 1) score -= (queryTokens.length - matched) * 12;

    // A one-edit tolerance catches common typos, but only against title/source
    // words and only for terms of four or more characters to avoid noisy hits.
    for (final term in queryTokens.where((term) => term.length >= 4)) {
      if (_nearToken(term, [...titleTokens, ..._tokens(aliases), ..._tokens(source)])) {
        score += 8;
      }
    }
    return score;
  }

  static bool _termMatches(String term, List<String> tokens, String text) {
    if (term.length < 2) return text == term || tokens.contains(term);
    if (tokens.contains(term) || text.contains(term)) return true;
    final stems = _stems(term);
    return stems.any((stem) => stem.length >= 3 &&
        (tokens.contains(stem) || text.contains(stem)));
  }

  static bool _nearToken(String term, Iterable<String> candidates) {
    for (final candidate in candidates) {
      if ((candidate.length - term.length).abs() > 1) continue;
      if (_levenshtein(term, candidate) <= 1) return true;
    }
    return false;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final insert = current[j + 1] + 1;
        final delete = previous[j + 1] + 1;
        final replace = previous[j] + (a[i] == b[j] ? 0 : 1);
        current[j + 1] = [insert, delete, replace].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous.last;
  }

  static List<String> _tokens(String value) => value
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length >= 2 && !_stopWords.contains(token))
      .toList(growable: false);

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[’‘`]', unicode: true), "'")
      .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<String> _stems(String word) => [
        if (word.endsWith('ing')) word.substring(0, word.length - 3),
        if (word.endsWith('ing')) '${word.substring(0, word.length - 3)}e',
        if (word.endsWith('tion')) word.substring(0, word.length - 4),
        if (word.endsWith('ness')) word.substring(0, word.length - 4),
        if (word.endsWith('ment')) word.substring(0, word.length - 4),
        if (word.endsWith('er')) word.substring(0, word.length - 2),
        if (word.endsWith('ed')) word.substring(0, word.length - 2),
        if (word.endsWith('ly')) word.substring(0, word.length - 2),
        if (word.endsWith('ies')) '${word.substring(0, word.length - 3)}y',
        if (word.endsWith('s') && !word.endsWith('ss')) word.substring(0, word.length - 1),
      ];

  static String categoryNameFor(
      String? id, Map<String, ResourceCategory> categoriesById) =>
      id == null ? '' : categoriesById[id]?.name ?? '';

  static String _canonicalUrl(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'^www\.'), '')
      .replaceFirst(RegExp(r'/+$'), '');

  static String _bookKey(VerifiedBook book) =>
      _canonicalUrl(book.freeSourceUrl).isNotEmpty
          ? _canonicalUrl(book.freeSourceUrl)
          : '${book.title.toLowerCase()}|${book.author.toLowerCase()}';
}

class _ScoredDocument {
  final PlatformSearchDocument document;
  final double score;
  const _ScoredDocument(this.document, this.score);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
EOF
