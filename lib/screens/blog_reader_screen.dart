import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ad_service.dart';
import '../services/engagement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/web_iframe_view.dart';

/// Opens a blog article or free-book URL inside the app using
/// flutter_inappwebview.  Navigation is intercepted — only the article's
/// own domain is allowed through.  A gold LinearProgressIndicator shows
/// page-load progress at the top.
///
/// When [bookId] is supplied the screen also tracks reading progress:
///   • Scroll position (0–100 %) is debounce-saved to the
///     "reading_progress" Hive box under the key `webview_scroll_<bookId>`.
///   • On subsequent opens the scroll position is restored automatically,
///     and a "Resuming from where you left off" snackbar is shown briefly.
class BlogReaderScreen extends StatefulWidget {
  final String url;
  final String title;

  /// Set when this article came from a category-tagged feed — lets the
  /// reader record that interest back into EngagementService.
  final String? categoryId;

  /// Set when this screen is opened for a *book* rather than a blog post.
  /// Enables Hive-backed scroll-progress tracking and the "resuming"
  /// snackbar.  Leave null for regular blog articles.
  final String? bookId;

  const BlogReaderScreen({
    required this.url,
    required this.title,
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
  Box<String>?            _progressBox;
  int?                    _savedScrollPercent;
  bool   _hasRestored  = false;
  Timer? _saveDebounce;

  String get _scrollKey => 'webview_scroll_${widget.bookId}';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _allowedHost = Uri.tryParse(widget.url)?.host ?? '';

    if (kIsWeb) {
      // Iframe has no load-progress callbacks into Flutter — clear the bar.
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

  // ── Scroll helpers ─────────────────────────────────────────────────────────

  /// Debounce-save the current scroll percentage to Hive.
  /// Fires at most once per 800 ms of scroll inactivity.
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

  /// Called once after the page finishes loading.  Restores the saved scroll
  /// position (with a short delay so lazy-rendered content has time to
  /// settle) and shows the "resuming" snackbar.
  Future<void> _maybeRestoreScroll(InAppWebViewController controller) async {
    if (widget.bookId == null) return;
    if (_savedScrollPercent == null || _savedScrollPercent! <= 0) return;
    if (_hasRestored) return;
    _hasRestored = true;

    // Give JS-heavy pages (archive.org, bookdio.org, etc.) time to finish
    // their own layout before we inject the scroll command.
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

  // ── Open-in-browser fallback (web only) ────────────────────────────────────

  /// Some publishers set X-Frame-Options / CSP frame-ancestors which causes
  /// the iframe to render blank.  We cannot detect this from Flutter (the
  /// browser silently blocks the frame), so we offer a persistent fallback
  /// button so the reader is never completely stranded.
  Widget _webFallbackBar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(widget.url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppTheme.dividerColor(context),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.open_in_browser_rounded,
                size: 15,
                color: AppTheme.gold.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                'Article not displaying? Open in browser',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.gold.withValues(alpha: 0.8),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
                // Web: load the article URL directly in an iframe so it
                // renders as a proper web page.  The previous approach of
                // routing through r.jina.ai returned plain-text/markdown
                // instead of HTML, which is why the screen showed raw
                // "Title:", "URL Source:", "Markdown Content:" output.
                ? WebIframeView(
                    url: widget.url,
                    title: widget.title,
                  )
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
                      // Allow about:blank / data / blob used by some readers.
                      if (scheme == 'about' ||
                          scheme == 'data' ||
                          scheme == 'blob') {
                        return NavigationActionPolicy.ALLOW;
                      }
                      if (scheme != 'http' && scheme != 'https') {
                        // mailto:, tel:, etc. — hand off to the OS.
                        final u = Uri.tryParse(uri.toString());
                        if (u != null && await canLaunchUrl(u)) {
                          await launchUrl(u, mode: LaunchMode.externalApplication);
                        }
                        return NavigationActionPolicy.CANCEL;
                      }
                      final host = uri.host;
                      // Same site (incl. subdomains) stays in this WebView.
                      if (host == _allowedHost ||
                          host.endsWith('.$_allowedHost') ||
                          _allowedHost.isEmpty) {
                        return NavigationActionPolicy.ALLOW;
                      }
                      // External article link: open inside FinReels in a new
                      // reader so taps never feel "dead".
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
          // Web-only fallback: if the site's X-Frame-Options / CSP blocks
          // the iframe (renders blank), the reader can still open the
          // article in a real browser tab.  Shown above the ad bar.
          if (kIsWeb) _webFallbackBar(context),
          // Sticky banner ad — pinned to the bottom while the user reads.
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
}
