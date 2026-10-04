import 'dart:typed_data';

import 'source_file_bytes_stub.dart'
    if (dart.library.io) 'source_file_bytes_io.dart'
    if (dart.library.html) 'source_file_bytes_web.dart' as impl;

bool isAppManagedSourcePath(String path) {
  final norm = path.replaceAll('\\', '/');
  return norm.startsWith('projects/');
}

Future<Uint8List> readSourceFileBytes(String path) =>
    impl.readSourceFileBytes(path);

Future<void> writeProjectMediaBytes(String relativePath, Uint8List bytes) =>
    impl.writeProjectMediaBytes(relativePath, bytes);

Future<void> copyFileIntoProjectMedia({
  required String sourceAbsolutePath,
  required String destRelativePath,
}) =>
    impl.copyFileIntoProjectMedia(
      sourceAbsolutePath: sourceAbsolutePath,
      destRelativePath: destRelativePath,
    );
