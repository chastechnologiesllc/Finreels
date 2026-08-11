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
/// NATIVE (Android / iOS)
///   Uses flutter_inappwebview — full in-app browser with navigation
///   interception, progress bar, and scroll-position persistence (books).
///
/// WEB — blog articles  (bookId == null)
///   Major news publishers (inc.com, entrepreneur.com, forbes.com, hbr.org)
///   set X-Frame-Options: DENY, so embedding their pages in an <iframe> is
///   actively refused by the browser.  The correct solution — used by Pocket,
///   Google News, Flipboard, and Apple News on web — is to show a rich
///   article preview card (thumbnail, title, source, excerpt) and open the
///   full article in a new browser tab.
///
/// WEB — books  (bookId != null)
///   Public-domain book sources (Gutenberg HTML pages, blob URLs for PDF
///   assets) do allow framing, so WebIframeView continues to work for them.
class BlogReaderScreen extends StatefulWidget {
  final String url;
  final String title;

  /// Extra article metadata — used for the web preview card.
  /// Passed from BlogFeedScreen; null when opened from other contexts.
  final String?   sourceName;
  final String?   thumbnailUrl;
  final String?   excerpt;
  final DateTime? publishedAt;

  /// Set when this came from a category-tagged feed.
  final String? categoryId;

  /// Set when this screen is opened for a *book* rather than a blog post.
  /// Enables Hive-backed scroll-progress tracking, the "resuming" snackbar,
  /// AND keeps WebIframeView on web (book sources allow framing).
  /// Leave null for regular blog articles.
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
  // ── Page-load state ────────────────────────────────────────────────────────
  double _progress = 0;
  bool   _loading  = true;
  late final String _allowedHost;

  // ── Scroll-progress tracking (books only) ──────────────────────────────────
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

    if (kIsWeb && widget.bookId != null) {
      // Book iframe — no load-progress callbacks into Flutter.
      _loading = false;
      _progress = 1;
    }

    if (widget.categoryId != null) {
      unawaited(
        EngagementService.instance.recordCategoryInterest(widget.categoryId!),
      );
    }

    if (widget.bookId != null) {
      _progressBox       = Hive.box<String>('reading_progress');
      _savedScrollPercent =
          int.tryParse(_progressBox?.get(_scrollKey) ?? '');
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
        if (_progressBox != null) {
          unawaited(_progressBox!.put(_scrollKey, percent.toString()));
        }
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
    // Web — blog articles: show a rich preview card, open full article in
    // a new browser tab.  Publishers block iframe embedding by design.
    if (kIsWeb && widget.bookId == null) {
      return _buildWebArticlePreview(context);
    }

    // Web — books: Gutenberg HTML and PDF blob URLs allow framing → iframe.
    // Native (Android / iOS): full in-app webview for all content.
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
                ? WebIframeView(url: widget.url, title: widget.title)
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

  // ── Web article preview ────────────────────────────────────────────────────

  /// Shown on web when opening a blog article (bookId == null).
  ///
  /// Displays the article's thumbnail, source, title, and excerpt —
  /// everything already available from the RSS feed — then opens the full
  /// article in a new browser tab via launchUrl.  This pattern matches how
  /// Pocket, Google News, and Flipboard handle publishers that block iframes.
  Widget _buildWebArticlePreview(BuildContext context) {
    final hasMeta = widget.thumbnailUrl != null ||
        widget.sourceName != null ||
        (widget.excerpt != null && widget.excerpt!.isNotEmpty);

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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Thumbnail ────────────────────────────────────────────
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

                  // ── Gold accent strip ─────────────────────────────────────
                  Container(height: 3, color: AppTheme.gold),

                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Source + date ────────────────────────────────────
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

                        // ── Headline ─────────────────────────────────────────
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

                        // ── Excerpt ──────────────────────────────────────────
                        if (widget.excerpt != null &&
                            widget.excerpt!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.excerpt!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      AppTheme.textSecondary(context),
                                  height: 1.7,
                                ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // ── Primary CTA ──────────────────────────────────────
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
                            icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 18),
                            label: const Text(
                              'Read Full Article',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.gold,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            'Opens in your browser',
                            style: TextStyle(
                              color: AppTheme.textMuted(context),
                              fontSize: 11,
                            ),
                          ),
                        ),

                        // ── Domain chip ──────────────────────────────────────
                        if (_allowedHost.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link_rounded,
                                      size: 13,
                                      color: AppTheme.textMuted(
                                          context)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _allowedHost,
                                    style: TextStyle(
                                      color:
                                          AppTheme.textMuted(context),
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

          // ── Ad bar ───────────────────────────────────────────────────────
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

  // ── Placeholder helpers ────────────────────────────────────────────────────

  Widget _heroPlaceholder(BuildContext context) => Container(
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
          child: Icon(Icons.article_rounded,
              color: AppTheme.gold, size: 56),
        ),
      );

  Widget _shimmer(BuildContext context) => Container(
        color: AppTheme.surfaceColor(context),
      );
}
