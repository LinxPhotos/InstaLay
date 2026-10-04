import 'dart:typed_data';

Future<Uint8List> readSourceFileBytes(String path) {
  throw UnsupportedError('Source file IO is not available on this platform.');
}

Future<void> writeProjectMediaBytes(String relativePath, Uint8List bytes) {
  throw UnsupportedError('Source file IO is not available on this platform.');
}

Future<void> copyFileIntoProjectMedia({
  required String sourceAbsolutePath,
  required String destRelativePath,
}) {
  throw UnsupportedError('Source file IO is not available on this platform.');
}
