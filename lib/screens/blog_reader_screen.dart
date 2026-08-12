import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../services/ad_service.dart';
import '../services/engagement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/web_iframe_view.dart';

/// Opens a blog article or a free-book URL.
///
/// ─── NATIVE (Android / iOS) ───────────────────────────────────────────────
/// Uses flutter_inappwebview.  Navigation is intercepted so only the
/// article's own domain is followed inline; external links push a new
/// BlogReaderScreen.  A gold LinearProgressIndicator shows load progress.
/// Books (bookId ≠ null) additionally persist and restore scroll position.
///
/// ─── WEB — blog articles (sourceName ≠ null) ──────────────────────────────
/// Major news publishers (inc.com, entrepreneur.com, forbes.com, hbr.org …)
/// set X-Frame-Options: DENY, so iframes are actively refused.
/// Solution (same pattern used by Google News, LinkedIn, Twitter/X on web):
///   1. The article opens in a new browser tab the moment the screen mounts.
///   2. The screen itself shows a rich article preview card with the article's
///      thumbnail, source, headline, and excerpt from the RSS feed.
///   3. The AppBar back-arrow returns the user to the feed — identical to
///      pressing Back in any other FinReels screen.
///   4. A "Reopen Article" button is available if the user needs the tab again.
///
/// ─── WEB — books / external URLs (sourceName == null) ────────────────────
/// Public-domain book sources (Gutenberg HTML pages, blob URLs for local PDF
/// assets) allow framing, so WebIframeView continues to be used for them.
class BlogReaderScreen extends StatefulWidget {
  final String url;
  final String title;

  /// Article metadata — used only for the web preview card.
  /// Populated by BlogFeedScreen / CategoryDetailScreen / ContentSearchScreen.
  /// Null when this screen is opened for a book or an unknown URL.
  final String?   sourceName;
  final String?   thumbnailUrl;
  final String?   excerpt;
  final DateTime? publishedAt;

  /// Set when this came from a category-tagged feed.
  final String? categoryId;

  /// Set when this screen is opened for a *book*.
  /// Enables Hive scroll-progress tracking AND keeps WebIframeView on web
  /// (book sources allow framing; news sites do not).
  final String? bookId;

  const BlogReaderScreen({
    required this.url,
    required this.title,
    this.sourceName,
    this.thumbnailUrl,
    this.excerpt,
    this.publishedAt,
    this.categoryId,
    this.bookId,
    super.key,
  });

  @override
  State<BlogReaderScreen> createState() => _BlogReaderScreenState();
}

class _BlogReaderScreenState extends State<BlogReaderScreen> {

  // ── Page-load state (native only) ─────────────────────────────────────────
  double _progress = 0;
  bool   _loading  = true;
  late final String _allowedHost;

  // ── Scroll-progress tracking (native books only) ───────────────────────────
  Box<String>?  _progressBox;
  int?          _savedScrollPercent;
  bool          _hasRestored  = false;
  Timer?        _saveDebounce;

  String get _scrollKey => 'webview_scroll_${widget.bookId}';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _allowedHost = Uri.tryParse(widget.url)?.host ?? '';

    // Web has no InAppWebView progress callbacks — clear the loading state.
    if (kIsWeb) {
      _loading = false;
      _progress = 1;
    }

