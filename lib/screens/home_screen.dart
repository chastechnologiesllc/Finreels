import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../data/channel_data.dart';
import '../models/feed_tab.dart';
import '../models/video.dart';
import '../providers/feed_provider.dart';
import '../services/ad_service.dart';
import '../services/notification_store.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/book_cover_image.dart';
import '../widgets/inline_video_card.dart';
import '../widgets/no_flash_page_route.dart';
import '../widgets/shimmer_loader.dart';
import 'blog_feed_screen.dart';
import 'book_detail_screen.dart';
import 'content_search_screen.dart';
import 'notifications_screen.dart';
import 'shorts_player_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AppHeader(),
            _FeedTabBar(),
            const Expanded(child: _FeedBody()),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────
class _AppHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: AppTheme.gold, borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Text('FinReels',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.search_rounded, color: AppTheme.textMuted(context)),
            onPressed: () {
              // Read FeedProvider HERE — this context is inside MultiProvider.
              // ContentSearchScreen is pushed as a route (outside MultiProvider),
              // so it cannot call context.read itself. Passing it explicitly is
              // the correct pattern for pushed routes in this architecture.
              final fp = context.read<FeedProvider>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ContentSearchScreen(feedProvider: fp),
                ),
              );
            },
          ),
          // Badge-wrapped bell — count driven by NotificationStore.unreadCount.
          // ValueListenableBuilder rebuilds ONLY this subtree on count changes,
          // leaving the rest of the header (search icon, logo, tabs) untouched.
          ValueListenableBuilder<int>(
            valueListenable: NotificationStore.instance.unreadCount,
            builder: (context, count, _) {
              return Badge(
                isLabelVisible: count > 0,
                label: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: IconButton(
                  icon: Icon(
                    count > 0
                        ? Icons.notifications_rounded
                        : Icons.notifications_outlined,
                    color: count > 0
                        ? AppTheme.gold
                        : AppTheme.textMuted(context),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _FeedTabBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedProvider>();
    final active   = provider.activeTab;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: FeedTab.values.map((tab) {
          final isActive = tab == active;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => provider.setTab(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.gold : AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isActive ? AppTheme.gold : AppTheme.dividerColor(context),
                    ),
                  ),
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      color: isActive ? Colors.black : AppTheme.textSecondary(context),
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Feed body ──────────────────────────────────────────────────────────────────
class _FeedBody extends StatefulWidget {
  const _FeedBody();
  @override
  State<_FeedBody> createState() => _FeedBodyState();
}

class _FeedBodyState extends State<_FeedBody> {
  // Shared notifier — cards listen directly; no parent setState for play/pause
  final _activeVideoNotifier = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _activeVideoNotifier.dispose();
    super.dispose();
  }

  void _onTap(Video video) {
    if (video.channelId == 'verified_book') {
      _openVerifiedBook(video);
      return;
    }
    if (video.channelId == 'books') {
      unawaited(AdService.instance.onVideoTapped());
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => BookDetailScreen(book: video)));
      return;
    }
    unawaited(AdService.instance.onVideoTapped());
  }

  /// All verified (category-specific) books now open through BookDetailScreen,
  /// giving them the same landing page (cover, description, CTA) as the
  /// general free books. BookDetailScreen detects channelId == 'verified_book'
  /// via the freeSourceUrl field and routes to BlogReaderScreen internally
  /// when the user taps the read button.
  void _openVerifiedBook(Video book) {
    if ((book.freeSourceUrl ?? '').isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(book: book),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedProvider>();

    if (provider.activeTab == FeedTab.blogs) {
      return const BlogFeedScreen();
    }
    if (provider.activeTab == FeedTab.books) {
      return _BooksTab(onTap: _onTap);
    }
    if (provider.activeTab == FeedTab.shorts) {
      return _ShortsTab(provider: provider);
    }

    // Videos tab
    return switch (provider.state) {
      FeedState.idle || FeedState.loading when provider.feedVideos.isEmpty =>
        const ShimmerLoader(),
      FeedState.error => _ErrorView(
          message: provider.errorMessage ?? 'Something went wrong.',
          onRetry: () => provider.refresh(force: true)),
      _ => _buildVideoFeed(context, provider),
    };
  }

  Widget _buildVideoFeed(BuildContext context, FeedProvider provider) {
    final videos = provider.feedVideos;
    if (videos.isEmpty) {
      return Center(
          child: Text('No videos found.',
              style: Theme.of(context).textTheme.bodyMedium));
    }
    return RefreshIndicator(
      color: AppTheme.gold,
      onRefresh: () => provider.refresh(force: true),
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        // Bound how far beyond the viewport Flutter builds items.
        // Without this Flutter eagerly renders cards well off-screen,
        // triggering VisibilityDetector callbacks and pre-warming WebViews
        // for cards the user may never reach — causing scroll jank on
        // lower-end devices. 350 ≈ 1 card height below the fold: enough
        // for smooth scrolling without building the whole list at once.
        cacheExtent: 350,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: videos.length,
        itemBuilder: (context, i) {
          final video    = videos[i];
          final channel  = ChannelData.byId[video.channelId] ?? ChannelData.fallback;
          final isAdSlot = i > 0 && (i + 1) % 3 == 0;
          return Column(
            key: ValueKey('v_${video.id}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAdSlot)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: LabelledBannerAd(),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InlineVideoCard(
                  key: ValueKey(video.id),
                  video: video,
                  channel: channel,
                  saved: provider.isVideoSaved(video.id),
                  activeVideoNotifier: _activeVideoNotifier,
                  onSave: () => provider.toggleSaved(video),
                  onShare: () =>
                      Share.share('${video.title}\n${video.watchUrl}'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Shorts tab ─────────────────────────────────────────────────────────────────
class _ShortsTab extends StatelessWidget {
  final FeedProvider provider;
  const _ShortsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.state == FeedState.loading && provider.feedVideos.isEmpty) {
      return const ShimmerLoader(variant: ShimmerVariant.grid, count: 6);
    }
    final shorts = provider.feedVideos;
    if (shorts.isEmpty) {
      return Center(
          child: Text('No shorts found.',
              style: Theme.of(context).textTheme.bodyMedium));
    }
    return RefreshIndicator(
      color: AppTheme.gold,
      onRefresh: () => provider.refresh(force: true),
      child: GridView.builder(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 9 / 16,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: shorts.length,
        itemBuilder: (context, i) {
          final video   = shorts[i];
          final channel = ChannelData.byId[video.channelId] ?? ChannelData.fallback;
          return RepaintBoundary(
            key: ValueKey(video.id),
            child: GestureDetector(
              onTap: () {
                // Interstitial on tap 4, 8, 12 …
                unawaited(AdService.instance.onShortTapped());
                Navigator.push(
                  context,
                  NoFlashPageRoute(
                    builder: (_) => ShortsPlayerScreen(
                        shorts: shorts,
                        initialIndex: i),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbnailMq,
                    fit: BoxFit.cover,
                    memCacheWidth: 360,
                    memCacheHeight: 640,
                    placeholder: (_, __) => Shimmer.fromColors(
                      baseColor: const Color(0xFF1E1E1E),
                      highlightColor: const Color(0xFF2C2C2C),
                      child: const ColoredBox(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF1E1E1E)),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                        stops: [0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned(top: 0, left: 0, right: 0,
                      child: Container(height: 3, color: channel.accentColor)),
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
                  Positioned(
                    bottom: 8, left: 8, right: 8,
                    child: Text(video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                        )),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Books tab ──────────────────────────────────────────────────────────────────
class _BooksTab extends StatelessWidget {
  final void Function(Video) onTap;
  const _BooksTab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final books = context.read<FeedProvider>().feedVideos;
    final adsRemoved = context.watch<AdService>().adsRemoved;
    if (books.isEmpty) {
      return Center(
          child: Text('No books found.',
              style: Theme.of(context).textTheme.bodyMedium));
    }
    // Build a flat list: book card rows + ad rows (every 3 books).
    // Ads live as independent rows — never inside a card widget.
    final items = <({Video? book, bool isAd})>[];
    for (var i = 0; i < books.length; i++) {
      items.add((book: books[i], isAd: false));
      if (i > 0 && (i + 1) % 3 == 0 && !adsRemoved) {
        items.add((book: null, isAd: true));
      }
    }

    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];

        // ── Ad row — full width, own space ──────────────────────────────
        if (item.isAd) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LabelledBannerAd(),
          );
        }

        // ── Book card ────────────────────────────────────────────────────
        final book = item.book!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RepaintBoundary(
            key: ValueKey(book.id),
            child: GestureDetector(
              onTap: () => onTap(book),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.dividerColor(context), width: 0.5),
                ),
                child: Row(
                  children: [
                    BookCoverImage(
                      url: book.thumbnailUrl,
                      width: 90,
                      height: 120,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(13),
                        bottomLeft: Radius.circular(13),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('📚 FREE BOOK',
                                  style: TextStyle(
                                    color: AppTheme.gold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  )),
                            ),
                            const SizedBox(height: 8),
                            Text(book.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.35),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text(book.description,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    // chevron — ad is injected as its own separate row
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textMuted(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56, color: AppTheme.textMuted(context)),
            const SizedBox(height: 20),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
