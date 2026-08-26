import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../data/channel_data.dart';
import '../models/saved_bookmark.dart';
import '../providers/feed_provider.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/blog_thumbnail_image.dart';
import '../widgets/book_cover_image.dart';
import '../widgets/no_flash_page_route.dart';
import '../widgets/video_thumbnail_image.dart';
import 'blog_reader_screen.dart';
import 'book_detail_screen.dart';
import 'video_player_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  void _openBookmark(SavedBookmark bookmark) {
    if (bookmark.isBlog) {
      if ((bookmark.url ?? '').isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlogReaderScreen(
            url: bookmark.url!,
            title: bookmark.title,
            sourceName: bookmark.sourceName,
            thumbnailUrl: bookmark.thumbnailUrl,
            excerpt: bookmark.description,
            publishedAt: bookmark.publishedAt,
            categoryId: bookmark.sourceCategoryId,
          ),
        ),
      );
      return;
    }

    final video = bookmark.videoItem;
    if (bookmark.isBook) {
      if (bookmark.channelId == 'verified_book' ||
          video.channelId == 'verified_book') {
        if ((bookmark.url ?? '').isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlogReaderScreen(
              url: bookmark.url!,
              title: bookmark.title,
              categoryId: bookmark.sourceCategoryId,
            ),
          ),
        );
      } else {
        unawaited(AdService.instance.onVideoTapped());
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailScreen(book: video)),
        );
      }
      return;
    }

    final channel = ChannelData.byId[video.channelId] ?? ChannelData.fallback;
    unawaited(AdService.instance.onVideoTapped());
    Navigator.push(
      context,
      NoFlashPageRoute(
        builder: (_) => VideoPlayerScreen(video: video, channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedProvider>();
    final saved = provider.savedBookmarks;
    final shorts = saved.where((item) => item.isShort).toList(growable: false);
    final others = saved.where((item) => !item.isShort).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          if (saved.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearAll(context, provider),
              child: const Text(
                'Clear all',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: saved.isEmpty
                ? const _EmptySaved()
                : shorts.isEmpty
                    ? _SingleBookmarkColumn(
                        items: others,
                        onTap: _openBookmark,
                        onRemove: provider.toggleBookmark,
                      )
                    : _TwoColumnBookmarks(
                        shorts: shorts,
                        others: others,
                        onTap: _openBookmark,
                        onRemove: provider.toggleBookmark,
                      ),
          ),
          ListenableBuilder(
            listenable: AdService.instance,
            builder: (_, __) => AdService.instance.adsRemoved
                ? const SizedBox.shrink()
                : const LabelledBannerAd(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(
      BuildContext context, FeedProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all bookmarks?'),
        content: const Text(
          'This will remove all your saved videos, Shorts, blogs, and books permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear all',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await provider.clearSaved();
  }
}

class _SingleBookmarkColumn extends StatelessWidget {
  final List<SavedBookmark> items;
  final ValueChanged<SavedBookmark> onTap;
  final Future<void> Function(SavedBookmark) onRemove;

  const _SingleBookmarkColumn({
    required this.items,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _SavedContentCard(
        bookmark: items[index],
        onTap: () => onTap(items[index]),
        onRemove: () => onRemove(items[index]),
      ),
    );
  }
}

class _TwoColumnBookmarks extends StatelessWidget {
  final List<SavedBookmark> shorts;
  final List<SavedBookmark> others;
  final ValueChanged<SavedBookmark> onTap;
  final Future<void> Function(SavedBookmark) onRemove;

  const _TwoColumnBookmarks({
    required this.shorts,
    required this.others,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final rowCount = shorts.length > others.length ? shorts.length : others.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(child: _BookmarkColumnHeader('Shorts', Icons.play_circle_outline_rounded)),
              SizedBox(width: 8),
              Expanded(child: _BookmarkColumnHeader('Videos • Blogs • Books', Icons.grid_view_rounded)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: rowCount,
            itemBuilder: (_, index) {
              final short = index < shorts.length ? shorts[index] : null;
              final other = index < others.length ? others[index] : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: short == null
                            ? const SizedBox.shrink()
                            : _SavedShortCard(
                                bookmark: short,
                                onTap: () => onTap(short),
                                onRemove: () => onRemove(short),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: other == null
                            ? const SizedBox.shrink()
                            : _SavedContentCard(
                                bookmark: other,
                                onTap: () => onTap(other),
                                onRemove: () => onRemove(other),
                              ),
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

class _BookmarkColumnHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const _BookmarkColumnHeader(this.label, this.icon);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted(context)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted(context),
                    letterSpacing: 0.3,
                  ),
            ),
          ),
        ],
      );
}

class _SavedShortCard extends StatelessWidget {
  final SavedBookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedShortCard({
    required this.bookmark,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final video = bookmark.videoItem;
    final channel = ChannelData.byId[video.channelId] ?? ChannelData.fallback;
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
                VideoThumbnailImage(
                  video: video,
                  fit: BoxFit.cover,
                  memCacheWidth: 360,
                  memCacheHeight: 640,
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
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 3, color: channel.accentColor),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _RemoveBookmarkButton(onPressed: onRemove),
                ),
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    bookmark.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                    ),
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

class _SavedContentCard extends StatelessWidget {
  final SavedBookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedContentCard({
    required this.bookmark,
    required this.onTap,
    required this.onRemove,
  });

  String get _label {
    if (bookmark.isBook) return 'Book';
    if (bookmark.isBlog) return 'Blog';
    return 'Video';
  }

  Widget _thumbnail(BuildContext context) {
    if (bookmark.isBook) {
      return BookCoverImage(
        url: bookmark.thumbnailUrl ?? '',
        fallbackUrls: bookmark.thumbnailFallbackUrls,
      );
    }
    if (bookmark.isBlog) {
      return BlogThumbnailImage(
        url: bookmark.thumbnailUrl,
        fallbackUrls: bookmark.thumbnailFallbackUrls,
      );
    }
    return VideoThumbnailImage(
      video: bookmark.videoItem,
      fit: BoxFit.cover,
      memCacheWidth: 360,
      memCacheHeight: 203,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.dividerColor(context),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _thumbnail(context),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _RemoveBookmarkButton(onPressed: onRemove),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        bookmark.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${bookmark.sourceName} · ${timeago.format(bookmark.publishedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textMuted(context),
                            ),
                      ),
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

class _RemoveBookmarkButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RemoveBookmarkButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: 'Remove bookmark',
          onPressed: onPressed,
          icon: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 18),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        ),
      );
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_add_outlined,
                  size: 64, color: AppTheme.textMuted(context)),
              const SizedBox(height: 20),
              Text('No bookmarks yet',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Tap the bookmark button on a video, Short, blog, or book to save it here.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
