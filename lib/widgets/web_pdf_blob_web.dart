// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Create a blob: URL the browser can open in an iframe as a PDF.
Future<String> createPdfBlobUrl(Uint8List bytes) async {
  final parts = [bytes.toJS].toJS;
  final blob = web.Blob(
    parts,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  return web.URL.createObjectURL(blob);
}
