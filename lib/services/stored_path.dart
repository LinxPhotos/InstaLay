import 'stored_path_stub.dart'
    if (dart.library.io) 'stored_path_io.dart'
    if (dart.library.html) 'stored_path_web.dart' as impl;

Future<bool> storedPathExists(String path) => impl.storedPathExists(path);

/// Last modified time (epoch ms) when known; null if missing or unsupported.
Future<int?> storedPathModifiedMs(String path) => impl.storedPathModifiedMs(path);
