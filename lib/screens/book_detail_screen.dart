import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/book_insights_data.dart';
import '../data/category_playbook_data.dart';
import '../models/video.dart';
import '../services/ad_service.dart';
import '../services/engagement_service.dart';
import '../services/pdf_download_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/book_cover_image.dart';
import 'blog_reader_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Source routing — Richest Man + 3 others use EPUB; copyrighted books use
// in-app insights; the two Five Buckets playbooks are bundled PDF assets.
// ─────────────────────────────────────────────────────────────────────────────

enum _SourceType { epub, insights, pdfAsset, externalUrl }

class _BookSource {
  final _SourceType type;
  final String? epubUrl;
  final String? assetPath;
  const _BookSource.epub(this.epubUrl)
      : type = _SourceType.epub, assetPath = null;
  const _BookSource.insights()
      : type = _SourceType.insights, epubUrl = null, assetPath = null;
  const _BookSource.pdfAsset(this.assetPath)
      : type = _SourceType.pdfAsset, epubUrl = null;
  /// Verified category books — URL is opened via BlogReaderScreen (WebView)
  /// or, when the URL points directly to a PDF, downloaded to local storage
  /// and opened with flutter_pdfview.  [epubUrl] stores the source URL.
  const _BookSource.externalUrl(this.epubUrl)
      : type = _SourceType.externalUrl, assetPath = null;
}

