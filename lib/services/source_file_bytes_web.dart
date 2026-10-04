import 'dart:typed_data';

import 'app_storage.dart';

Future<Uint8List> readSourceFileBytes(String path) async {
  final bytes = await AppStorage.readBytes(path);
  if (bytes == null || bytes.isEmpty) {
    throw StateError('Missing source file: $path');
  }
  return bytes;
}

Future<void> writeProjectMediaBytes(String relativePath, Uint8List bytes) {
  return AppStorage.writeBytes(relativePath, bytes);
}

Future<void> copyFileIntoProjectMedia({
  required String sourceAbsolutePath,
  required String destRelativePath,
}) async {
  throw UnsupportedError(
    'copyFileIntoProjectMedia requires in-memory bytes on web',
  );
}
