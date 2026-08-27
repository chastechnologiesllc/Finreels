import 'dart:async';

import 'package:flutter/material.dart';

import '../data/channel_data.dart';
import '../models/channel.dart';
import '../models/resource_category.dart';
import '../models/saved_bookmark.dart';
import '../models/video.dart';
import '../providers/feed_provider.dart';
import '../services/ad_service.dart';
import '../services/blog_rss_service.dart';
import '../services/platform_search_index.dart';
import '../theme/app_theme.dart';
import '../widgets/blog_thumbnail_image.dart';
import '../widgets/book_cover_image.dart';
import '../widgets/finreels_shimmer.dart';
import '../widgets/no_flash_page_route.dart';
import '../widgets/video_thumbnail_image.dart';
import 'blog_channel_screen.dart';
import 'blog_reader_screen.dart';
import 'book_detail_screen.dart';
import 'category_detail_screen.dart';
import 'channel_videos_screen.dart';
import 'shorts_player_screen.dart';
import 'video_player_screen.dart';

// ── Unified search result ───────────────────────────────────────────────────

enum _ResultKind { short, video, blog, book, category, channel, blogSource }

class _SearchItem {
  final _ResultKind kind;
  final Video? video;
  final BlogArticle? article;
  final ResourceCategory? category;
  final Channel? channel;
  final Map<String, String>? blogSource;
  final VerifiedBook? verifiedBook;
  final double score;

  const _SearchItem.video(this.video, this.score)
      : kind = _ResultKind.video,
        article = null,
        category = null,
        channel = null,
        blogSource = null,
        verifiedBook = null;
  const _SearchItem.short(this.video, this.score)
      : kind = _ResultKind.short,
        article = null,
        category = null,
        channel = null,
        blogSource = null,
        verifiedBook = null;
  const _SearchItem.blog(this.article, this.score)
      : kind = _ResultKind.blog,
        video = null,
        category = null,
        channel = null,
        blogSource = null,
        verifiedBook = null;
  const _SearchItem.book(this.video, this.score)
      : kind = _ResultKind.book,
        article = null,
        category = null,
        channel = null,
        blogSource = null,
        verifiedBook = null;
  const _SearchItem.category(this.category, this.score)
      : kind = _ResultKind.category,
        video = null,
        article = null,
        channel = null,
        blogSource = null,
        verifiedBook = null;
  const _SearchItem.channel(this.channel, this.score)
      : kind = _ResultKind.channel,
        video = null,
        article = null,
        category = null,
        blogSource = null,
        verifiedBook = null;
  const _SearchItem.blogSource(this.blogSource, this.score)
      : kind = _ResultKind.blogSource,
        video = null,
        article = null,
        category = null,
        channel = null,
        verifiedBook = null;

  const _SearchItem.verifiedBook(this.verifiedBook, this.score)
      : kind = _ResultKind.book,
        video = null,
        article = null,
        category = null,
        channel = null,
        blogSource = null;

  bool get isShort => kind == _ResultKind.short;
  bool get canBookmark => !isShort &&
      (video != null || article != null || verifiedBook != null);

  DateTime get date => video?.publishedAt ?? article?.publishedAt ?? DateTime(2000);
}

// ── Screen ─────────────────────────────────────────────────────────────────

/// In-app content search — searches every piece of content loaded in the app:
/// videos, shorts, blog articles (from the cached RSS feeds), and books.
///
/// Results are displayed in the 2-column layout matching the design brief:
///   LEFT  column — Shorts (9:16 portrait cards, tap → ShortsPlayerScreen)
///   RIGHT column — Videos, Blogs, Books (tap → appropriate detail screen)
///
/// IMPORTANT: This screen is pushed as a route, so its BuildContext is NOT
/// under the MultiProvider that wraps the app shell. FeedProvider is therefore
/// passed as a constructor parameter (read at the push site, which IS inside
/// MultiProvider) rather than via context.read() in initState().
class ContentSearchScreen extends StatefulWidget {
  final FeedProvider feedProvider;
  const ContentSearchScreen({required this.feedProvider, super.key});

  @override
  State<ContentSearchScreen> createState() => _ContentSearchScreenState();
}

