import 'dart:io';

import 'app_storage.dart';
import 'source_file_bytes.dart' show isAppManagedSourcePath;

Future<bool> storedPathExists(String path) async {
  if (isAppManagedSourcePath(path)) {
    return AppStorage.exists(path);
  }
  return File(path).exists();
}
