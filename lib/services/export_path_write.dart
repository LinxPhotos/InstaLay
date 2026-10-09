import 'dart:typed_data';

import 'export_path_write_stub.dart'
    if (dart.library.io) 'export_path_write_io.dart' as impl;

Future<void> writeExportPath(String path, Uint8List bytes) =>
    impl.writeExportPath(path, bytes);
