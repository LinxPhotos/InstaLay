import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'app_storage.dart';

Future<void> writeExportPath(String path, Uint8List bytes) async {
  if (p.isAbsolute(path)) {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return;
  }
  await AppStorage.writeBytes(path, bytes);
}
