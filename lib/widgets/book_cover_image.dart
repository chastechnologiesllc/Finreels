import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Renders a book cover from either:
///  • a bundled Flutter asset (path starts with 'assets/'), or
///  • a remote network URL (Open Library, Global Grey, archive.org, etc.)
///
/// When a remote cover 404s, automatically tries alternate Open Library
/// sizes / ID forms and a few public CDN patterns before showing the
/// branded placeholder. Used everywhere a book thumbnail appears.
class BookCoverImage extends StatefulWidget {
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

  @override
  State<BookCoverImage> createState() => _BookCoverImageState();
}

class _BookCoverImageState extends State<BookCoverImage> {
  late List<String> _candidates;
  int _index = 0;

  bool get _isAsset => widget.url.startsWith('assets/');
  bool get _isEmpty => widget.url.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _candidates = _buildCandidates(widget.url);
  }

  @override
  void didUpdateWidget(covariant BookCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _candidates = _buildCandidates(widget.url);
      _index = 0;
    }
  }

  /// Build ordered fallback URLs for common cover hosts.
  static List<String> _buildCandidates(String primary) {
    final u = primary.trim();
    if (u.isEmpty || u.startsWith('assets/')) return [u];

    final out = <String>[u];

    // Open Library: try size variants (L → M → S) and isbn ↔ id forms.
    final olIsbn = RegExp(
            r'https?://covers\.openlibrary\.org/b/isbn/([0-9X\-]+)-([LMS])\.jpg',
            caseSensitive: false)
        .firstMatch(u);
    if (olIsbn != null) {
      final isbn = olIsbn.group(1)!;
      final size = olIsbn.group(2)!.toUpperCase();
      for (final s in ['L', 'M', 'S']) {
        if (s == size) continue;
        out.add('https://covers.openlibrary.org/b/isbn/$isbn-$s.jpg');
      }
      // Some ISBNs only resolve via the ID endpoint after a redirect; try
      // the hyphen-stripped ISBN as well.
      final compact = isbn.replaceAll('-', '');
      if (compact != isbn) {
        for (final s in ['L', 'M', 'S']) {
          out.add('https://covers.openlibrary.org/b/isbn/$compact-$s.jpg');
        }
      }
    }

    final olId = RegExp(
            r'https?://covers\.openlibrary\.org/b/(id|olid)/([A-Za-z0-9]+)-([LMS])\.jpg',
            caseSensitive: false)
        .firstMatch(u);
    if (olId != null) {
      final kind = olId.group(1)!.toLowerCase();
      final id = olId.group(2)!;
      final size = olId.group(3)!.toUpperCase();
      for (final s in ['L', 'M', 'S']) {
        if (s == size) continue;
        out.add('https://covers.openlibrary.org/b/$kind/$id-$s.jpg');
      }
    }

    // archive.org services/img sometimes returns a generic placeholder;
    // also try the item page cover path if the id is present.
    final ia = RegExp(r'https?://archive\.org/services/img/([A-Za-z0-9_\-\.]+)',
            caseSensitive: false)
        .firstMatch(u);
    if (ia != null) {
      final id = ia.group(1)!;
      out.add('https://archive.org/download/$id/__ia_thumb.jpg');
      out.add('https://archive.org/services/img/$id');
    }

    // Deduplicate while preserving order.
    final seen = <String>{};
    return out.where(seen.add).toList();
  }

  String get _currentUrl =>
      _candidates.isEmpty ? widget.url : _candidates[_index.clamp(0, _candidates.length - 1)];

  void _tryNext() {
    if (_index + 1 < _candidates.length) {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) {
      final fb = _fallback(context);
      return widget.borderRadius != null
          ? ClipRRect(borderRadius: widget.borderRadius!, child: fb)
          : fb;
    }
    final image = _isAsset ? _buildAsset(context) : _buildNetwork(context);
    if (widget.borderRadius == null) return image;
    return ClipRRect(borderRadius: widget.borderRadius!, child: image);
  }

  Widget _buildAsset(BuildContext context) {
    return Image.asset(
      widget.url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => _fallback(context),
    );
  }

  Widget _buildNetwork(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth =
        widget.width != null ? (widget.width! * dpr).round() : 480;
    final cacheHeight =
        widget.height != null ? (widget.height! * dpr).round() : 640;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBase =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0);
    final shimmerHighlight =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);

    final hasMore = _index + 1 < _candidates.length;

    return CachedNetworkImage(
      imageUrl: _currentUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      fadeInDuration: const Duration(milliseconds: 250),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: shimmerBase,
        highlightColor: shimmerHighlight,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: const ColoredBox(color: Colors.white),
        ),
      ),
      errorWidget: (_, __, ___) {
        if (hasMore) {
          // Schedule next candidate on next frame to avoid setState during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tryNext();
          });
          return Shimmer.fromColors(
            baseColor: shimmerBase,
            highlightColor: shimmerHighlight,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: const ColoredBox(color: Colors.white),
            ),
          );
        }
        return _fallback(context);
      },
    );
  }

  Widget _fallback(BuildContext context) {
    final iconSize =
        (widget.width != null && widget.width! < 80) ? 22.0 : 40.0;
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppTheme.gold.withValues(alpha: 0.15),
      child: Icon(Icons.menu_book_rounded, color: AppTheme.gold, size: iconSize),
    );
  }
}
