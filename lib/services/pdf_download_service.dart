import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pdf_io_stub.dart' if (dart.library.io) 'pdf_io_io.dart' as pdf_io;

/// Downloads remote PDF files to the app's private documents directory.
/// On web, opens the remote URL in a new tab (no local cache).
class PdfDownloadService {
  PdfDownloadService._();

  static String _filename(String bookId) {
    final slug = bookId.replaceAll(RegExp('[^a-z0-9_]'), '_');
    return 'book_pdf_$slug.pdf';
  }

  static Future<bool> isDownloaded(String bookId) async {
    if (kIsWeb) return false;
    return pdf_io.exists(_filename(bookId));
  }

  static Future<String?> getLocalPath(String bookId) async {
    if (kIsWeb) return null;
    return pdf_io.localPath(_filename(bookId));
  }

  static Future<String?> downloadPdf({
    required String url,
    required String bookId,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        onProgress?.call(1.0);
        return url;
      }
      return null;
    }

    try {
      final existing = await pdf_io.localPath(_filename(bookId));
      if (existing != null) {
        onProgress?.call(1.0);
        return existing;
      }

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        final response = await client.send(request);
        if (response.statusCode != 200) return null;

        final total = response.contentLength ?? 0;
        var received = 0;
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
        }
        final path = await pdf_io.write(_filename(bookId), bytes);
        onProgress?.call(1.0);
        return path;
      } finally {
        client.close();
      }
    } on Object {
      return null;
    }
  }

  static Future<void> deleteCached(String bookId) async {
    if (kIsWeb) return;
    await pdf_io.delete(_filename(bookId));
  }
}
