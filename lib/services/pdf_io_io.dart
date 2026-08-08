import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> _path(String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/$filename';
}

Future<bool> exists(String filename) async {
  final f = File(await _path(filename));
  return f.existsSync();
}

Future<String?> localPath(String filename) async {
  final f = File(await _path(filename));
  return f.existsSync() ? f.path : null;
}

Future<String?> write(String filename, List<int> bytes) async {
  final f = File(await _path(filename));
  await f.writeAsBytes(bytes, flush: true);
  return f.path;
}

Future<void> delete(String filename) async {
  final f = File(await _path(filename));
  if (f.existsSync()) f.deleteSync();
}

/// Read an absolute file path (used by local PDF viewer).
Future<Uint8List> readBytes(String absolutePath) async {
  return File(absolutePath).readAsBytes();
}
