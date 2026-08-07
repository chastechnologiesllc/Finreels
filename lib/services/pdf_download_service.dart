import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads remote PDF files to the app's private documents directory and
/// exposes helpers to check the cache and open already-downloaded files.
///
/// All writes go to [getApplicationDocumentsDirectory] — no external storage
/// permission is required on any supported Android / iOS version.
class PdfDownloadService {
  PdfDownloadService._();

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Converts a book ID into a safe filename, e.g.
  /// "vbook_general_the_e_myth_revisited" → "book_pdf_vbook_general_the_e...pdf"
  static String _filename(String bookId) {
    final slug = bookId.replaceAll(RegExp('[^a-z0-9_]'), '_');
    return 'book_pdf_$slug.pdf';
  }

  static Future<File> _file(String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/${_filename(bookId)}');
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns `true` if a PDF for [bookId] has already been downloaded and
  /// the cached file still exists on disk.
  static Future<bool> isDownloaded(String bookId) async {
    return (await _file(bookId)).existsSync();
  }

  /// Returns the absolute path to the cached PDF if it exists, otherwise null.
  /// Use this on screen init so the UI can immediately show "Open" instead of
  /// "Download" for books the user has already fetched.
  static Future<String?> getLocalPath(String bookId) async {
    final f = await _file(bookId);
    return f.existsSync() ? f.path : null;
  }

  /// Downloads the PDF at [url] to the app's documents directory.
  ///
  /// - [onProgress] fires repeatedly with a value in [0.0, 1.0].  When the
  ///   server doesn't send a Content-Length header the value stays at 0.0
  ///   until the download completes, then jumps to 1.0.
  /// - Returns the local file path on success, or `null` if the download
  ///   fails (network error, non-200 status, or write error).
  /// - If the file already exists it is returned immediately without
  ///   re-downloading.
  static Future<String?> downloadPdf({
    required String url,
    required String bookId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final file = await _file(bookId);

      // ── Serve from cache if already present ────────────────────────────────
      if (file.existsSync()) {
        onProgress?.call(1.0);
        return file.path;
      }

      // ── Stream the download ────────────────────────────────────────────────
      final client = http.Client();
      try {
        final request  = http.Request('GET', Uri.parse(url));
        final response = await client.send(request);

        if (response.statusCode != 200) return null;

        final total    = response.contentLength ?? 0;
        var   received = 0;

        final sink = file.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            onProgress?.call((received / total).clamp(0.0, 1.0));
          }
        }
        await sink.close();

        onProgress?.call(1.0);
        return file.path;
      } finally {
        client.close();
      }
    } on Object catch (_) {
      return null;
    }
  }

  /// Deletes the locally cached PDF for [bookId].  Safe to call even if the
  /// file does not exist.  Useful for a "clear downloads" settings option.
  static Future<void> deleteCached(String bookId) async {
    final f = await _file(bookId);
    if (f.existsSync()) f.deleteSync();
  }
}
