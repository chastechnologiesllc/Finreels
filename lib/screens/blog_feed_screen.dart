import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/feed_provider.dart';
import '../services/ad_service.dart';
import '../services/blog_rss_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/blog_thumbnail_image.dart';
import '../widgets/rumuo_shimmer.dart';
import 'blog_channel_screen.dart';
import 'blog_reader_screen.dart';

/// Fix 4 — Blogs Tab Design
/// Each article is rendered as a full-width card matching the video feed:
/// 16:9 cover image at top (with branded gradient fallback when no image),
/// then source badge + date, then headline, then excerpt.
/// No ListTile, no raw text rows, no horizontal thumbnail layout.
class BlogFeedScreen extends StatefulWidget {
  const BlogFeedScreen({super.key});

  @override
  State<BlogFeedScreen> createState() => _BlogFeedScreenState();
}

class _BlogFeedScreenState extends State<BlogFeedScreen> {
  // Immutable snapshot — never appended to mid-render (Fix 2).
  List<BlogArticle> _articles = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    // First paint comes from the in-memory cache or bundled snapshot. This
    // keeps category-relevant content visible while live RSS is in flight.
    if (!force && _articles.isEmpty) {
      try {
        final seed = await BlogRssService.instance.fetchLocalSeed();
        if (mounted && seed.isNotEmpty) {
          setState(() => _articles = List.unmodifiable(seed));
        }
      } on Object catch (_) {
        // Live fetch below remains the source of truth if the seed is absent.
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final articles =
          await BlogRssService.instance.fetchAll(forceRefresh: force);
      if (mounted) {
        setState(() {
          final nextArticles = articles.isEmpty ? _articles : articles;
          _articles = List.unmodifiable(nextArticles); // atomic replace
          // Soft failure: preserve a useful local seed when all live feeds are
          // unavailable instead of replacing a populated list with nothing.
          if (nextArticles.isEmpty) {
            _error = 'Could not load articles.';
          }
        });
      }
    } on Exception catch (_) {
      if (mounted && _articles.isEmpty) {
        setState(() => _error = 'Could not load articles.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedProvider>();
    // Shimmer shown only on the very first load (no cached articles yet).
    if (_loading && _articles.isEmpty) return _buildShimmer(context);

    // ── Empty / error state (after shimmer) ───────────────────────────────
    // Covers both explicit errors and "loaded but zero articles" (silent
    // RSS failure / rate-limit). AlwaysScrollableScrollPhysics + Retry
    // button so the user can recover without leaving the tab.
    if (!_loading && _articles.isEmpty) {
      final message = _error ?? 'No articles available right now.';
      final subtitle = _error != null
          ? 'Pull down to try again, or tap Retry below.'
          : 'Pull down or tap Retry to reload the feeds.';
      return RefreshIndicator(
        color: AppTheme.gold,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 56, color: AppTheme.textMuted(context)),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted(context),
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.gold,
                          side: BorderSide(
                              color: AppTheme.gold.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: () => _load(force: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Loaded / refreshing state ─────────────────────────────────────────
    return RefreshIndicator(
      color: AppTheme.gold,
      onRefresh: () => _load(force: true),
      child: ListView.separated(
        // ClampingScrollPhysics prevents bounce-induced scroll jumps while
        // still forwarding overscroll notifications to RefreshIndicator.
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: _articles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final article = _articles[i];
          return Column(
            key: ValueKey(article.url),
            mainAxisSize: MainAxisSize.min,
            children: [
              // Banner after every 3rd article (items 3, 6, 9 …)
              if (i > 0 && i % 3 == 0)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: const LabelledBannerAd(placement: InlineBannerPlacement.large),
                ),
              RepaintBoundary(
                child: _BlogCard(
                  article: article,
                  saved: provider.isBlogSaved(article.url),
                  onSave: () => provider.toggleBlogSaved(article),
                  onSourceTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlogChannelScreen(
                          sourceName: article.sourceName,
                          sourceUrl: article.sourceUrl ??
                              BlogRssService.catalogUrlForSource(
                                article.sourceName,
                              ),
                          initialArticles: _articles
                              .where((candidate) =>
                                  BlogRssService.sameSource(article, candidate))
                              .toList(growable: false),
                        ),
                      ),
                    );
                  },
                  onTap: () {
                    // Interstitial on tap 4, 8, 12 … (blog-specific counter)
                    unawaited(AdService.instance.onBlogTapped());
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlogReaderScreen(
                          url:          article.url,
                          title:        article.title,
                          sourceName:   article.sourceName,
                          thumbnailUrl: article.thumbnailUrl,
                          excerpt:      article.excerpt.isNotEmpty
                              ? article.excerpt
                              : null,
                          publishedAt:  article.publishedAt,
                          categoryId:   article.categoryId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Shimmer that matches the 16:9 blog card shape exactly.
  Widget _buildShimmer(BuildContext context) {
    final skeleton = RumuoShimmer.fillColor(context);

    return RumuoShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, __) =>
            _BlogShimmerSkeleton(placeholderColor: skeleton),
      ),
    );
  }
}

// ── Skeleton ─────────────────────────────────────────────────────────────────

class _BlogShimmerSkeleton extends StatelessWidget {
  final Color placeholderColor;

  const _BlogShimmerSkeleton({required this.placeholderColor});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: placeholderColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(6)),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 16,
                  width: MediaQuery.of(context).size.width * 0.6,
                  decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Blog Card — 16:9 cover + text body ───────────────────────────────────────

class _BlogCard extends StatelessWidget {
  final BlogArticle article;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onTap;
  final VoidCallback onSourceTap;

  const _BlogCard({
    required this.article,
    required this.saved,
    required this.onSave,
    required this.onTap,
    required this.onSourceTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.dividerColor(context), width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 16:9 Cover Image ─────────────────────────────────────────
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
                    child: _BlogBookmarkButton(saved: saved, onPressed: onSave),
                  ),
                ],
              ),
            ),

            // Source badge + gold accent strip
            Container(height: 3, color: AppTheme.gold),

            // ── Text Body ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prominent, clearly clickable blog channel/source name.
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: onSourceTap,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.rss_feed_rounded,
                                    size: 17, color: AppTheme.gold),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    article.sourceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.gold,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    size: 12, color: AppTheme.gold),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeago.format(article.publishedAt),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Headline
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700, height: 1.35),
                  ),
                  if (article.excerpt.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      article.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _BlogBookmarkButton extends StatelessWidget {
  final bool saved;
  final VoidCallback onPressed;

  const _BlogBookmarkButton({required this.saved, required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: saved ? 'Remove bookmark' : 'Bookmark blog',
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
