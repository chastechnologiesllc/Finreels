import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../data/channel_data.dart';
import '../models/video.dart';
import '../providers/feed_provider.dart';
import '../services/ad_service.dart';
import '../services/blog_rss_service.dart';
import '../theme/app_theme.dart';
import '../widgets/book_cover_image.dart';
import '../widgets/no_flash_page_route.dart';
import 'blog_reader_screen.dart';
import 'book_detail_screen.dart';
import 'shorts_player_screen.dart';
import 'video_player_screen.dart';

// ── Unified search result ───────────────────────────────────────────────────

enum _ResultKind { short, video, blog, book }

class _SearchItem {
  final _ResultKind kind;
  final Video?       video;
  final BlogArticle? article;
  final double       score;

  const _SearchItem.video(this.video, this.score)
      : kind    = _ResultKind.video,
        article = null;
  const _SearchItem.short(this.video, this.score)
      : kind    = _ResultKind.short,
        article = null;
  const _SearchItem.blog(this.article, this.score)
      : kind    = _ResultKind.blog,
        video   = null;
  const _SearchItem.book(this.video, this.score)
      : kind    = _ResultKind.book,
        article = null;

  bool get isShort => kind == _ResultKind.short;

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
    final newState = _fp.state;
    if (_lastFeedState == FeedState.loading &&
        newState == FeedState.loaded &&
        _query.isNotEmpty) {
      _search(_query);
    }
    _lastFeedState = newState;
  }

  void _onInput() {
    _debounce?.cancel();
    final q = _ctrl.text.trim();
    if (q == _query) return;
    if (q.length < 2) {
      setState(() { _query = q; _left = []; _right = []; _loading = false; });
      return;
    }
    // Debounce: wait 300 ms after the user stops typing before searching.
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
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

  static double _score(String rawQuery, String title, String desc, String source) {
    final q    = rawQuery.toLowerCase().trim();
    final tl   = title.toLowerCase();
    final dl   = desc.toLowerCase();
    final sl   = source.toLowerCase();
    double s   = 0;

    // Pass 1: full-phrase match in title (highest signal — user typed a title)
    if (q.length >= 3 && tl.contains(q)) s += 5.0;

    final words = q.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();

    for (final word in words) {
      // Pass 2–4: individual word match
      if (tl.contains(word)) s += 2.0;
      if (dl.contains(word)) s += 1.0;
      if (sl.contains(word)) s += 0.5;

      // Pass 5: stem match (strip common suffixes) — helps "pricing" match
      // "price", "sewing" match "sew", "tailoring" match "tailor", etc.
      for (final stem in _stems(word)) {
        if (stem.length < 3) continue;
        if (tl.contains(stem) && !tl.contains(word)) s += 1.0;
        if (dl.contains(stem) && !dl.contains(word)) s += 0.5;
      }
    }
    return s;
  }

  /// Returns a small set of common stems for [word] so searching "sewing"
  /// also matches documents that only contain "sew", "pricing" matches
  /// "price", etc. This is intentionally minimal — not a full stemmer, just
  /// the most useful suffixes for the FinReels topic domain.
  static List<String> _stems(String word) {
    if (word.length < 4) return [];
    return [
      if (word.endsWith('ing')) word.substring(0, word.length - 3),
      if (word.endsWith('ing')) '${word.substring(0, word.length - 3)}e',
      if (word.endsWith('tion')) word.substring(0, word.length - 4),
      if (word.endsWith('ness')) word.substring(0, word.length - 4),
      if (word.endsWith('ment')) word.substring(0, word.length - 4),
      if (word.endsWith('er')) word.substring(0, word.length - 2),
      if (word.endsWith('ors')) word.substring(0, word.length - 3),
      if (word.endsWith('ers')) word.substring(0, word.length - 3),
      if (word.endsWith('ed')) word.substring(0, word.length - 2),
      if (word.endsWith('ly')) word.substring(0, word.length - 2),
      if (word.endsWith('al')) word.substring(0, word.length - 2),
      if (word.endsWith('ies')) '${word.substring(0, word.length - 3)}y',
      if (word.endsWith('s') && !word.endsWith('ss')) word.substring(0, word.length - 1),
    ];
  }

  // ── Search ──────────────────────────────────────────────────────────────

  Future<void> _search(String q) async {
    if (!mounted) return;
    setState(() { _query = q; _loading = true; _fetchingBlogs = false; });

    // ── Phase 1: in-memory (INSTANT) ──────────────────────────────────────
    final allVids  = _fp.allFeedVideos;
    final newLeft  = <_SearchItem>[];
    final newRight = <_SearchItem>[];

    for (final v in allVids) {
      final ch    = ChannelData.byId[v.channelId] ?? ChannelData.fallback;
      final score = _score(q, v.title, v.description, ch.name);
      if (score <= 0) continue;
      if (v.isShort) {
        newLeft.add(_SearchItem.short(v, score));
      } else {
        newRight.add(_SearchItem.video(v, score));
      }
    }

    for (final b in _fp.allBooksForSearch) {
      final score = _score(q, b.title, b.description, b.channelName);
      if (score > 0) newRight.add(_SearchItem.book(b, score));
    }

    int cmp(_SearchItem a, _SearchItem b) {
      final sc = b.score.compareTo(a.score);
      return sc != 0 ? sc : b.date.compareTo(a.date);
    }
    newLeft.sort(cmp);
    newRight.sort(cmp);

    if (!mounted) return;
    // Show video/book results immediately — never wait for blogs.
    setState(() {
      _left         = newLeft;
      _right        = newRight;
      _loading      = false;
      _fetchingBlogs = true; // Phase 2 starting
    });

    // ── Phase 2: blogs (background, 5-second cap) ─────────────────────────
    try {
      final articles = await BlogRssService.instance
          .fetchAll()
          .timeout(const Duration(seconds: 5));

      final blogItems = <_SearchItem>[];
      for (final a in articles) {
        final score = _score(q, a.title, a.excerpt, a.sourceName);
        if (score > 0) blogItems.add(_SearchItem.blog(a, score));
      }
      blogItems.sort(cmp);

      if (!mounted || _query != q) return;
      if (blogItems.isNotEmpty) {
        final merged = [..._right, ...blogItems]..sort(cmp);
        setState(() { _right = merged; _fetchingBlogs = false; });
      } else {
        setState(() => _fetchingBlogs = false);
      }
    } on TimeoutException {
      debugPrint('[ContentSearch] blog fetch timed out for: $q');
      if (mounted) setState(() => _fetchingBlogs = false);
    } on Exception catch (e) {
      debugPrint('[ContentSearch] blog fetch error: $e');
      if (mounted) setState(() => _fetchingBlogs = false);
    }
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

  void _openArticle(BlogArticle a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlogReaderScreen(
          url:        a.url,
          title:      a.title,
          categoryId: a.categoryId,
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

  Widget _buildBody() {
    if (_query.isEmpty) return _EmptyPrompt();

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2.5),
      );
    }

    final feedLoading = _fp.state == FeedState.loading ||
        _fp.state == FeedState.idle;

    // If in-memory results are empty AND the feed is still loading, show a
    // loading state rather than "no results" — results will appear as soon
    // as FeedProvider finishes (_onFeedChanged triggers a re-search).
    if (_left.isEmpty && _right.isEmpty && feedLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text('Loading your content…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted(context))),
          ],
        ),
      );
    }

    if (_left.isEmpty && _right.isEmpty) {
      return _NoResults(query: _query, stillFetchingBlogs: _fetchingBlogs);
    }

    final count = _left.length > _right.length ? _left.length : _right.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Text(
                '${_left.length + _right.length} results for "$_query"',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted(context)),
              ),
              if (_fetchingBlogs) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(
                      color: AppTheme.gold, strokeWidth: 1.5),
                ),
                const SizedBox(width: 4),
                Text('searching blogs…',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMuted(context))),
              ],
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _ColHeader('Shorts', Icons.play_circle_outline_rounded)),
              SizedBox(width: 8),
              Expanded(child: _ColHeader('Videos • Blogs • Books', Icons.grid_view_rounded)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: count,
            itemBuilder: (ctx, i) {
              final left  = i < _left.length  ? _left[i]  : null;
              final right = i < _right.length ? _right[i] : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: left != null
                            ? _ShortCard(item: left, onTap: () => _openShort(i))
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: right != null
                            ? _ContentCard(
                                item:       right,
                                onTapVideo: _openVideo,
                                onTapBook:  _openBook,
                                onTapBlog:  _openArticle,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
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
            hintText:    'Search videos, shorts, blogs, books…',
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
  const _ShortCard({required this.item, required this.onTap});

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
                CachedNetworkImage(
                  imageUrl:     v.thumbnailMq,
                  fit:          BoxFit.cover,
                  memCacheWidth: 360,
                  memCacheHeight: 640,
                  placeholder:  (_, __) => Shimmer.fromColors(
                    baseColor:      const Color(0xFF1E1E1E),
                    highlightColor: const Color(0xFF2C2C2C),
                    child: const ColoredBox(color: Colors.white),
                  ),
                  errorWidget:  (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF1E1E1E)),
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
  final void Function(Video)         onTapVideo;
  final void Function(Video)         onTapBook;
  final void Function(BlogArticle)   onTapBlog;

  const _ContentCard({
    required this.item,
    required this.onTapVideo,
    required this.onTapBook,
    required this.onTapBlog,
  });

  String get _badge => switch (item.kind) {
    _ResultKind.short => 'Short',
    _ResultKind.video => 'Video',
    _ResultKind.blog  => 'Blog',
    _ResultKind.book  => 'Book',
  };

  void _onTap() {
    switch (item.kind) {
      case _ResultKind.video:
        onTapVideo(item.video!);
      case _ResultKind.book:
        onTapBook(item.video!);
      case _ResultKind.blog:
        onTapBlog(item.article!);
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
                _buildThumb(context),
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
                      Text(_sourceLine(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textMuted(context))),
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

  String get _title => item.video?.title ?? item.article?.title ?? '';

  String _sourceLine(BuildContext context) {
    if (item.article != null) {
      return '${item.article!.sourceName} · ${timeago.format(item.article!.publishedAt)}';
    }
    if (item.video != null) {
      final ch = ChannelData.byId[item.video!.channelId] ?? ChannelData.fallback;
      if (item.kind == _ResultKind.book) return item.video!.description;
      return '${ch.name} · ${timeago.format(item.video!.publishedAt)}';
    }
    return '';
  }

  Widget _buildThumb(BuildContext context) {
    if (item.kind == _ResultKind.book) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: BookCoverImage(url: item.video!.thumbnailUrl),
      );
    }
    final url = item.video?.thumbnailMq ?? item.article?.thumbnailUrl ?? '';
    final ch  = item.video != null
        ? (ChannelData.byId[item.video!.channelId] ?? ChannelData.fallback)
        : ChannelData.fallback;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          url.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl:     url,
                  fit:          BoxFit.cover,
                  memCacheWidth: 360,
                  memCacheHeight: 203,
                  placeholder:  (_, __) => Shimmer.fromColors(
                    baseColor:      const Color(0xFF1E1E1E),
                    highlightColor: const Color(0xFF2C2C2C),
                    child: const ColoredBox(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) =>
                      ColoredBox(color: AppTheme.surfaceElevated(context)),
                )
              : ColoredBox(color: AppTheme.surfaceElevated(context)),
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
              '"fashion business" — to find videos, shorts, blog articles, and books.',
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