class _ContentSearchScreenState extends State<ContentSearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  bool _fetchingBlogs = false;
  bool _typing = false;
  int _searchGeneration = 0;

  List<_SearchItem> _left  = [];
  List<_SearchItem> _right = [];

  // Shorthand — widget.feedProvider passed from the push site (inside
  // MultiProvider) so context.read() is never needed inside this State.
  FeedProvider get _fp => widget.feedProvider;
  FeedState _lastFeedState = FeedState.idle;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onInput);
    _lastFeedState = _fp.state;
    // Listen to feed so we re-search automatically when it finishes loading
    // on a cold launch where the user typed before videos were in memory.
    _fp.addListener(_onFeedChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fp.removeListener(_onFeedChanged);
    _ctrl
      ..removeListener(_onInput)
      ..dispose();
    super.dispose();
  }

  void _onFeedChanged() {
    if (mounted) setState(() {});
    final newState = _fp.state;
    if (_lastFeedState == FeedState.loading &&
        newState == FeedState.loaded &&
        _query.length >= 2 &&
        !_typing) {
      final generation = ++_searchGeneration;
      unawaited(_search(_query, generation));
    }
    _lastFeedState = newState;
  }

  void _onInput() {
    _debounce?.cancel();
    final q = _ctrl.text.trim();
    if (q == _query && !_typing && !_loading) return;
    final generation = ++_searchGeneration;

    if (q.length < 2) {
      setState(() {
        _query = q;
        _left = [];
        _right = [];
        _loading = false;
        _fetchingBlogs = false;
        _typing = false;
      });
      return;
    }

    // Clear stale results immediately. The generation token prevents an old
    // index or blog request from painting over the newer query.
    setState(() {
      _query = q;
      _left = [];
      _right = [];
      _loading = true;
      _fetchingBlogs = false;
      _typing = true;
    });

    // Debounce only the expensive search work, keeping the text field itself
    // responsive while avoiding one full index pass per keystroke.
    _debounce = Timer(
      const Duration(milliseconds: 200),
      () => unawaited(_search(q, generation)),
    );
  }

  // ── Scoring ─────────────────────────────────────────────────────────────
  //
  // Multi-pass matching so a tailor searching "cloth business profit" finds
  // "Fashion for Profit" (title match), channels about textiles (description),
  // and Entrepreneur articles (source). Order of pass priority:
  //   1. Exact full-query match in title     → 5.0 pts
  //   2. Any query word in title             → 2.0 pts each
  //   3. Any query word in description       → 1.0 pts each
  //   4. Any query word in source/channel    → 0.5 pts each
  //   5. Stem of query word (strip -ing/-er/-ed/-s) also checked at 0.5×

  // ── Search ──────────────────────────────────────────────────────────────

  SavedBookmark _bookmarkFor(_SearchItem item) {
    if (item.article != null) return SavedBookmark.fromBlog(item.article!);
    if (item.verifiedBook != null) {
      final book = item.verifiedBook!;
      return SavedBookmark(
        id: book.freeSourceUrl,
        kind: SavedBookmarkKind.book,
        title: book.title,
        description: book.freeSourceNote ?? book.author,
        sourceName: book.author,
        url: book.freeSourceUrl,
        thumbnailUrl: book.coverUrl,
        thumbnailFallbackUrls: book.coverCandidates,
        publishedAt: DateTime(2000),
        sourceCategoryId: book.categoryId,
        freeSourceType: book.freeSourceType,
      );
    }
    return SavedBookmark.fromVideo(item.video!);
  }

  bool _isItemSaved(_SearchItem item) =>
      item.canBookmark && _fp.isBookmarkSaved(_bookmarkFor(item).stableKey);

  Future<void> _toggleItemSaved(_SearchItem item) async {
    if (!item.canBookmark) return;
    await _fp.toggleBookmark(_bookmarkFor(item));
  }

  _SearchItem _itemFor(PlatformSearchDocument document) {
    final score = document.relevance;
    switch (document.kind) {
      case PlatformSearchKind.short:
        return _SearchItem.short(document.payload as Video, score);
      case PlatformSearchKind.video:
        return _SearchItem.video(document.payload as Video, score);
      case PlatformSearchKind.blog:
        return _SearchItem.blog(document.payload as BlogArticle, score);
      case PlatformSearchKind.book:
        final payload = document.payload;
        if (payload is VerifiedBook) return _SearchItem.verifiedBook(payload, score);
        return _SearchItem.book(payload as Video, score);
      case PlatformSearchKind.category:
        return _SearchItem.category(document.payload as ResourceCategory, score);
      case PlatformSearchKind.channel:
        return _SearchItem.channel(document.payload as Channel, score);
      case PlatformSearchKind.blogSource:
        return _SearchItem.blogSource(document.payload as Map<String, String>, score);
    }
  }

  Future<void> _search(String q, int generation) async {
    if (!_isCurrentSearch(q, generation)) return;
    setState(() {
      _query = q;
      _loading = true;
      _fetchingBlogs = false;
      _typing = false;
    });

    // Start the cheap, same-origin blog seed in parallel with index readiness.
    // It can complete from the 10-minute RSS cache or bundled snapshot without
    // waiting for live network requests.
    final seedFuture = BlogRssService.instance
        .fetchSearchSeed()
        .catchError((_) => const <BlogArticle>[]);

    await PlatformSearchIndex.instance.ensureReady();
    if (!_isCurrentSearch(q, generation)) return;

    // Stage 1: score the indexed categories, channels, books, videos and
    // Shorts in bounded batches. Each batch is published immediately so broad
    // two-letter queries never monopolize the UI isolate.
    final newLeft = <_SearchItem>[];
    final newRight = <_SearchItem>[];

    int cmp(_SearchItem a, _SearchItem b) {
      final sc = b.score.compareTo(a.score);
      return sc != 0 ? sc : b.date.compareTo(a.date);
    }

    await for (final batch in PlatformSearchIndex.instance.searchProgressively(
      query: q,
      videos: _fp.allFeedVideos,
      books: _fp.allBooksForSearch,
    )) {
      if (!_isCurrentSearch(q, generation)) return;
      for (final document in batch) {
        final item = _itemFor(document);
        if (item.isShort) {
          newLeft.add(item);
        } else {
          newRight.add(item);
        }
      }
      newLeft.sort(cmp);
      newRight.sort(cmp);
      if (_isCurrentSearch(q, generation)) {
        setState(() {
          _left = List.unmodifiable(newLeft);
          _right = List.unmodifiable(newRight);
          _loading = false;
          _fetchingBlogs = true;
        });
      }
    }

    if (!_isCurrentSearch(q, generation)) return;
    // A query with no indexed matches still transitions out of the index
    // stage, allowing the blog seed/live stages to finish and the UI to show
    // a truthful "0 results so far" state rather than an indefinite spinner.
    if (_loading) {
      setState(() {
        _loading = false;
        _fetchingBlogs = true;
      });
    }

    Future<void> mergeBlogs(List<BlogArticle> articles) async {
      if (!_isCurrentSearch(q, generation) || articles.isEmpty) return;
      final blogDocs = PlatformSearchIndex.instance
          .search(query: q, articles: articles)
          .where((document) => document.kind == PlatformSearchKind.blog);
      final blogItems = [for (final document in blogDocs) _itemFor(document)];
      final existingKeys = {for (final item in _right) _itemKey(item)};
      final merged = [
        ..._right,
        ...blogItems.where((item) => existingKeys.add(_itemKey(item))),
      ]..sort(cmp);
      if (_isCurrentSearch(q, generation)) {
        setState(() => _right = merged);
      }
    }

    // Stage 2: merge local snapshot/fresh-cache articles as soon as ready.
    final seedArticles = await seedFuture;
    if (!_isCurrentSearch(q, generation)) return;
    await mergeBlogs(seedArticles);

    // Stage 3: fetch live RSS only after the fast result set is visible.
    try {
      final articles = await BlogRssService.instance
          .fetchAll()
          .timeout(const Duration(seconds: 5));
      if (!_isCurrentSearch(q, generation)) return;
      await mergeBlogs(articles);
    } on TimeoutException {
      debugPrint('[ContentSearch] blog fetch timed out for: $q');
    } on Exception catch (e) {
      debugPrint('[ContentSearch] blog fetch error: $e');
    } finally {
      if (_isCurrentSearch(q, generation)) {
        setState(() => _fetchingBlogs = false);
      }
    }
  }

  bool _isCurrentSearch(String q, int generation) =>
      mounted && generation == _searchGeneration && _ctrl.text.trim() == q;

  String _itemKey(_SearchItem item) {
    if (item.video != null) return 'video:${item.video!.id}';
    if (item.article != null) return 'blog:${item.article!.url}';
    if (item.category != null) return 'category:${item.category!.id}';
    if (item.channel != null) return 'channel:${item.channel!.id}';
    if (item.blogSource != null) return 'blog-source:${item.blogSource!['url']}';
    if (item.verifiedBook != null) {
      return 'verified-book:${item.verifiedBook!.freeSourceUrl}';
    }
    return item.toString();
  }

  // ── Navigation helpers ──────────────────────────────────────────────────

  void _openShort(int index) {
    final shorts = _left.map((e) => e.video!).toList();
    Navigator.push(
      context,
      NoFlashPageRoute(
        builder: (_) => ShortsPlayerScreen(
          shorts:       shorts,
          initialIndex: index,
        ),
      ),
    );
  }

  void _openVideo(Video v) {
    final ch = ChannelData.byId[v.channelId] ?? ChannelData.fallback;
    unawaited(AdService.instance.onVideoTapped());
    Navigator.push(
      context,
      NoFlashPageRoute(builder: (_) => VideoPlayerScreen(video: v, channel: ch)),
    );
  }

  void _openBook(Video b) {
    if (b.channelId == 'verified_book') {
      if ((b.freeSourceUrl ?? '').isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlogReaderScreen(
            url:        b.freeSourceUrl!,
            title:      b.title,
            categoryId: b.sourceCategoryId,
          ),
        ),
      );
    } else {
      unawaited(AdService.instance.onVideoTapped());
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookDetailScreen(book: b)),
      );
    }
  }

  void _openBlogChannel(String sourceName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlogChannelScreen(sourceName: sourceName),
      ),
    );
  }

  void _openArticle(BlogArticle a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlogReaderScreen(
          url:          a.url,
          title:        a.title,
          sourceName:   a.sourceName,
          thumbnailUrl: a.thumbnailUrl,
          excerpt:      a.excerpt.isNotEmpty ? a.excerpt : null,
          publishedAt:  a.publishedAt,
          categoryId:   a.categoryId,
        ),
      ),
    );
  }

  void _openCategory(ResourceCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoryDetailScreen(category: category)),
    );
  }

  void _openChannel(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChannelVideosScreen(channel: channel)),
    );
  }

  void _openVerifiedBook(VerifiedBook book) {
    if (book.freeSourceUrl.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlogReaderScreen(
          url: book.freeSourceUrl,
          title: book.title,
          sourceName: book.author,
          categoryId: book.categoryId,
        ),
      ),
    );
  }

  void _openBlogSource(Map<String, String> source) {
    final name = source['name']?.trim();
    if (name != null && name.isNotEmpty) {
      _openBlogChannel(name);
      return;
    }
    final url = source['url']?.trim();
    if (url == null || url.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlogReaderScreen(
          url: url,
          title: 'Blog source',
          categoryId: source['categoryId'],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: _SearchBar(controller: _ctrl),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _ctrl.clear();
                setState(() { _query = ''; _left = []; _right = []; });
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  String get _resultSummary {
    final count = _left.length + _right.length;
    if (_typing || (_loading && count == 0)) {
      return 'Searching for "$_query"…';
    }
    if (_fetchingBlogs) {
      return '$count results so far for "$_query"';
    }
    return '$count results for "$_query"';
  }

  Widget _buildBody() {
    if (_query.isEmpty) return _EmptyPrompt();

    final hasResults = _left.isNotEmpty || _right.isNotEmpty;
    final feedLoading = _fp.state == FeedState.loading ||
        _fp.state == FeedState.idle;
    final stillLoading = _typing || _loading || _fetchingBlogs ||
        (!hasResults && feedLoading);

    // Never block the text field with a centered spinner. While the first
    // stage is pending, show an animated, bounded result preview; once any
    // stage completes, the real lazy result list stays visible and its count
    // continues to update as later stages arrive.
    if (!hasResults && stillLoading) {
      return _SearchProgress(
        query: _query,
        waitingForIndex: _typing || _loading,
        visibleCount: 0,
      );
    }

    if (!hasResults) {
      return _NoResults(query: _query, stillFetchingBlogs: _fetchingBlogs);
    }

    final pairCount = _left.length < _right.length ? _left.length : _right.length;
    final rightTailCount = _right.length - pairCount;
    final leftTailCount = _left.length - pairCount;

    Widget rightCard(_SearchItem item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ContentCard(
            item: item,
            saved: _isItemSaved(item),
            onSave: () => _toggleItemSaved(item),
            onTapVideo: _openVideo,
            onTapBook: _openBook,
            onTapBlog: _openArticle,
            onTapBlogChannel: _openBlogChannel,
            onTapCategory: _openCategory,
            onTapChannel: _openChannel,
            onTapVerifiedBook: _openVerifiedBook,
            onTapBlogSource: _openBlogSource,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _resultSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted(context)),
                ),
              ),
              if (_typing || _loading || _fetchingBlogs) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      color: AppTheme.gold,
                      backgroundColor: Color(0x33219E8A),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_left.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _ColHeader('Shorts', Icons.play_circle_outline_rounded)),
                SizedBox(width: 8),
                Expanded(child: _ColHeader('Videos • Blogs • Books • Sources', Icons.grid_view_rounded)),
              ],
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _ColHeader('Videos • Blogs • Books • Sources', Icons.grid_view_rounded),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: _left.isEmpty
                ? _right.length
                : pairCount + rightTailCount + leftTailCount,
            itemBuilder: (ctx, i) {
              // Without Shorts, every non-Short result receives the full width.
              if (_left.isEmpty) return rightCard(_right[i]);

              // Keep the search-style two-column treatment while both columns
              // have content, without IntrinsicHeight's extra layout pass.
              if (i < pairCount) {
                final short = _left[i];
                final right = _right[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ShortCard(
                          item: short,
                          onTap: () => _openShort(i),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _ContentCard(
                        item: right,
                        saved: _isItemSaved(right),
                        onSave: () => _toggleItemSaved(right),
                        onTapVideo: _openVideo,
                        onTapBook: _openBook,
                        onTapBlog: _openArticle,
                        onTapBlogChannel: _openBlogChannel,
                        onTapCategory: _openCategory,
                        onTapChannel: _openChannel,
                        onTapVerifiedBook: _openVerifiedBook,
                        onTapBlogSource: _openBlogSource,
                      )),
                    ],
                  ),
                );
              }

              // Once Shorts run out, promote the remaining right-column
              // content to the full available width instead of leaving a
              // visually empty left column.
              if (i < pairCount + rightTailCount) {
                return rightCard(_right[i - pairCount + pairCount]);
              }

              // If Shorts are the longer result set, keep their remaining
              // cards aligned on the left rather than changing their order.
              final shortIndex = i - pairCount - rightTailCount + pairCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ShortCard(
                        item: _left[shortIndex],
                        onTap: () => _openShort(shortIndex),
                      ),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Search bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor(context), width: 0.5),
        ),
        child: TextField(
          controller:    controller,
          autofocus:     true,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(color: AppTheme.textColor(context), fontSize: 14),
          decoration: InputDecoration(
            hintText:    'Search videos, shorts, blogs, books, channels, categories…',
            hintStyle:   TextStyle(color: AppTheme.textMuted(context), fontSize: 14),
            prefixIcon:  Icon(Icons.search_rounded,
                              color: AppTheme.textMuted(context), size: 20),
            border:      InputBorder.none,
            isDense:     true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }
}

