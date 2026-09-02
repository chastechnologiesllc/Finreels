import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
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
/// article's own domain is followed inline; external links open a new
/// BlogReaderScreen.  A gold progress bar shows page-load state.
/// Books (bookId ≠ null) persist and restore scroll position via Hive.
///
/// ─── WEB — blog articles  (sourceName ≠ null) ─────────────────────────────
/// Publishers set X-Frame-Options: DENY on their own URLs, so loading them
/// directly in an <iframe> is refused.  We work around this with the same
/// technique used by Pocket's offline reader and Safari Reader Mode:
///
///   1. Fetch the full article HTML through a CORS proxy (corsproxy.io with
///      allorigins.win as a concurrent fallback — see _loadArticleHtml).
///   2. Inject a <base href="…"> tag so relative asset URLs resolve against
///      the original domain.
///   3. Hand the HTML to WebIframeView, which wraps it in a blob: URL.
///      blob: URLs are same-origin to the app — X-Frame-Options never applies.
///
/// The AppBar back-arrow returns the user to the feed in the normal way.
/// If both proxies fail, a retry/open-in-browser fallback is shown.
///
/// ─── WEB — books / external URLs  (sourceName == null) ───────────────────
/// Gutenberg HTML pages and blob PDF assets allow framing, so WebIframeView
/// loads them by URL as before.
class BlogReaderScreen extends StatefulWidget {
  final String url;
  final String title;

  /// Set when opened from a blog feed — distinguishes articles (web: blob
  /// fetch path) from books (web: direct iframe path).
  /// Also displayed in the AppBar while the article is loading on web.
  final String? sourceName;

  /// Unused in rendering but forwarded to EngagementService.
  final String? categoryId;

  /// Set when this screen is opened for a *book*.
  /// Enables Hive scroll-progress tracking on native; keeps the direct
  /// iframe path on web (book sources allow framing).
  final String? bookId;

  // Extra article metadata kept for potential future use; not rendered.
  final String? thumbnailUrl;
  final String? excerpt;
  final DateTime? publishedAt;

  const BlogReaderScreen({
    required this.url,
    required this.title,
    this.sourceName,
    this.categoryId,
    this.bookId,
    this.thumbnailUrl,
    this.excerpt,
    this.publishedAt,
    super.key,
  });

  @override
  State<BlogReaderScreen> createState() => _BlogReaderScreenState();
}

class _BlogReaderScreenState extends State<BlogReaderScreen> {

  // ── Native page-load state ─────────────────────────────────────────────────
  double _progress = 0;
  bool   _loading  = true;
  late final String _allowedHost;

  // ── Native book scroll-progress ────────────────────────────────────────────
  Box<String>?  _progressBox;
  int?          _savedScrollPercent;
  bool          _hasRestored  = false;
  Timer?        _saveDebounce;

  String get _scrollKey => 'webview_scroll_${widget.bookId}';

  // ── Web article fetch state ────────────────────────────────────────────────
  /// The HTML fetched from a proxy, with <base> injected; drives WebIframeView.
  String? _fetchedHtml;
  bool    _webFetching = false;
  bool    _webFailed   = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _allowedHost = Uri.tryParse(widget.url)?.host ?? '';

    if (kIsWeb) {
      // No InAppWebView progress callbacks on web.
      _loading = false;
      _progress = 1;
    }

    if (widget.categoryId != null) {
      unawaited(
        EngagementService.instance.recordCategoryInterest(widget.categoryId!),
      );
    }

    // Native-only: Hive scroll-progress for books.
    if (widget.bookId != null && !kIsWeb) {
      _progressBox        = Hive.box<String>('reading_progress');
      _savedScrollPercent = int.tryParse(_progressBox?.get(_scrollKey) ?? '');
    }

    // Web articles: fetch HTML immediately so the iframe is ready to display.
    if (kIsWeb && widget.sourceName != null) {
      _loadArticleHtml();
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  // ── Web article HTML fetch ─────────────────────────────────────────────────

  /// Fetches the article HTML through two concurrent CORS proxies and
  /// injects a <base> tag so relative asset URLs resolve correctly.
  ///
  /// On success: [_fetchedHtml] is set → WebIframeView renders via blob URL.
  /// On failure: [_webFailed] is set → fallback UI with retry / open-in-browser.
  Future<void> _loadArticleHtml() async {
    if (!mounted) return;
    setState(() {
      _webFetching = true;
      _webFailed   = false;
    });

    final encoded  = Uri.encodeComponent(widget.url);
    final proxies  = [
      'https://corsproxy.io/?url=$encoded',
      'https://api.allorigins.win/raw?url=$encoded',
    ];

    final completer = Completer<String?>();
    var pending = proxies.length;

    for (final proxy in proxies) {
      unawaited(() async {
        try {
          final res = await http
              .get(Uri.parse(proxy))
              .timeout(const Duration(seconds: 15));
          if (res.statusCode == 200 && res.bodyBytes.length > 200) {
            final html = _injectBase(
              utf8.decode(res.bodyBytes, allowMalformed: true),
              widget.url,
            );
            if (!completer.isCompleted) {
              completer.complete(html);
              return;
            }
          }
        } on Object catch (e) {
          debugPrint('[BlogReaderScreen] HTML fetch $proxy: $e');
        }
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null); // All proxies failed.
        }
      }());
    }

