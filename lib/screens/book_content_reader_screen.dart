import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/book_reader_content.dart';
import '../theme/app_theme.dart';

/// A controlled reader for remote HTML and plain-text books.
///
/// It deliberately renders the document in Flutter instead of embedding the
/// publisher page in a WebView/iframe. That prevents publisher backgrounds,
/// boilerplate metadata, and dark-mode CSS from obscuring the actual book text
/// on Web, Android, and iOS.
class BookContentReaderScreen extends StatefulWidget {
  /// URL used for controlled reading. It can be a mapped HTML mirror rather
  /// than the publisher/catalog URL shown to the user.
  final String url;
  final String title;
  final String? sourceUrl;

  const BookContentReaderScreen({
    required this.url,
    required this.title,
    this.sourceUrl,
    super.key,
  });

  @override
  State<BookContentReaderScreen> createState() =>
      _BookContentReaderScreenState();
}

class _BookContentReaderScreenState extends State<BookContentReaderScreen> {
  _LoadedBookContent? _content;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final loaded = await _fetchContent();
      if (!mounted) return;
      setState(() {
        _content = loaded;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<_LoadedBookContent> _fetchContent() async {
    final targets = BookReaderContent.sourceCandidates(
      widget.url,
      widget.sourceUrl,
    );
    final candidates = <String>[
      if (kIsWeb)
        for (final target in targets) ...[
          'https://api.allorigins.win/raw?url=${Uri.encodeComponent(target)}',
          'https://corsproxy.io/?url=${Uri.encodeComponent(target)}',
        ],
      ...targets,
      if (!kIsWeb)
        for (final target in targets) ...[
          'https://api.allorigins.win/raw?url=${Uri.encodeComponent(target)}',
          'https://corsproxy.io/?url=${Uri.encodeComponent(target)}',
        ],
    ];
    final unique = candidates.toSet().toList();

    // Concurrent race — every candidate starts simultaneously, first valid
    // response wins. Previously these were tried sequentially, each with its
    // own 18s timeout; a single slow/hanging proxy could burn the full 18s
    // before the next candidate was even attempted, so a book needing
    // several fallbacks could take over a minute with no feedback beyond a
    // static spinner. Racing bounds real-world wait to one timeout window,
    // matching the pattern already proven in RssService._tryFetchWeb().
    final completer = Completer<_LoadedBookContent>();
    var pending = unique.length;
    Object? lastError;

    for (final candidate in unique) {
      unawaited(() async {
        try {
          final response = await http.get(Uri.parse(candidate), headers: {
            'Accept': 'text/html, text/plain;q=0.9, application/xhtml+xml',
            'User-Agent': 'FinReels/1.0 (+com.chastechgroup.finreels)',
          }).timeout(const Duration(seconds: 25));

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            final body =
                utf8.decode(response.bodyBytes, allowMalformed: true);
            final contentType = response.headers['content-type'] ?? '';
            final plain = BookReaderContent.looksLikePlainText(
              widget.url,
              contentType,
              body,
            );
            if (!completer.isCompleted) {
              completer.complete(_LoadedBookContent(
                isPlainText: plain,
                body: plain ? body : BookReaderContent.sanitizeHtml(body),
              ));
              return; // Skip pending decrement; completer is resolved.
            }
          } else {
            lastError = StateError('HTTP ${response.statusCode}');
          }
        } on Object catch (error) {
          lastError = error;
        }
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.completeError(StateError(
            'The book could not be loaded. ${lastError ?? 'No readable response.'}',
          ));
        }
      }());
    }

    return completer.future;
  }

  

  Future<void> _openLink(String? href) async {
    final raw = href?.trim() ?? '';
    if (raw.isEmpty) return;
    final parsed = Uri.tryParse(raw);
    if (parsed != null) {
      await launchUrl(parsed, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _openSource() async {
    final candidates = <Uri>[];
    // Try the direct readable content URL first — landing pages require an
    // extra click to actually reach the book, which defeats the point of
    // this fallback. widget.sourceUrl (the original/landing page) is only
    // tried second, in case the mapped URL itself can't be launched.
    for (final raw in [widget.url, widget.sourceUrl]) {
      final uri = Uri.tryParse(raw?.trim() ?? '');
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        continue;
      }
      if (!candidates.contains(uri)) candidates.add(uri);
    }
    for (final uri in candidates) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return;
      } on Object catch (_) {
        // Try the mapped reader URL if the original source cannot be opened.
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this book source.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = AppTheme.bgColor(context);
    final textColor = AppTheme.textColor(context);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Reload book',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.gold),
                  const SizedBox(height: 16),
                  Text(
                    'Preparing readable book text… longer books can take a '
                    'little while',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted(context)),
                  ),
                ],
              ),
            )
          : _error != null
              ? _buildError(context)
              : ColoredBox(
                  color: background,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 120),
                    child: _content!.isPlainText
                        ? SelectableText(
                            _content!.body,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              height: 1.65,
                            ),
                          )
                        : Html(
                            data: _content!.body,
                            shrinkWrap: true,
                            onLinkTap: (url, _, __) => unawaited(_openLink(url)),
                            style: {
                              'body': Style(
                                color: textColor,
                                backgroundColor: background,
                                fontSize: FontSize(16),
                              ),
                              'p': Style(
                                color: textColor,
                                fontSize: FontSize(16),
                              ),
                              'h1': Style(
                                color: textColor,
                                fontSize: FontSize(26),
                              ),
                              'h2': Style(
                                color: textColor,
                                fontSize: FontSize(22),
                              ),
                              'h3': Style(
                                color: textColor,
                                fontSize: FontSize(19),
                              ),
                              'a': Style(color: AppTheme.gold),
                              'pre': Style(
                                color: textColor,
                                fontSize: FontSize(14),
                              ),
                            },
                          ),
                  ),
                ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded,
                size: 52, color: AppTheme.textMuted(context)),
            const SizedBox(height: 16),
            Text(
              'This book could not be prepared for reading.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Try again or open the verified source in your browser.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted(context)),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openSource,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open source'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadedBookContent {
  final bool isPlainText;
  final String body;

  const _LoadedBookContent({required this.isPlainText, required this.body});
}