// ── Column header ───────────────────────────────────────────────────────────

class _ColHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ColHeader(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted(context)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted(context),
                letterSpacing: 0.3),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Left card — Short (9:16 portrait) ──────────────────────────────────────

class _ShortCard extends StatelessWidget {
  final _SearchItem item;
  final VoidCallback onTap;
  const _ShortCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v  = item.video!;
    final ch = ChannelData.byId[v.channelId] ?? ChannelData.fallback;
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail
                VideoThumbnailImage(
                  video: v,
                  fit: BoxFit.cover,
                  memCacheWidth: 360,
                  memCacheHeight: 640,
                ),
                // Gradient
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                      stops: [0.45, 1.0],
                    ),
                  ),
                ),
                // Channel accent top bar
                Positioned(top: 0, left: 0, right: 0,
                    child: Container(height: 3, color: ch.accentColor)),
                // Play icon
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: Colors.black45, shape: BoxShape.circle),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ),
                // Bottom info
                Positioned(
                  bottom: 8, left: 8, right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(v.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                          )),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                              color: ch.accentColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(ch.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 9.5,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Right card — Video / Blog / Book ───────────────────────────────────────

class _ContentCard extends StatelessWidget {
  final _SearchItem                  item;
  final bool                         saved;
  final VoidCallback                 onSave;
  final void Function(Video)         onTapVideo;
  final void Function(Video)         onTapBook;
  final void Function(BlogArticle)   onTapBlog;
  final void Function(String) onTapBlogChannel;
  final void Function(ResourceCategory) onTapCategory;
  final void Function(Channel) onTapChannel;
  final void Function(VerifiedBook) onTapVerifiedBook;
  final void Function(Map<String, String>) onTapBlogSource;

  const _ContentCard({
    required this.item,
    required this.saved,
    required this.onSave,
    required this.onTapVideo,
    required this.onTapBook,
    required this.onTapBlog,
    required this.onTapBlogChannel,
    required this.onTapCategory,
    required this.onTapChannel,
    required this.onTapVerifiedBook,
    required this.onTapBlogSource,
  });

  String get _badge => switch (item.kind) {
    _ResultKind.short => 'Short',
    _ResultKind.video => 'Video',
    _ResultKind.blog  => 'Blog',
    _ResultKind.book  => 'Book',
    _ResultKind.category => 'Category',
    _ResultKind.channel => 'Channel',
    _ResultKind.blogSource => 'Blog source',
  };

  void _onTap() {
    switch (item.kind) {
      case _ResultKind.video:
        onTapVideo(item.video!);
      case _ResultKind.book:
        if (item.verifiedBook != null) {
          onTapVerifiedBook(item.verifiedBook!);
        } else {
          onTapBook(item.video!);
        }
      case _ResultKind.blog:
        onTapBlog(item.article!);
      case _ResultKind.category:
        onTapCategory(item.category!);
      case _ResultKind.channel:
        onTapChannel(item.channel!);
      case _ResultKind.blogSource:
        onTapBlogSource(item.blogSource!);
      case _ResultKind.short:
        break; // Shorts are in the left column; this shouldn't appear here.
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:        AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(
                color: AppTheme.dividerColor(context), width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    _buildThumb(context),
                    if (item.canBookmark)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _SearchBookmarkButton(
                          saved: saved,
                          onPressed: onSave,
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BadgePill(label: _badge, kind: item.kind),
                      const SizedBox(height: 5),
                      Text(_title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700, height: 1.3)),
                      const SizedBox(height: 4),
                      _buildSourceMeta(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _title => item.video?.title ??
      item.article?.title ??
      item.category?.name ??
      item.channel?.name ??
      item.blogSource?['name'] ??
      item.verifiedBook?.title ?? '';

  Widget _buildSourceMeta(BuildContext context) {
    if (item.article != null) {
      return _SearchSourceLink(
        label: item.article!.sourceName,
        onTap: () => onTapBlogChannel(item.article!.sourceName),
      );
    }
    if (item.video != null) {
      final channel =
          ChannelData.byId[item.video!.channelId] ?? ChannelData.fallback;
      if (item.kind == _ResultKind.book) {
        return Text(item.video!.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted(context)));
      }
      return _SearchSourceLink(
        label: channel.name,
        onTap: () => onTapChannel(channel),
      );
    }
    if (item.verifiedBook != null) {
      return Text(item.verifiedBook!.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textMuted(context)));
    }
    if (item.category != null) {
      return Text('${item.category!.section.label} · FinReels research',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textMuted(context)));
    }
    if (item.channel != null) {
      return _SearchSourceLink(
        label: item.channel!.name,
        onTap: () => onTapChannel(item.channel!),
      );
    }
    if (item.blogSource != null) {
      return _SearchSourceLink(
        label: item.blogSource!['name'] ?? 'Verified blog source',
        onTap: () => onTapBlogSource(item.blogSource!),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildThumb(BuildContext context) {
    if (item.kind == _ResultKind.book) {
      final book = item.verifiedBook;
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: book != null
            ? BookCoverImage(
                url: book.coverUrl ?? '',
                fallbackUrls: book.coverCandidates,
              )
            : BookCoverImage(
                url: item.video!.thumbnailUrl,
                fallbackUrls: item.video!.thumbnailFallbackUrls,
              ),
      );
    }
    if (item.category != null || item.channel != null || item.blogSource != null) {
      final icon = item.category != null
          ? Icons.category_outlined
          : item.channel != null
              ? Icons.play_circle_outline_rounded
              : Icons.article_outlined;
      final color = item.category != null
          ? AppTheme.gold
          : item.channel?.accentColor ?? const Color(0xFF065F46);
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: AppTheme.surfaceElevated(context),
          child: Center(
            child: Icon(icon, size: 42, color: color.withValues(alpha: 0.85)),
          ),
        ),
      );
    }
    final ch = item.video != null
        ? (ChannelData.byId[item.video!.channelId] ?? ChannelData.fallback)
        : ChannelData.fallback;
    final image = item.article != null
        ? BlogThumbnailImage(
            url: item.article!.thumbnailUrl,
            fallbackUrls: item.article!.thumbnailFallbackUrls,
          )
        : item.video != null
            ? VideoThumbnailImage(
                video: item.video!,
                fit: BoxFit.cover,
                memCacheWidth: 360,
                memCacheHeight: 203,
              )
            : ColoredBox(color: AppTheme.surfaceElevated(context));
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned(top: 0, left: 0, right: 0,
              child: Container(height: 3, color: ch.accentColor)),
          if (item.kind == _ResultKind.video)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.black45, shape: BoxShape.circle),
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          if (item.kind == _ResultKind.blog)
            Positioned(
              bottom: 4, right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.article_outlined,
                    color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchSourceLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SearchSourceLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_new_rounded,
                  size: 14, color: AppTheme.gold),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          decorationThickness: 1.2,
                        )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge pill ──────────────────────────────────────────────────────────────

class _BadgePill extends StatelessWidget {
  final String      label;
  final _ResultKind kind;
  const _BadgePill({required this.label, required this.kind});

  Color get _bg => switch (kind) {
    _ResultKind.short => const Color(0xFF7C3AED),
    _ResultKind.video => const Color(0xFF1D4ED8),
    _ResultKind.blog  => const Color(0xFF065F46),
    _ResultKind.book  => const Color(0xFF92400E),
    _ResultKind.category => AppTheme.gold,
    _ResultKind.channel => const Color(0xFF2563EB),
    _ResultKind.blogSource => const Color(0xFF0F766E),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        _bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: _bg.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(
              color:       _bg,
              fontSize:    9,
              fontWeight:  FontWeight.w800,
              letterSpacing: 0.8)),
    );
  }
}

