import 'dart:io';
import 'dart:typed_data';

import 'app_storage.dart';
import 'source_file_bytes.dart' show isAppManagedSourcePath;

Future<Uint8List> readSourceFileBytes(String path) async {
  if (isAppManagedSourcePath(path)) {
    final bytes = await AppStorage.readBytes(path);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Missing source file: $path');
    }
    return bytes;
  }
  return File(path).readAsBytes();
}

Future<void> writeProjectMediaBytes(String relativePath, Uint8List bytes) {
  return AppStorage.writeBytes(relativePath, bytes);
}

Future<void> copyFileIntoProjectMedia({
  required String sourceAbsolutePath,
  required String destRelativePath,
}) async {
  final bytes = await File(sourceAbsolutePath).readAsBytes();
  await AppStorage.writeBytes(destRelativePath, bytes);
}
