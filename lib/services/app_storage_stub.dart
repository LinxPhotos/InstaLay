import 'dart:typed_data';

Future<void> initAppStorage() async {
  throw UnsupportedError('AppStorage is not available on this platform.');
}

Future<bool> appStorageExists(String relativePath) async {
  throw UnsupportedError('AppStorage is not available on this platform.');
}

Future<Uint8List?> appStorageReadBytes(String relativePath) async {
  throw UnsupportedError('AppStorage is not available on this platform.');
}

Future<void> appStorageWriteBytes(String relativePath, Uint8List bytes) async {
  throw UnsupportedError('AppStorage is not available on this platform.');
}

Future<void> appStorageDelete(String relativePath) async {
  throw UnsupportedError('AppStorage is not available on this platform.');
}

Future<void> appStorageDeleteTree(String relativeDir) async {
  throw UnsupportedError('AppStorage is not available on this platform.');
}

Future<AppStorageStat?> appStorageStat(String relativePath) async {
  throw UnsupportedError('AppStorage is not available on this platform.');
}

class AppStorageStat {
  const AppStorageStat({required this.size, required this.modifiedMs});

  final int size;
  final int modifiedMs;
}
