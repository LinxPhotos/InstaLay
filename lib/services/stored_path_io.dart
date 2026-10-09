import 'dart:io';

import 'app_storage.dart';
import 'source_file_bytes.dart' show isAppManagedSourcePath;

Future<bool> storedPathExists(String path) async {
  if (isAppManagedSourcePath(path)) {
    return AppStorage.exists(path);
  }
  return File(path).exists();
}

Future<int?> storedPathModifiedMs(String path) async {
  if (isAppManagedSourcePath(path)) {
    final stat = await AppStorage.stat(path);
    return stat?.modifiedMs;
  }
  final file = File(path);
  if (!await file.exists()) return null;
  return (await file.stat()).modified.millisecondsSinceEpoch;
}
