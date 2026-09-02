import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/feed_provider.dart';
import '../services/ad_service.dart';
import '../services/blog_rss_service.dart';
import '../theme/app_theme.dart';
import '../widgets/blog_thumbnail_image.dart';
import '../widgets/rumuo_shimmer.dart';
import 'blog_reader_screen.dart';

/// A dedicated, video-channel-style page for one blog/RSS source.
class BlogChannelScreen extends StatefulWidget {
  final String sourceName;
  final String? sourceUrl;
  final List<BlogArticle> initialArticles;

  const BlogChannelScreen({
    required this.sourceName,
    this.sourceUrl,
    this.initialArticles = const [],
    super.key,
  });

  @override
  State<BlogChannelScreen> createState() => _BlogChannelScreenState();
}

class _BlogChannelScreenState extends State<BlogChannelScreen> {
  List<BlogArticle> _articles = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _articles = List.unmodifiable(widget.initialArticles);
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final articles = await BlogRssService.instance.fetchForSource(
        widget.sourceName,
        sourceUrl: widget.sourceUrl,
      );
      if (!mounted) return;
      setState(() {
        // Keep visible seed articles when a live refresh is empty or partial.
        // This prevents a source page from going blank after a successful tap.
        final refreshed = BlogRssService.mergeArticles(
          articles,
          widget.initialArticles,
        );
        final nextArticles = refreshed.isNotEmpty ? refreshed : _articles;
        _articles = List.unmodifiable(nextArticles);
        if (nextArticles.isEmpty) {
          _error = 'No articles found for this source.';
        }
      });
    } on Object catch (_) {
      if (mounted && _articles.isEmpty) {
        setState(() => _error = 'Could not load this blog source.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openArticle(BlogArticle article) {
    unawaited(AdService.instance.onBlogTapped());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlogReaderScreen(
          url: article.url,
          title: article.title,
          sourceName: article.sourceName,
          thumbnailUrl: article.thumbnailUrl,
          excerpt: article.excerpt.isNotEmpty ? article.excerpt : null,
          publishedAt: article.publishedAt,
          categoryId: article.categoryId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = FeedProvider.instance;
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor(context),
        titleSpacing: 16,
        title: Text(
          widget.sourceName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh source',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: provider == null
          ? _buildBody(context, null)
          : ListenableBuilder(
              listenable: provider,
              builder: (context, _) => _buildBody(context, provider),
            ),
    );
  }

  Widget _buildBody(BuildContext context, FeedProvider? provider) {
    if (_loading && _articles.isEmpty) return _buildShimmer(context);
    return RefreshIndicator(
      color: AppTheme.gold,
      onRefresh: _load,
      child: _articles.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: _articles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final article = _articles[index];
                return _BlogSourceArticleCard(
                  article: article,
                  saved: provider?.isBlogSaved(article.url) ?? false,
                  onSave: provider == null
                      ? () {}
                      : () => provider.toggleBlogSaved(article),
                  onTap: () => _openArticle(article),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(32, 100, 32, 120),
      children: [
        Icon(Icons.rss_feed_rounded, size: 54, color: AppTheme.gold),
        const SizedBox(height: 16),
        Text(
          _error ?? 'No articles available right now.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Pull down or tap refresh to try again.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted(context),
              ),
        ),
      ],
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final fill = RumuoShimmer.fillColor(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RumuoShimmer(
            child: CircleAvatar(
              radius: 34,
              backgroundColor: fill,
              child: const Icon(Icons.rss_feed_rounded, size: 30),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Loading ${widget.sourceName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Preparing the latest articles…',
            style: TextStyle(color: AppTheme.textMuted(context)),
          ),
        ],
      ),
    );
  }
}

class _BlogSourceArticleCard extends StatelessWidget {
  final BlogArticle article;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onTap;

  const _BlogSourceArticleCard({
    required this.article,
    required this.saved,
    required this.onSave,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceColor(context),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BlogThumbnailImage(
                    url: article.thumbnailUrl,
                    fallbackUrls: article.thumbnailFallbackUrls,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: saved ? 'Remove bookmark' : 'Bookmark blog',
                        onPressed: onSave,
                        icon: Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 3, color: AppTheme.gold),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700, height: 1.35),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${article.sourceName} · ${timeago.format(article.publishedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: AppTheme.textMuted(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
