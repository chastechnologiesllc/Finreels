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
  final String url;
  final String title;

  const BookContentReaderScreen({
    required this.url,
    required this.title,
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
    final encoded = Uri.encodeComponent(widget.url);
    final direct = widget.url;
    final candidates = <String>[
      if (kIsWeb) ...[
        'https://corsproxy.io/?url=$encoded',
        'https://api.allorigins.win/raw?url=$encoded',
      ],
      direct,
      if (!kIsWeb) ...[
        'https://corsproxy.io/?url=$encoded',
        'https://api.allorigins.win/raw?url=$encoded',
      ],
    ];

    Object? lastError;
    final attempted = <String>{};
    for (final candidate in candidates) {
      if (!attempted.add(candidate)) continue;
      try {
        final response = await http.get(Uri.parse(candidate), headers: {
          'Accept': 'text/html, text/plain;q=0.9, application/xhtml+xml',
          'User-Agent': 'FinReels/1.0 (+com.chastechgroup.finreels)',
        }).timeout(const Duration(seconds: 18));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          lastError = StateError('HTTP ${response.statusCode}');
          continue;
        }

        final body = utf8.decode(response.bodyBytes, allowMalformed: true);
        final contentType = response.headers['content-type'] ?? '';
        final plain = BookReaderContent.looksLikePlainText(
          widget.url,
          contentType,
          body,
        );
        return _LoadedBookContent(
          isPlainText: plain,
          body: plain ? body : BookReaderContent.sanitizeHtml(body),
        );
      } on Object catch (error) {
        lastError = error;
      }
    }

    throw StateError(
      'The book could not be loaded. ${lastError ?? 'No readable response.'}',
    );
  }

  

  Future<void> _openLink(String? href) async {
    final raw = href?.trim() ?? '';
    if (raw.isEmpty) return;
    final parsed = Uri.tryParse(raw);
    if (parsed != null) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
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
                    'Preparing readable book text…',
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
              onPressed: () async {
                final uri = Uri.tryParse(widget.url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
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