    final html = await completer.future;
    if (!mounted) return;
    if (html != null) {
      setState(() {
        _fetchedHtml = html;
        _webFetching = false;
      });
    } else {
      setState(() {
        _webFetching = false;
        _webFailed   = true;
      });
    }
  }

  /// Injects `<base href="origin">` after the first `<head>` tag so every
  /// relative URL (CSS, images, fonts) resolves against the original domain.
  static String _injectBase(String html, String originalUrl) {
    final uri = Uri.tryParse(originalUrl);
    if (uri == null) return html;
    final origin = '${uri.scheme}://${uri.host}';
    if (html.toLowerCase().contains('<base')) return html; // already present
    final match =
        RegExp('<head[^>]*>', caseSensitive: false).firstMatch(html);
    if (match != null) {
      return '${html.substring(0, match.end)}<base href="$origin">${html.substring(match.end)}';
    }
    return '<base href="$origin">$html'; // no <head> found — prepend
  }

  // ── Native scroll helpers ──────────────────────────────────────────────────

  void _onScrollChanged(InAppWebViewController c, int x, int y) {
    if (widget.bookId == null || _progressBox == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      final raw = await c.evaluateJavascript(
        source: 'document.body.scrollHeight.toString()',
      );
      final sh = double.tryParse(
              raw?.toString().replaceAll('"', '') ?? '') ??
          0;
      if (sh > 0) {
        final pct = (y / sh * 100).clamp(0, 100).toInt();
        unawaited(_progressBox!.put(_scrollKey, pct.toString()));
      }
    });
  }

  Future<void> _maybeRestoreScroll(InAppWebViewController c) async {
    if (widget.bookId == null) return;
    if (_savedScrollPercent == null || _savedScrollPercent! <= 0) return;
    if (_hasRestored) return;
    _hasRestored = true;

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final raw = await c.evaluateJavascript(
      source: 'document.body.scrollHeight.toString()',
    );
    final sh = double.tryParse(
            raw?.toString().replaceAll('"', '') ?? '') ??
        0;
    if (sh <= 0) return;
    await c.scrollTo(x: 0, y: (sh * _savedScrollPercent! / 100).toInt(),
        animated: true);
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
    // Web: blog article — fetch HTML and render inside the app via blob iframe.
    // kIsWeb is a compile-time constant so this entire branch is tree-shaken
    // out of the Android / iOS builds.
    if (kIsWeb && widget.sourceName != null) {
      return _buildWebArticle(context);
    }

    // Web: books (sourceName == null) — direct iframe (framing is permitted).
    // Native: all content — full InAppWebView with interception.
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    initialUrlRequest:
                        URLRequest(url: WebUri(widget.url)),
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

  // ── Web article scaffold ───────────────────────────────────────────────────

  Widget _buildWebArticle(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        // Subtle gold progress bar while the proxy fetch is in-flight.
        bottom: _webFetching
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  color: AppTheme.gold,
                  backgroundColor: Colors.transparent,
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(child: _webArticleBody(context)),
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

  Widget _webArticleBody(BuildContext context) {
    // ── Article loaded: render inside the app via blob iframe ──────────────
    if (_fetchedHtml != null) {
      return WebIframeView(
        url: widget.url,
        title: widget.title,
        htmlContent: _fetchedHtml,
      );
    }

    // ── Fetching: gold spinner ─────────────────────────────────────────────
    if (_webFetching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: AppTheme.gold,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading article…',
              style: TextStyle(
                color: AppTheme.textMuted(context),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // ── Both proxies failed: retry / open-in-browser ───────────────────────
    if (!_webFailed) return const SizedBox.shrink();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: AppTheme.textMuted(context)),
            const SizedBox(height: 16),
            Text(
              'Could not load article',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'The article could not be loaded inside Rumuo.',
              style: TextStyle(
                color: AppTheme.textMuted(context),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Retry the proxy fetch
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _loadArticleHtml,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Retry',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Hard fallback: open in the device browser
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(widget.url);
                if (uri != null) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
              icon: Icon(Icons.open_in_new_rounded,
                  size: 16, color: AppTheme.textMuted(context)),
              label: Text(
                'Open in browser',
                style: TextStyle(
                  color: AppTheme.textMuted(context),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
