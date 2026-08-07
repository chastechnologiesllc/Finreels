import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';

import '../services/ad_service.dart';
import '../services/engagement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';

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
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.bookmark_rounded, color: AppTheme.gold, size: 16),
            SizedBox(width: 8),
            Text('Resuming from where you left off'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
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
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                allowsInlineMediaPlayback: true,
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
              // Block navigation away from the article's origin domain
              shouldOverrideUrlLoading: (_, action) async {
                final uri = action.request.url;
                if (uri == null) return NavigationActionPolicy.CANCEL;
                final host = uri.host;
                if (host == _allowedHost ||
                    host.endsWith('.$_allowedHost') ||
                    _allowedHost.isEmpty) {
                  return NavigationActionPolicy.ALLOW;
                }
                return NavigationActionPolicy.CANCEL;
              },
            ),
          ),
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
