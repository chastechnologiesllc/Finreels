import 'dart:typed_data';

Future<bool> exists(String filename) async => false;
Future<String?> localPath(String filename) async => null;
Future<String?> write(String filename, List<int> bytes) async => null;
Future<void> delete(String filename) async {}

Future<Uint8List> readBytes(String absolutePath) async {
  throw UnsupportedError('Local PDF files are not available on web');
}
