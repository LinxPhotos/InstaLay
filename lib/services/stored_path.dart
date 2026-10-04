import 'stored_path_stub.dart'
    if (dart.library.io) 'stored_path_io.dart'
    if (dart.library.html) 'stored_path_web.dart' as impl;

Future<bool> storedPathExists(String path) => impl.storedPathExists(path);