class _SearchProgress extends StatelessWidget {
  final String query;
  final bool waitingForIndex;
  final int visibleCount;

  const _SearchProgress({
    required this.query,
    required this.waitingForIndex,
    required this.visibleCount,
  });

  @override
  Widget build(BuildContext context) {
    final fill = FinreelsShimmer.fillColor(context);
    return FinreelsShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  waitingForIndex
                      ? 'Preparing matches for "$query"…'
                      : 'Loading more matches…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted(context),
                      ),
                ),
              ),
              Text(
                '$visibleCount results so far',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted(context),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(
            minHeight: 3,
            color: AppTheme.gold,
            backgroundColor: Color(0x33219E8A),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < 4; i++) ...[
            Container(
              height: 86,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            if (i < 3) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ── Empty prompt ────────────────────────────────────────────────────────────

class _EmptyPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                size: 56, color: AppTheme.textMuted(context)),
            const SizedBox(height: 16),
            Text('Search your content',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Type a keyword — "how to price", "solar install", '
              '"fashion business" — to find videos, shorts, blogs, books, channels, and categories.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted(context), height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ── No results ──────────────────────────────────────────────────────────────

class _NoResults extends StatelessWidget {
  final String query;
  final bool stillFetchingBlogs;
  const _NoResults({required this.query, this.stillFetchingBlogs = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56, color: AppTheme.textMuted(context)),
            const SizedBox(height: 16),
            Text(
              stillFetchingBlogs
                  ? 'No videos found for "$query"'
                  : 'No results for "$query"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (stillFetchingBlogs) ...[
              const SizedBox(height: 4),
              const CircularProgressIndicator(
                  color: AppTheme.gold, strokeWidth: 2),
              const SizedBox(height: 10),
              Text('Still searching blogs…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted(context))),
            ] else
              Text(
                'Try shorter or different keywords — for example '
                '"pricing", "solar", or "tailoring".',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted(context), height: 1.6),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchBookmarkButton extends StatelessWidget {
  final bool saved;
  final VoidCallback onPressed;

  const _SearchBookmarkButton({required this.saved, required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: saved ? 'Remove bookmark' : 'Bookmark',
          onPressed: onPressed,
          icon: Icon(
            saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: Colors.white,
            size: 20,
          ),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      );
}
