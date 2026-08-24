import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../models/video.dart';
import '../theme/app_theme.dart';

/// Displays an ordinary YouTube video thumbnail without ever leaving a solid
/// black rectangle when an image request fails.
///
/// The candidate order prefers the feed-provided URL and normal YouTube sizes,
/// then the documented default/numbered image variants commonly used for
/// preview frames, and finally a small number of CORS-safe proxy candidates.
/// The numbered images are best-effort frame candidates; YouTube does not
/// guarantee a public exact-first-frame endpoint for every video.
class VideoThumbnailImage extends StatefulWidget {
  final Video video;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BorderRadius? borderRadius;

  const VideoThumbnailImage({
    required this.video,
    super.key,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.borderRadius,
  });

  @override
  State<VideoThumbnailImage> createState() => _VideoThumbnailImageState();
}

class _VideoThumbnailImageState extends State<VideoThumbnailImage> {
  late List<String> _candidates;
  int _index = 0;
  bool _retryScheduled = false;

  @override
  void initState() {
    super.initState();
    _candidates = _buildCandidates(widget.video);
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.video.thumbnailUrl != widget.video.thumbnailUrl) {
      _candidates = _buildCandidates(widget.video);
      _index = 0;
      _retryScheduled = false;
    }
  }

  static List<String> _buildCandidates(Video video) {
    if (video.channelId == 'books' || video.channelId == 'verified_book') {
      return [video.thumbnailUrl.trim()];
    }

    final id = video.id.trim();
    if (id.isEmpty) return const [''];

    final direct = <String>[
      video.thumbnailUrl.trim(),
      video.thumbnailHd,
      'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      video.thumbnailMq,
      'https://i.ytimg.com/vi/$id/sddefault.jpg',
      // Best-effort numbered preview-frame candidates.
      'https://i.ytimg.com/vi/$id/0.jpg',
      'https://i.ytimg.com/vi/$id/1.jpg',
      'https://i.ytimg.com/vi/$id/2.jpg',
      'https://i.ytimg.com/vi/$id/3.jpg',
    ];

    final output = <String>[];
    final seen = <String>{};
    void add(String value) {
      final url = value.trim();
      if (url.isEmpty || !seen.add(url)) return;
      output.add(url);
    }

    for (final url in direct) {
      add(url);
    }

    // Keep proxy retries bounded: direct YouTube URLs remain the preferred
    // path, while these four cover the common CORS/fetch failure cases.
    for (final url in direct.take(4)) {
      final parsed = Uri.tryParse(url);
      if (parsed == null ||
          (parsed.scheme != 'http' && parsed.scheme != 'https')) {
        continue;
      }
      add('https://wsrv.nl/?url=${Uri.encodeComponent(url)}');
    }

    return output.isEmpty ? const [''] : List.unmodifiable(output);
  }

  void _advanceAfterFailure() {
    if (_retryScheduled || _index + 1 >= _candidates.length) return;
    _retryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _retryScheduled = false;
      if (_index + 1 < _candidates.length) {
        setState(() => _index++);
      }
    });
  }

  Widget _shimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurfaceElevated,
      highlightColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.lightBg,
      child: ColoredBox(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    return ColoredBox(
      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurfaceElevated,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_outline_rounded,
                  color: foreground, size: 34),
              const SizedBox(height: 6),
              Text(
                widget.video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: _candidates[_index],
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      placeholder: (_, __) => _shimmer(context),
      errorWidget: (_, __, ___) {
        _advanceAfterFailure();
        return _index + 1 < _candidates.length
            ? _shimmer(context)
            : _fallback(context);
      },
    );

    final radius = widget.borderRadius;
    return radius == null
        ? image
        : ClipRRect(borderRadius: radius, child: image);
  }
}
