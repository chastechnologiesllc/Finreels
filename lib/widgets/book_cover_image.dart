import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Renders a book cover from either:
///  • a bundled Flutter asset (path starts with 'assets/'), or
///  • a remote network URL (Open Library, Global Grey, archive.org, etc.)
///
/// Used everywhere a book thumbnail appears (Books tab list, book detail
/// header, Saved/Bookmarks list) so local PDF-book covers and remote
/// EPUB-book covers render identically with the same placeholder and
/// error-fallback behaviour.
class BookCoverImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const BookCoverImage({
    required this.url,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  bool get _isAsset => url.startsWith('assets/');
  bool get _isEmpty => url.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) {
      final fb = _fallback(context);
      return borderRadius != null
          ? ClipRRect(borderRadius: borderRadius!, child: fb)
          : fb;
    }
    final image = _isAsset ? _buildAsset(context) : _buildNetwork(context);
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  Widget _buildAsset(BuildContext context) {
    return Image.asset(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _fallback(context),
    );
  }

  Widget _buildNetwork(BuildContext context) {
    // Book cover URLs come from varied external sources (Open Library,
    // Global Grey, archive.org) whose actual resolution is unpredictable —
    // some scans run well beyond 1000px wide. Deriving the decode target
    // from this widget's own requested size (scaled for device pixel
    // ratio) keeps every cover's memory footprint proportional to how
    // large it's actually rendered, rather than whatever the source
    // happens to be. Falls back to a generous fixed size only for the one
    // caller (video_card.dart, book cards in a Stack.expand) that doesn't
    // pass explicit width/height.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth  = width  != null ? (width! * dpr).round()  : 480;
    final cacheHeight = height != null ? (height! * dpr).round() : 640;

    // Shimmer colours adapt to the active theme so they're visible in both
    // light and dark mode. Dark shimmer on a dark background and light
    // shimmer on a light background are both near-invisible — invert instead.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBase      = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0);
    final shimmerHighlight = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      // Smooth fade-in once the image is ready — avoids the jarring
      // snap from shimmer to full image on fast connections.
      fadeInDuration: const Duration(milliseconds: 250),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: shimmerBase,
        highlightColor: shimmerHighlight,
        child: SizedBox(
          width: width,
          height: height,
          child: const ColoredBox(color: Colors.white),
        ),
      ),
      errorWidget: (_, __, ___) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    final iconSize = (width != null && width! < 80) ? 22.0 : 40.0;
    return Container(
      width: width,
      height: height,
      color: AppTheme.gold.withValues(alpha: 0.15),
      child: Icon(Icons.menu_book_rounded, color: AppTheme.gold, size: iconSize),
    );
  }
}
