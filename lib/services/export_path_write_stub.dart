import 'dart:typed_data';

import 'app_storage.dart';

Future<void> writeExportPath(String path, Uint8List bytes) =>
    AppStorage.writeBytes(path, bytes);
