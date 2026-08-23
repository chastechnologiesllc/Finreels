import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Renders a book cover from either a bundled Flutter asset or a remote URL.
/// For remote books, [fallbackUrls] must be an ordered list of exact-edition
/// cover candidates. The first successful candidate wins; generic title-only
/// cover searches are intentionally not generated here.
class BookCoverImage extends StatefulWidget {
  final String url;
  final List<String> fallbackUrls;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const BookCoverImage({
    required this.url,
    super.key,
    this.fallbackUrls = const [],
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

  bool get _isEmpty => _candidates.isEmpty ||
      _candidates.every((url) => url.trim().isEmpty);

  @override
  void initState() {
    super.initState();
    _candidates = _buildCandidates(widget.url, widget.fallbackUrls);
  }

  @override
  void didUpdateWidget(covariant BookCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        !listEquals(oldWidget.fallbackUrls, widget.fallbackUrls)) {
      _candidates = _buildCandidates(widget.url, widget.fallbackUrls);
      _index = 0;
    }
  }

  /// Build ordered, exact-cover candidates. Provider-specific size variants
  /// are added only when the supplied URL already identifies an edition.
  static List<String> _buildCandidates(
      String primary, List<String> fallbackUrls) {
    final seeds = <String>[
      primary.trim(),
      ...fallbackUrls.map((url) => url.trim()),
    ].where((url) => url.isNotEmpty).toList();
    if (seeds.isEmpty) return [''];

    final out = <String>[];
    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty && !out.contains(trimmed)) out.add(trimmed);
    }

    for (final seed in seeds) {
      add(seed);

      final olIsbn = RegExp(
              r'https?://covers\.openlibrary\.org/b/isbn/([0-9X\-]+)-([LMS])\.jpg',
              caseSensitive: false)
          .firstMatch(seed);
      if (olIsbn != null) {
        final isbn = olIsbn.group(1)!;
        final size = olIsbn.group(2)!.toUpperCase();
        for (final candidateSize in ['L', 'M', 'S']) {
          if (candidateSize != size) {
            add('https://covers.openlibrary.org/b/isbn/$isbn-$candidateSize.jpg');
          }
        }
        final compact = isbn.replaceAll('-', '');
        if (compact != isbn) {
          for (final candidateSize in ['L', 'M', 'S']) {
            add('https://covers.openlibrary.org/b/isbn/$compact-$candidateSize.jpg');
          }
        }
      }

      final olId = RegExp(
              r'https?://covers\.openlibrary\.org/b/(id|olid)/([A-Za-z0-9]+)-([LMS])\.jpg',
              caseSensitive: false)
          .firstMatch(seed);
      if (olId != null) {
        final kind = olId.group(1)!.toLowerCase();
        final id = olId.group(2)!;
        final size = olId.group(3)!.toUpperCase();
        for (final candidateSize in ['L', 'M', 'S']) {
          if (candidateSize != size) {
            add('https://covers.openlibrary.org/b/$kind/$id-$candidateSize.jpg');
          }
        }
      }

      final gutenberg = RegExp(
              r'https?://www\.gutenberg\.org/cache/epub/(\d+)/pg\1\.cover\.(medium|small)\.jpg',
              caseSensitive: false)
          .firstMatch(seed);
      if (gutenberg != null) {
        final id = gutenberg.group(1)!;
        add('https://www.gutenberg.org/cache/epub/$id/pg$id.cover.medium.jpg');
        add('https://www.gutenberg.org/cache/epub/$id/pg$id.cover.small.jpg');
      }

      final ia = RegExp(
              r'https?://archive\.org/services/img/([A-Za-z0-9_\-\.]+)',
              caseSensitive: false)
          .firstMatch(seed);
      if (ia != null) {
        final id = ia.group(1)!;
        add('https://archive.org/download/$id/__ia_thumb.jpg');
        add('https://archive.org/services/img/$id');
      }
    }

    return out;
  }

  String get _currentUrl => _candidates.isEmpty
      ? widget.url
      : _candidates[_index.clamp(0, _candidates.length - 1)];

  bool get _currentIsAsset => _currentUrl.startsWith('assets/');

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

    final image = _currentIsAsset
        ? _buildAsset(context)
        : _buildNetwork(context);
    if (widget.borderRadius == null) return image;
    return ClipRRect(borderRadius: widget.borderRadius!, child: image);
  }

  Widget _buildAsset(BuildContext context) {
    return Image.asset(
      _currentUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) {
        if (_index + 1 < _candidates.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tryNext();
          });
          return _loadingPlaceholder(context);
        }
        return _fallback(context);
      },
    );
  }

  Widget _buildNetwork(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth =
        widget.width != null ? (widget.width! * dpr).round() : 480;
    final cacheHeight =
        widget.height != null ? (widget.height! * dpr).round() : 640;
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
      placeholder: (_, __) => _loadingPlaceholder(context),
      errorWidget: (_, __, ___) {
        if (hasMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tryNext();
          });
          return _loadingPlaceholder(context);
        }
        return _fallback(context);
      },
    );
  }

  Widget _loadingPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0);
    final highlight = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: const ColoredBox(color: Colors.white),
      ),
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
