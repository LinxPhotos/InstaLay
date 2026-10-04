import 'dart:typed_data';

import 'app_storage_stub.dart' show AppStorageStat;
import 'app_storage_stub.dart'
    if (dart.library.io) 'app_storage_io.dart'
    if (dart.library.html) 'app_storage_web.dart' as impl;

export 'app_storage_stub.dart' show AppStorageStat;


/// Cross-platform app data bytes (filesystem on IO, IndexedDB on web).
abstract final class AppStorage {
  static Future<void> init() => impl.initAppStorage();

  static Future<bool> exists(String relativePath) =>
      impl.appStorageExists(relativePath);

  static Future<Uint8List?> readBytes(String relativePath) =>
      impl.appStorageReadBytes(relativePath);

  static Future<void> writeBytes(String relativePath, Uint8List bytes) =>
      impl.appStorageWriteBytes(relativePath, bytes);

  static Future<void> delete(String relativePath) =>
      impl.appStorageDelete(relativePath);

  static Future<void> deleteTree(String relativeDir) =>
      impl.appStorageDeleteTree(relativeDir);

  static Future<AppStorageStat?> stat(String relativePath) =>
      impl.appStorageStat(relativePath);
}
