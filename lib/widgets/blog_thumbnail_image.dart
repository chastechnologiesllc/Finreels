import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Displays a blog thumbnail from an ordered list of feed-provided candidates.
/// A broken featured-image URL never leaves the card blank: the widget advances
/// to the next candidate and finally uses the branded article placeholder.
class BlogThumbnailImage extends StatefulWidget {
  final String? url;
  final List<String> fallbackUrls;
  final double? width;
  final double? height;
  final BoxFit fit;

  const BlogThumbnailImage({
    super.key,
    this.url,
    this.fallbackUrls = const [],
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<BlogThumbnailImage> createState() => _BlogThumbnailImageState();
}

class _BlogThumbnailImageState extends State<BlogThumbnailImage> {
  late List<String> _candidates;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _candidates = _buildCandidates(widget.url, widget.fallbackUrls);
  }

  @override
  void didUpdateWidget(covariant BlogThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        !listEquals(oldWidget.fallbackUrls, widget.fallbackUrls)) {
      _candidates = _buildCandidates(widget.url, widget.fallbackUrls);
      _index = 0;
    }
  }

  static List<String> _buildCandidates(
      String? primary, List<String> fallbacks) {
    final out = <String>[];
    for (final value in <String?>[primary, ...fallbacks]) {
      final url = value?.trim() ?? '';
      if (url.isEmpty || url.startsWith('data:')) continue;
      final parsed = Uri.tryParse(url);
      if (parsed == null ||
          (parsed.scheme != 'http' && parsed.scheme != 'https')) {
        continue;
      }
      if (!out.contains(url)) out.add(url);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty) return _fallback(context);
    final url = _candidates[_index.clamp(0, _candidates.length - 1)];
    return CachedNetworkImage(
      imageUrl: url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      memCacheWidth: widget.width == null
          ? 720
          : (widget.width! * MediaQuery.devicePixelRatioOf(context)).round(),
      memCacheHeight: widget.height == null
          ? 405
          : (widget.height! * MediaQuery.devicePixelRatioOf(context)).round(),
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) {
        if (_index + 1 < _candidates.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index++);
          });
          return _placeholder();
        }
        return _fallback(context);
      },
    );
  }

  Widget _placeholder() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E1E),
      highlightColor: const Color(0xFF2C2C2C),
      child: const ColoredBox(color: Colors.white),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gold.withValues(alpha: 0.25),
            AppTheme.gold.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.article_rounded,
          color: AppTheme.gold.withValues(alpha: 0.55),
          size: (widget.width != null && widget.width! < 80) ? 24 : 40,
        ),
      ),
    );
  }
}