const Map<String, _BookSource> _sources = {
  // ── Project Gutenberg — public domain, no login ──────────────────────────
  'book_richest_man': _BookSource.epub(
    'https://www.gutenberg.org/cache/epub/1297/pg1297-images.epub',
  ),
  'book_as_man_thinketh': _BookSource.epub(
    'https://www.gutenberg.org/cache/epub/4507/pg4507-images.epub',
  ),
  'book_science_rich': _BookSource.epub(
    'https://www.gutenberg.org/cache/epub/59844/pg59844-images.epub',
  ),
  'book_popular_delusions': _BookSource.epub(
    'https://www.gutenberg.org/cache/epub/636/pg636-images.epub',
  ),
  // ── Global Grey — public domain, direct EPUB, no login ──────────────────
  'book_think_grow': _BookSource.epub(
    'https://www.globalgreyebooks.com/ebooks/napoleon-hill_think-and-grow-rich.epub',
  ),
  'book_art_money': _BookSource.epub(
    'https://www.globalgreyebooks.com/ebooks/p-t-barnum_art-of-money-getting.epub',
  ),
  'book_eight_pillars': _BookSource.epub(
    'https://www.globalgreyebooks.com/ebooks/james-allen_eight-pillars-of-prosperity.epub',
  ),
  'book_master_key': _BookSource.epub(
    'https://www.globalgreyebooks.com/ebooks/charles-f-haanel_master-key-system.epub',
  ),
  // ── Bundled PDF assets — ship inside the app, always available offline ──
  'book_five_buckets_playbook': _BookSource.pdfAsset(
    'assets/books/five_buckets_playbook.pdf',
  ),
  'book_five_buckets_complete': _BookSource.pdfAsset(
    'assets/books/five_buckets_complete.pdf',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class BookDetailScreen extends StatefulWidget {
  final Video book;
  const BookDetailScreen({required this.book, super.key});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _showReader = false;
  bool _isLoading  = true;

  // EPUB
  final EpubController _epubController = EpubController();
  String? _lastCfi;
  Box<String>? _progressBox;

  // PDF (bundled asset books)
  int? _lastPdfPage;

  // WebView books — scroll progress (0–100 integer %)
  int? _lastWebScroll;

  // Downloadable PDF books — download state + cached local path
  bool   _isDownloading     = false;
  double _downloadProgress  = 0.0;
  String? _localPdfPath;

  _BookSource get _source {
    final known = _sources[widget.book.id];
    if (known != null) return known;
    // Verified category books carry their free URL in freeSourceUrl.
    // Route them to the external reader rather than the insights fallback.
    final url = widget.book.freeSourceUrl;
    if (url != null && url.trim().isNotEmpty) {
      return _BookSource.externalUrl(url);
    }
    return const _BookSource.insights();
  }

  String get _progressKey    => 'epub_cfi_${widget.book.id}';
  String get _pdfProgressKey => 'pdf_page_${widget.book.id}';
  String get _webScrollKey   => 'webview_scroll_${widget.book.id}';

  /// True when the URL is a direct PDF file that can be downloaded and
  /// opened natively in flutter_pdfview.
  bool _isPdfUrl(String url) =>
      url.toLowerCase().endsWith('.pdf') ||
      RegExp(r'\.pdf[\?#]').hasMatch(url.toLowerCase());

  /// True if the user has made any reading progress on this book,
  /// regardless of which reader type it uses.
  bool get _hasProgress =>
      (_lastCfi != null && _lastCfi!.isNotEmpty) ||
      (_lastPdfPage != null && _lastPdfPage! > 0) ||
      (_lastWebScroll != null && _lastWebScroll! > 0);

  @override
  void initState() {
    super.initState();
    if (CategoryPlaybookData.isPlaybookId(widget.book.id)) {
      final categoryId = widget.book.id.replaceFirst('playbook_', '');
      unawaited(EngagementService.instance.recordCategoryInterest(categoryId));
    }
    _progressBox   = Hive.box<String>('reading_progress');
    _lastCfi       = _progressBox?.get(_progressKey);
    _lastPdfPage   = int.tryParse(_progressBox?.get(_pdfProgressKey) ?? '');
    _lastWebScroll = int.tryParse(_progressBox?.get(_webScrollKey) ?? '');
    // Check if a PDF was previously downloaded for this book so we can
    // show "Open Downloaded Book" instead of "Download Free Book" immediately.
    _checkLocalPdf();
  }

  /// Async check — runs after initState; updates UI once the file lookup
  /// completes without blocking the initial frame.
  Future<void> _checkLocalPdf() async {
    final url = widget.book.freeSourceUrl ?? '';
    if (!_isPdfUrl(url)) return;
    final path = await PdfDownloadService.getLocalPath(widget.book.id);
    if (path != null && mounted) setState(() => _localPdfPath = path);
  }

  // ── External book handler (async, called from CTA onPressed) ──────────────

  Future<void> _handleExternalBook() async {
    final url = _source.epubUrl ?? '';

    // ── Case 1: direct PDF URL ────────────────────────────────────────────
    if (_isPdfUrl(url)) {
      // Already downloaded → go straight to the reader
      if (_localPdfPath != null) {
        unawaited(AdService.instance.onBookRead());
        setState(() { _showReader = true; _isLoading = true; });
        return;
      }

      // Start download with progress UI
      unawaited(AdService.instance.onBookRead());
      setState(() { _isDownloading = true; _downloadProgress = 0.0; });

      final path = await PdfDownloadService.downloadPdf(
        url: url,
        bookId: widget.book.id,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );

      if (!mounted) return;

      if (path != null) {
        // Download succeeded → open the PDF reader in-place
        setState(() {
          _localPdfPath    = path;
          _isDownloading   = false;
          _showReader      = true;
          _isLoading       = true;
        });
      } else {
        // Download failed → fall back to the in-app WebView
        setState(() => _isDownloading = false);
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BlogReaderScreen(
            url: url,
            title: widget.book.title,
            categoryId: widget.book.sourceCategoryId,
            bookId: widget.book.id,
          ),
        ));
        _refreshWebScrollProgress();
      }
      return;
    }

    // ── Case 2: web URL (article, borrow page, author site, etc.) ─────────
    unawaited(AdService.instance.onBookRead());
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlogReaderScreen(
        url: url,
        title: widget.book.title,
        categoryId: widget.book.sourceCategoryId,
        bookId: widget.book.id,
      ),
    ));
    _refreshWebScrollProgress();
  }

  /// Re-reads the WebView scroll key from Hive so that returning from
  /// BlogReaderScreen immediately updates the "Continue reading" badge.
  void _refreshWebScrollProgress() {
    if (!mounted) return;
    setState(() {
      _lastWebScroll =
          int.tryParse(_progressBox?.get(_webScrollKey) ?? '');
    });
  }

  // ── CTA label / icon / caption helpers ────────────────────────────────────

  String get _ctaLabel {
    if (_source.type != _SourceType.externalUrl) {
      return _hasProgress ? 'Continue Reading' : 'Read Full Book Free';
    }
    // Downloaded PDF — show reading state
    if (_localPdfPath != null) {
      return _hasProgress ? 'Continue Reading' : 'Open Downloaded Book';
    }
    // Direct PDF that needs downloading
    if (_isPdfUrl(widget.book.freeSourceUrl ?? '')) {
      return 'Download Free Book';
    }
    // Web / article URL
    return _hasProgress ? 'Continue Reading' : 'Read Free Online';
  }

  IconData get _ctaIcon {
    if (_source.type == _SourceType.externalUrl) {
      if (_localPdfPath == null &&
          _isPdfUrl(widget.book.freeSourceUrl ?? '')) {
        return Icons.download_rounded;
      }
    }
    return Icons.menu_book_rounded;
  }

  String get _ctaCaption {
    switch (_source.type) {
      case _SourceType.pdfAsset:
        return 'Included free with FinReels — no internet required';
      case _SourceType.externalUrl:
        if (_localPdfPath != null) {
          return 'Saved on this device — no internet required';
        }
        if (_isPdfUrl(widget.book.freeSourceUrl ?? '')) {
          return 'Downloads once, then reads offline — always free';
        }
        return 'Opens in built-in reader · stays inside FinReels';
      case _SourceType.epub:
        if (widget.book.id.startsWith('book_richest') ||
            widget.book.id.startsWith('book_as_man') ||
            widget.book.id.startsWith('book_science') ||
            widget.book.id.startsWith('book_popular')) {
          return 'Reads free via Project Gutenberg (public domain)';
        }
        return 'Reads free via Global Grey ebooks (public domain)';
      case _SourceType.insights:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showReader) return _buildReader();
    return _buildDetail();
  }

  // ── Detail / landing page ──────────────────────────────────────────────────

  Widget _buildDetail() {
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(title: const Text('Free Book')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover + meta
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookCoverImage(
                        url: widget.book.thumbnailUrl,
                        width: 110,
                        height: 160,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '📚 FREE BOOK',
                                style: TextStyle(
                                    color: AppTheme.gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(widget.book.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.35)),
                            const SizedBox(height: 6),
                            Text(widget.book.channelName,
                                style: TextStyle(
                                    color: AppTheme.textMuted(context),
                                    fontSize: 12)),
                            if (_hasProgress &&
                                _source.type != _SourceType.insights) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.success
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Continue reading',
                                    style: TextStyle(
                                        color: AppTheme.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  Text('About this book',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.gold, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(widget.book.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.6)),

                  const SizedBox(height: 32),

                  // Primary CTA
                  // ── CTA — varies by source type & download state ──────────
                  if (_isDownloading)
                    // Download progress indicator (only for direct-PDF books)
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: _downloadProgress,
                                  strokeWidth: 5,
                                  backgroundColor:
                                      AppTheme.gold.withValues(alpha: 0.18),
                                  valueColor: const AlwaysStoppedAnimation(
                                      AppTheme.gold),
                                ),
                                Text(
                                  '${(_downloadProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppTheme.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Downloading PDF…',
                            style: TextStyle(
                                color: AppTheme.textMuted(context),
                                fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (_source.type == _SourceType.externalUrl) {
                            unawaited(_handleExternalBook());
                            return;
                          }
                          unawaited(AdService.instance.onBookRead());
                          setState(() {
                            _showReader = true;
                            _isLoading  = true;
                          });
                        },
                        icon: Icon(_ctaIcon),
                        label: Text(
                          _ctaLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      _ctaCaption,
                      style: TextStyle(
                          color: AppTheme.textMuted(context), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListenableBuilder(
            listenable: AdService.instance,
            builder: (_, __) => AdService.instance.adsRemoved
                ? const SizedBox.shrink()
                : const LabelledBannerAd(),
          ),
        ],
      ),
    );
  }

  // ── Reader router ──────────────────────────────────────────────────────────

  Widget _buildReader() {
    if (_source.type == _SourceType.epub) {
      return _buildEpubReader(_source.epubUrl!);
    }
    if (_source.type == _SourceType.pdfAsset) {
      return _buildPdfReader(_source.assetPath!);
    }
    // Downloaded PDF for verified books with a direct PDF URL
    if (_localPdfPath != null) {
      return _buildLocalPdfReader(_localPdfPath!);
    }
    return _buildInsightsReader();
  }

  // ── EPUB reader ────────────────────────────────────────────────────────────

  Widget _buildEpubReader(String url) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title.split('—').first.trim(),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() {
            _showReader = false;
            _isLoading  = true;
          }),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                EpubViewer(
                  epubSource: EpubSource.fromUrl(url),
                  epubController: _epubController,
                  displaySettings: EpubDisplaySettings(
                    flow: EpubFlow.scrolled,
                    snap: false,
                    allowScriptedContent: true,
                  ),
                  onEpubLoaded: () async {
                    if (mounted) setState(() => _isLoading = false);
                    if (_lastCfi != null && _lastCfi!.isNotEmpty) {
                      _epubController.display(cfi: _lastCfi!);
                    }
                  },
                  onChaptersLoaded: (_) {
                    if (mounted) setState(() => _isLoading = false);
                  },
                  onRelocated: (location) {
                    if (!mounted) return;
                    final cfi = location.startCfi;
                    if (cfi.isNotEmpty) {
                      _lastCfi = cfi;
                      _progressBox?.put(_progressKey, cfi);
                    }
                  },
                  onTextSelected: (_) {},
                ),
                if (_isLoading)
                  const Center(
                      child: CircularProgressIndicator(color: AppTheme.gold)),
              ],
            ),
          ),
          // Banner ad inside reader
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

  // ── PDF reader (bundled asset books) ────────────────────────────────────────

  Widget _buildPdfReader(String assetPath) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title.split(':').first.trim(),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() {
            _showReader = false;
            _isLoading  = true;
          }),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<Uint8List>(
              // Load the bundled PDF bytes once. Bundled assets are
              // instant to read (no network), but we still show a spinner
              // for the brief decode time on lower-end devices.
              future: rootBundle.load(assetPath).then((d) => d.buffer
                  .asUint8List(d.offsetInBytes, d.lengthInBytes)),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.gold),
                  );
                }
                return Stack(
                  children: [
                    PDFView(
                      pdfData: snapshot.data,
                      defaultPage: _lastPdfPage ?? 0,
                      nightMode:
                          Theme.of(context).brightness == Brightness.dark,
                      onRender: (_) {
                        if (mounted) setState(() => _isLoading = false);
                      },
                      onPageChanged: (page, total) {
                        if (page == null) return;
                        _lastPdfPage = page;
                        _progressBox?.put(_pdfProgressKey, page.toString());
                      },
                      onError: (error) {
                        if (mounted) setState(() => _isLoading = false);
                      },
                    ),
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(color: AppTheme.gold),
                      ),
                  ],
                );
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

  // ── Local (downloaded) PDF reader ──────────────────────────────────────────

  Widget _buildLocalPdfReader(String filePath) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title.split('—').first.trim(),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() {
            _showReader = false;
            _isLoading  = true;
          }),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<Uint8List>(
              future: File(filePath).readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.gold, size: 40),
                        const SizedBox(height: 12),
                        Text('Could not open the PDF.',
                            style: TextStyle(
                                color: AppTheme.textSecondary(context))),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.gold),
                  );
                }
                return Stack(
                  children: [
                    PDFView(
                      pdfData: snapshot.data,
                      defaultPage: _lastPdfPage ?? 0,
                      nightMode: Theme.of(context).brightness ==
                          Brightness.dark,
                      onRender: (_) {
                        if (mounted) setState(() => _isLoading = false);
                      },
                      onPageChanged: (page, _) {
                        if (page == null) return;
                        _lastPdfPage = page;
                        _progressBox?.put(_pdfProgressKey, page.toString());
                      },
                      onError: (_) {
                        if (mounted) setState(() => _isLoading = false);
                      },
                    ),
                    if (_isLoading)
                      const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.gold),
                      ),
                  ],
                );
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

  Widget _buildInsightsReader() {
    final insight = CategoryPlaybookData.findAnyInsight(widget.book.id);

    if (insight == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.book.title.split('—').first.trim()),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => _showReader = false),
          ),
        ),
        body: const Center(child: Text('Content coming soon.')),
      );
    }

    return _InsightsReaderScreen(
      insight: insight,
      onBack: () => setState(() => _showReader = false),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Insights reader — standalone stateful widget
// ─────────────────────────────────────────────────────────────────────────────

class _InsightsReaderScreen extends StatefulWidget {
  final BookInsightData insight;
  final VoidCallback onBack;
  const _InsightsReaderScreen({required this.insight, required this.onBack});

  @override
  State<_InsightsReaderScreen> createState() => _InsightsReaderScreenState();
}

class _InsightsReaderScreenState extends State<_InsightsReaderScreen> {
  final int _adEveryN = 4;

  Future<void> _openPurchaseLink() async {
    final uri = Uri.parse(widget.insight.purchaseUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final insight = widget.insight;

    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? AppTheme.darkText : AppTheme.lightText),
          onPressed: widget.onBack,
        ),
        title: Text(
          insight.title.split('—').first.replaceAll(r'$', r'\$').trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
              fontWeight: FontWeight.w700,
              fontSize: 17),
        ),
        actions: [
          if (insight.purchaseUrl.isNotEmpty)
            IconButton(
              tooltip: 'Get full book',
              icon: const Icon(Icons.shopping_bag_outlined, color: AppTheme.gold),
              onPressed: _openPurchaseLink,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // ── Intro card ───────────────────────────────────────────
                _IntroCard(insight: insight),
                const SizedBox(height: 24),

                // ── Chapter tiles ────────────────────────────────────────
                ...List.generate(insight.chapters.length, (i) {
                  final chapter = insight.chapters[i];
                  final widgets = <Widget>[
                    _ChapterCard(chapter: chapter, isDark: isDark),
                    const SizedBox(height: 16),
                  ];

                  // Insert inline banner ad every _adEveryN chapters
                  if (!AdService.instance.adsRemoved &&
                      (i + 1) % _adEveryN == 0 &&
                      i != insight.chapters.length - 1) {
                    widgets.add(ListenableBuilder(
                      listenable: AdService.instance,
                      builder: (_, __) => AdService.instance.adsRemoved
                          ? const SizedBox.shrink()
                          : const Column(mainAxisSize: MainAxisSize.min, children: [
                              StickyBannerBar(),
                              SizedBox(height: 16),
                            ]),
                    ));
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widgets,
                  );
                }),

                // ── Buy the full book CTA (only when there's a real book) ─
                if (insight.purchaseUrl.isNotEmpty)
                  _BuyFullBookCard(
                    insight: insight,
                    onTap: _openPurchaseLink,
                  ),
              ],
            ),
          ),

          // Sticky banner at bottom of reader
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

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _IntroCard extends StatelessWidget {
  final BookInsightData insight;
  const _IntroCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.gold.withValues(alpha: 0.20), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('KEY INSIGHTS',
                    style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'by ${insight.author}',
            style: const TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            insight.intro,
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatefulWidget {
  final BookChapter chapter;
  final bool isDark;
  const _ChapterCard({required this.chapter, required this.isDark});

  @override
  State<_ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<_ChapterCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _expanded
                ? AppTheme.gold.withValues(alpha: 0.35)
                : AppTheme.dividerColor(context),
            width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (always visible)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.chapter.title,
                      style: TextStyle(
                        color: widget.isDark
                            ? AppTheme.darkText
                            : AppTheme.lightText,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.gold,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Expanded body
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                widget.chapter.body,
                style: TextStyle(
                  color: widget.isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ),
            if (widget.chapter.keyPoints.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text('Key Takeaways',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    )),
              ),
              ...widget.chapter.keyPoints.map(
                (pt) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle,
                            color: AppTheme.gold, size: 6),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(pt,
                            style: TextStyle(
                              color: widget.isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                              fontSize: 13,
                              height: 1.5,
                            )),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _BuyFullBookCard extends StatelessWidget {
  final BookInsightData insight;
  final VoidCallback onTap;
  const _BuyFullBookCard({required this.insight, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.gold.withValues(alpha: 0.15),
            AppTheme.gold.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.gold.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.menu_book_rounded, color: AppTheme.gold, size: 36),
          const SizedBox(height: 12),
          const Text('Enjoyed the insights?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'Get the full book to read every chapter, '
            'story, and example in detail.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.shopping_bag_rounded, size: 18),
              label: const Text('Get Full Book on Amazon',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll leave FinReels to open Amazon',
            style: TextStyle(
                color: AppTheme.textMuted(context), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
