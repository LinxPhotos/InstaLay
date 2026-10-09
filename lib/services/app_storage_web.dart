import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import 'app_storage_stub.dart' show AppStorageStat;

const _dbName = 'instalay_web_v1';
const _storeName = 'files';

Database? _db;

Future<Database> _openDb() async {
  if (_db != null) return _db!;
  final factory = getIdbFactory()!;
  _db = await factory.open(
    _dbName,
    version: 1,
    onUpgradeNeeded: (VersionChangeEvent event) {
      final db = event.database;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    },
  );
  return _db!;
}

String _norm(String relativePath) =>
    relativePath.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');

Future<void> initAppStorage() async {
  await _openDb();
}

Future<bool> appStorageExists(String relativePath) async {
  final db = await _openDb();
  final txn = db.transaction(_storeName, idbModeReadOnly);
  final store = txn.objectStore(_storeName);
  final key = _norm(relativePath);
  final value = await store.getObject(key);
  await txn.completed;
  return value != null;
}

Future<Uint8List?> appStorageReadBytes(String relativePath) async {
  final db = await _openDb();
  final txn = db.transaction(_storeName, idbModeReadOnly);
  final store = txn.objectStore(_storeName);
  final key = _norm(relativePath);
  final value = await store.getObject(key);
  await txn.completed;
  if (value == null) return null;
  if (value is Uint8List) return value;
  if (value is List<int>) return Uint8List.fromList(value);
  return null;
}

Future<void> appStorageWriteBytes(String relativePath, Uint8List bytes) async {
  final db = await _openDb();
  final txn = db.transaction(_storeName, idbModeReadWrite);
  final store = txn.objectStore(_storeName);
  final key = _norm(relativePath);
  await store.put(bytes, key);
  await txn.completed;
}

Future<void> appStorageDelete(String relativePath) async {
  final db = await _openDb();
  final txn = db.transaction(_storeName, idbModeReadWrite);
  final store = txn.objectStore(_storeName);
  await store.delete(_norm(relativePath));
  await txn.completed;
}

Future<void> appStorageDeleteTree(String relativeDir) async {
  final prefix = '${_norm(relativeDir)}/';
  final db = await _openDb();
  final txn = db.transaction(_storeName, idbModeReadWrite);
  final store = txn.objectStore(_storeName);
  final keys = await store.getAllKeys();
  for (final key in keys) {
    final s = key.toString();
    if (s.startsWith(prefix) || s == _norm(relativeDir)) {
      await store.delete(key);
    }
  }
  await txn.completed;
}

Future<AppStorageStat?> appStorageStat(String relativePath) async {
  final bytes = await appStorageReadBytes(relativePath);
  if (bytes == null) return null;
  return AppStorageStat(size: bytes.length, modifiedMs: 0);
}

Future<List<String>> appStorageListFileNames(String relativeDir) async {
  final prefix = '${_norm(relativeDir)}/';
  final db = await _openDb();
  final txn = db.transaction(_storeName, idbModeReadOnly);
  final store = txn.objectStore(_storeName);
  final keys = await store.getAllKeys();
  await txn.completed;
  final names = <String>[];
  for (final key in keys) {
    final s = key.toString();
    if (!s.startsWith(prefix)) continue;
    final rest = s.substring(prefix.length);
    if (rest.contains('/')) continue;
    names.add(rest);
  }
  names.sort();
  return names;
}

Future<List<String>> appStorageListChildDirectoryNames(String relativeDir) async {
  final base = _norm(relativeDir);
  final prefix = base.isEmpty ? '' : '$base/';
  final db = await _openDb();
  final txn = db.transaction(_storeName, idbModeReadOnly);
  final store = txn.objectStore(_storeName);
  final keys = await store.getAllKeys();
  await txn.completed;
  final dirs = <String>{};
  for (final key in keys) {
    var s = key.toString();
    if (prefix.isNotEmpty && !s.startsWith(prefix)) continue;
    if (prefix.isNotEmpty) s = s.substring(prefix.length);
    final slash = s.indexOf('/');
    if (slash <= 0) continue;
    dirs.add(s.substring(0, slash));
  }
  final out = dirs.toList()..sort();
  return out;
}
