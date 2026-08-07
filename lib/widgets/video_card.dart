import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/channel.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import 'book_cover_image.dart';

/// Compact read-only card used in the Saved screen.
/// All Image.network calls replaced with CachedNetworkImage (Fix 5).
class VideoCard extends StatelessWidget {
  final Video video;
  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final bool saved;
  final bool compact;

  const VideoCard({
    required this.video,
    required this.channel,
    required this.onTap,
    super.key,
    this.onSave,
    this.onShare,
    this.saved = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.dividerColor(context), width: 0.5),
          ),
          clipBehavior: Clip.hardEdge,
          child: compact ? _buildCompact(context) : _buildFull(context),
        ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.03, end: 0),
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildThumbnail(context, aspectRatio: 16 / 9),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(height: 1.35, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ChannelDot(color: channel.accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      channel.name,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '· ${timeago.format(video.publishedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (onSave != null || onShare != null) ...[
                    const SizedBox(width: 4),
                    _actionMenu(context),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              bottomLeft: Radius.circular(15),
            ),
            child: SizedBox(
              width: 130,
              height: 90,
              child: _buildThumbnailContent(context),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w600, height: 1.3)),
                  Row(
                    children: [
                      _ChannelDot(color: channel.accentColor),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${channel.name} · ${timeago.format(video.publishedAt)}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context,
      {required double aspectRatio}) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildThumbnailContent(context),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(height: 3, color: channel.accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailContent(BuildContext context) {
    final isBook = video.channelId == 'books' || video.channelId == 'verified_book';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (isBook)
          // Books: use the asset/network-aware cover widget. No fake
          // YouTube thumbnail URL — video.thumbnailHd already resolves
          // to the book's real cover via the Video model fix.
          BookCoverImage(url: video.thumbnailHd)
        else
          CachedNetworkImage(
            imageUrl: video.thumbnailHd,
            fit: BoxFit.cover,
            memCacheWidth: 720,
            memCacheHeight: 405,
            placeholder: (_, __) => Shimmer.fromColors(
              baseColor: const Color(0xFF1E1E1E),
              highlightColor: const Color(0xFF2C2C2C),
              child: const ColoredBox(color: Colors.white),
            ),
            errorWidget: (_, __, ___) => CachedNetworkImage(
              imageUrl: video.thumbnailMq,
              fit: BoxFit.cover,
              memCacheWidth: 720,
              memCacheHeight: 405,
              placeholder: (_, __) => Shimmer.fromColors(
                baseColor: const Color(0xFF1E1E1E),
                highlightColor: const Color(0xFF2C2C2C),
                child: const ColoredBox(color: Colors.white),
              ),
              errorWidget: (_, __, ___) => ColoredBox(
                color: AppTheme.surfaceElevated(context),
                child: Icon(Icons.play_circle_outline_rounded,
                    color: AppTheme.textMuted(context), size: 36),
              ),
            ),
          ),
        // Play button overlay — videos only. A play icon over a book
        // cover would be misleading since tapping opens a reader, not a
        // video player.
        if (!isBook)
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
      ],
    );
  }

  Widget _actionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded,
          size: 18, color: AppTheme.textMuted(context)),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        if (onSave != null)
          PopupMenuItem(
            value: 'save',
            child: Row(
              children: [
                Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_add_outlined,
                    size: 18,
                    color: AppTheme.gold),
                const SizedBox(width: 10),
                Text(saved ? 'Remove bookmark' : 'Bookmark'),
              ],
            ),
          ),
        if (onShare != null)
          const PopupMenuItem(
            value: 'share',
            child: Row(
              children: [
                Icon(Icons.share_outlined, size: 18),
                SizedBox(width: 10),
                Text('Share'),
              ],
            ),
          ),
      ],
      onSelected: (v) {
        if (v == 'save') onSave?.call();
        if (v == 'share') onShare?.call();
      },
    );
  }
}

class _ChannelDot extends StatelessWidget {
  final Color color;
  const _ChannelDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
