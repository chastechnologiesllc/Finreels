import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../services/media_cache_manager.dart';
import '../theme/app_theme.dart';
import 'rumuo_shimmer.dart';

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

  String get _selectionKey =>
      'blog:${widget.url}|${widget.fallbackUrls.join('|')}';

  void _restoreSelection() {
    final remembered = RumuoMediaCache.selectedIndex(_selectionKey);
    if (remembered != null && remembered >= 0 && remembered < _candidates.length) {
      _index = remembered;
    }
  }

  @override
  void initState() {
    super.initState();
    _candidates = _buildCandidates(widget.url, widget.fallbackUrls);
    _restoreSelection();
  }

  @override
  void didUpdateWidget(covariant BlogThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        !listEquals(oldWidget.fallbackUrls, widget.fallbackUrls)) {
      _candidates = _buildCandidates(widget.url, widget.fallbackUrls);
      _index = 0;
      _restoreSelection();
    }
  }

  static List<String> _buildCandidates(
      String? primary, List<String> fallbacks) {
    final out = <String>[];
    var sourceCount = 0;
    for (final value in <String?>[primary, ...fallbacks]) {
      if (sourceCount >= 5) break;
      final url = value?.trim() ?? '';
      if (url.isEmpty || url.startsWith('data:')) continue;
      final parsed = Uri.tryParse(url);
      if (parsed == null ||
          (parsed.scheme != 'http' && parsed.scheme != 'https')) {
        continue;
      }
      if (out.contains(url)) continue;
      sourceCount++;
      out.add(url);
      final encoded = Uri.encodeComponent(url);
      final proxied = 'https://wsrv.nl/?url=$encoded';
      final legacyProxied = 'https://images.weserv.nl/?url=$encoded';
      if (!out.contains(proxied)) out.add(proxied);
      if (!out.contains(legacyProxied)) out.add(legacyProxied);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty) return _fallback(context);
    final url = _candidates[_index.clamp(0, _candidates.length - 1)];
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: RumuoMediaCache.instance,
      imageBuilder: (_, imageProvider) {
        RumuoMediaCache.rememberSelection(_selectionKey, _index);
        return Image(image: imageProvider, fit: widget.fit);
      },
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: widget.width == null
          ? 720
          : (widget.width! * MediaQuery.devicePixelRatioOf(context)).round(),
      memCacheHeight: widget.height == null
          ? 405
          : (widget.height! * MediaQuery.devicePixelRatioOf(context)).round(),
      placeholder: (_, __) => _placeholder(context),
      errorWidget: (_, __, ___) {
        if (_index + 1 < _candidates.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index++);
          });
          return _placeholder(context);
        }
        return _fallback(context);
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    return RumuoShimmer(
      child: ColoredBox(color: RumuoShimmer.fillColor(context)),
    );
  }

  Widget _fallback(BuildContext context) {
    return Image.asset(
      'assets/blog/rumuo_blog_cover.png',
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      semanticLabel: 'Rumuo insights blog cover',
      errorBuilder: (_, __, ___) => _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
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
