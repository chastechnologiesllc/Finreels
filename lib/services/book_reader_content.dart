/// Pure helpers shared by the book reader and its regression tests.
class BookReaderContent {
  BookReaderContent._();

  static bool looksLikePlainText(
    String url,
    String contentType,
    String body,
  ) {
    final lowerUrl = url.toLowerCase();
    final lowerType = contentType.toLowerCase();
    if (lowerUrl.endsWith('.txt') || lowerUrl.contains('.txt?')) return true;
    if (lowerType.contains('text/plain')) return true;
    return !RegExp(r'<\s*(html|body|p|div|h1|h2|pre)\b',
            caseSensitive: false)
        .hasMatch(body);
  }

  /// Maps known book landing/download URLs to the readable source body.
  /// Returning the original URL is intentional for ordinary HTML/TXT pages.
  static String readableUrl(String bookUrl) {
    final landing = RegExp(r'gutenberg\.org/ebooks/(\d+)', caseSensitive: false)
        .firstMatch(bookUrl);
    if (landing != null) {
      final id = landing.group(1)!;
      return 'https://www.gutenberg.org/cache/epub/$id/pg${id}-images.html';
    }

    final gut = RegExp(r'gutenberg\.org/cache/epub/(\d+)/', caseSensitive: false)
        .firstMatch(bookUrl);
    if (gut != null) {
      final id = gut.group(1)!;
      return 'https://www.gutenberg.org/cache/epub/$id/pg${id}-images.html';
    }

    final gg = RegExp(
      r'globalgreyebooks\.com/ebooks/([^/]+)\.epub',
      caseSensitive: false,
    ).firstMatch(bookUrl);
    if (gg != null) {
      return 'https://www.globalgreyebooks.com/${gg.group(1)}.html';
    }
    return bookUrl;
  }

  /// Removes publisher CSS/chrome while preserving semantic book markup.
  static String sanitizeHtml(String html) {
    var content = html;
    final bodyMatch = RegExp(
      r'<body[^>]*>([\s\S]*?)</body>',
      caseSensitive: false,
    ).firstMatch(content);
    if (bodyMatch != null) content = bodyMatch.group(1) ?? content;

    for (final tag in const [
      'script',
      'style',
      'noscript',
      'iframe',
      'object',
      'embed',
      'nav',
      'header',
      'footer',
    ]) {
      content = content.replaceAll(
        RegExp('<$tag[^>]*>[\\s\\S]*?</$tag>', caseSensitive: false),
        '',
      );
    }
    content = content
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll(RegExp(r'\sstyle\s*=\s*"[^"]*"', caseSensitive: false), '')
        .replaceAll(RegExp(r"\sstyle\s*=\s*'[^']*'", caseSensitive: false), '')
        .replaceAll(RegExp(r'\s(bgcolor|background)\s*=\s*"[^"]*"', caseSensitive: false), '')
        .replaceAll(RegExp(r"\s(bgcolor|background)\s*=\s*'[^']*'", caseSensitive: false), '');
    return '<div>$content</div>';
  }
}