    // Web blog article: open the URL in a new browser tab on the first frame.
    // The preview card (this screen) stays open so the user keeps context
    // and the AppBar back-arrow to return to the feed — exactly the pattern
    // used by Google News, LinkedIn, and Twitter/X for external links on web.
    if (kIsWeb && widget.sourceName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final uri = Uri.tryParse(widget.url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      });
    }

    if (widget.categoryId != null) {
      unawaited(
        EngagementService.instance.recordCategoryInterest(widget.categoryId!),
      );
    }

    // Scroll-progress is a native-only feature (InAppWebView JS API).
    if (widget.bookId != null && !kIsWeb) {
      _progressBox        = Hive.box<String>('reading_progress');
      _savedScrollPercent = int.tryParse(_progressBox?.get(_scrollKey) ?? '');
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  // ── Scroll helpers (native books only) ────────────────────────────────────

  void _onScrollChanged(InAppWebViewController controller, int x, int y) {
    if (widget.bookId == null || _progressBox == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      final raw = await controller.evaluateJavascript(
        source: 'document.body.scrollHeight.toString()',
      );
      final scrollHeight =
          double.tryParse(raw?.toString().replaceAll('"', '') ?? '') ?? 0;
      if (scrollHeight > 0) {
        final percent = (y / scrollHeight * 100).clamp(0, 100).toInt();
        unawaited(_progressBox!.put(_scrollKey, percent.toString()));
      }
    });
  }

  Future<void> _maybeRestoreScroll(InAppWebViewController controller) async {
    if (widget.bookId == null) return;
    if (_savedScrollPercent == null || _savedScrollPercent! <= 0) return;
    if (_hasRestored) return;
    _hasRestored = true;

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final raw = await controller.evaluateJavascript(
      source: 'document.body.scrollHeight.toString()',
    );
    final scrollHeight =
        double.tryParse(raw?.toString().replaceAll('"', '') ?? '') ?? 0;
    if (scrollHeight <= 0) return;

    final targetY = (scrollHeight * _savedScrollPercent! / 100).toInt();
    await controller.scrollTo(x: 0, y: targetY, animated: true);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.bookmark_rounded, color: AppTheme.gold, size: 16),
            SizedBox(width: 8),
            Text('Resuming from where you left off'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Web: blog article ──────────────────────────────────────────────────
    // sourceName being non-null is the signal that this is a blog article
    // (not a book URL), so the preview card + auto-launch path is used.
    // All kIsWeb branches are compile-time dead on Android / iOS.
    if (kIsWeb && widget.sourceName != null) {
      return _buildWebArticlePreview(context);
    }

    // ── Web: book / external URL  AND  native: all content ────────────────
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  color: AppTheme.gold,
                  backgroundColor: Colors.transparent,
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: kIsWeb
                // Web books: Gutenberg HTML / blob URLs allow framing.
                ? WebIframeView(url: widget.url, title: widget.title)
                // Native: full in-app browser with navigation interception.
                : InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                    initialSettings: InAppWebViewSettings(
                      useShouldOverrideUrlLoading: true,
                      allowsInlineMediaPlayback: true,
                      mediaPlaybackRequiresUserGesture: false,
                      builtInZoomControls: false,
                    ),
                    onWebViewCreated: (_) {},
                    onLoadStart: (_, __) {
                      if (mounted) setState(() => _loading = true);
                    },
                    onLoadStop: (controller, __) async {
                      if (mounted) setState(() => _loading = false);
                      unawaited(_maybeRestoreScroll(controller));
                    },
                    onProgressChanged: (_, progress) {
                      if (mounted) {
                        setState(() {
                          _progress = progress / 100.0;
                          if (progress >= 100) _loading = false;
                        });
                      }
                    },
                    onScrollChanged: _onScrollChanged,
                    shouldOverrideUrlLoading: (controller, action) async {
                      final uri = action.request.url;
                      if (uri == null) return NavigationActionPolicy.CANCEL;
                      final scheme = uri.scheme.toLowerCase();
                      if (scheme == 'about' ||
                          scheme == 'data' ||
                          scheme == 'blob') {
                        return NavigationActionPolicy.ALLOW;
                      }
                      if (scheme != 'http' && scheme != 'https') {
                        final u = Uri.tryParse(uri.toString());
                        if (u != null && await canLaunchUrl(u)) {
                          await launchUrl(u,
                              mode: LaunchMode.externalApplication);
                        }
                        return NavigationActionPolicy.CANCEL;
                      }
                      final host = uri.host;
                      if (host == _allowedHost ||
                          host.endsWith('.$_allowedHost') ||
                          _allowedHost.isEmpty) {
                        return NavigationActionPolicy.ALLOW;
                      }
                      if (!mounted) return NavigationActionPolicy.CANCEL;
                      unawaited(
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlogReaderScreen(
                              url: uri.toString(),
                              title: uri.host,
                              categoryId: widget.categoryId,
                            ),
                          ),
                        ),
                      );
                      return NavigationActionPolicy.CANCEL;
                    },
                  ),
          ),
          ListenableBuilder(
            listenable: AdService.instance,
            builder: (_, __) => AdService.instance.adsRemoved
                ? const SizedBox.shrink()
                : const StickyBannerBar(),
          ),
        ],
      ),
    );
  }

  // ── Web article preview card ───────────────────────────────────────────────

  /// Displayed on web when this screen is opened for a blog article.
  ///
  /// The article has already been launched in a new browser tab by initState.
  /// This card keeps the user oriented within FinReels: they can read the
  /// article in the new tab and tap the AppBar ← to return to the feed —
  /// identical UX to Google News, LinkedIn, and Twitter/X on web.
  Widget _buildWebArticlePreview(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          // ── "Opened in tab" status bar ─────────────────────────────────
          Container(
            width: double.infinity,
            color: AppTheme.gold.withValues(alpha: 0.1),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              children: [
                const Icon(Icons.open_in_new_rounded,
                    size: 14, color: AppTheme.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Article opened in a new tab',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Thumbnail ──────────────────────────────────────────
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: widget.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.thumbnailUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _shimmer(context),
                            errorWidget: (_, __, ___) =>
                                _heroPlaceholder(context),
                          )
                        : _heroPlaceholder(context),
                  ),

                  // ── Gold accent strip ──────────────────────────────────
                  Container(height: 3, color: AppTheme.gold),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Source + date ──────────────────────────────
                        if (widget.sourceName != null ||
                            widget.publishedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [
                                if (widget.sourceName != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.gold
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.sourceName!.toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.gold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                if (widget.publishedAt != null) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    timeago.format(widget.publishedAt!),
                                    style: TextStyle(
                                      color: AppTheme.textMuted(context),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                        // ── Headline ───────────────────────────────────
                        Text(
                          widget.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                        ),

                        // ── Excerpt ────────────────────────────────────
                        if (widget.excerpt != null &&
                            widget.excerpt!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.excerpt!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textSecondary(context),
                                  height: 1.7,
                                ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // ── Reopen button ──────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final uri = Uri.tryParse(widget.url);
                              if (uri != null) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            icon: const Icon(Icons.open_in_new_rounded,
                                size: 18),
                            label: const Text(
                              'Reopen Article',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.gold,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            'Tap ← above to return to the feed',
                            style: TextStyle(
                              color: AppTheme.textMuted(context),
                              fontSize: 11,
                            ),
                          ),
                        ),

                        // ── Domain chip ────────────────────────────────
                        if (_allowedHost.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link_rounded,
                                      size: 13,
                                      color: AppTheme.textMuted(context)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _allowedHost,
                                    style: TextStyle(
                                      color: AppTheme.textMuted(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Ad bar ────────────────────────────────────────────────────
          ListenableBuilder(
            listenable: AdService.instance,
            builder: (_, __) => AdService.instance.adsRemoved
                ? const SizedBox.shrink()
                : const StickyBannerBar(),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _heroPlaceholder(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.gold.withValues(alpha: 0.25),
              AppTheme.gold.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.article_rounded, color: AppTheme.gold, size: 56),
        ),
      );

  Widget _shimmer(BuildContext context) => ColoredBox(
        color: AppTheme.surfaceColor(context),
      );
}
