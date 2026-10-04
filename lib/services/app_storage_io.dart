import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'app_paths.dart';
import 'app_storage_stub.dart' show AppStorageStat;

Directory? _rootDir;

Future<Directory> _root() async {
  _rootDir ??= await appDataRoot();
  return _rootDir!;
}

Future<String> _absPath(String relativePath) async {
  final norm = relativePath.replaceAll('\\', '/');
  return p.join((await _root()).path, norm);
}

Future<void> initAppStorage() async {
  await _root();
}

Future<bool> appStorageExists(String relativePath) async {
  return File(await _absPath(relativePath)).exists();
}

Future<Uint8List?> appStorageReadBytes(String relativePath) async {
  final file = File(await _absPath(relativePath));
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> appStorageWriteBytes(String relativePath, Uint8List bytes) async {
  final path = await _absPath(relativePath);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<void> appStorageDelete(String relativePath) async {
  final file = File(await _absPath(relativePath));
  if (await file.exists()) await file.delete();
}

Future<void> appStorageDeleteTree(String relativeDir) async {
  final dir = Directory(await _absPath(relativeDir));
  if (await dir.exists()) await dir.delete(recursive: true);
}

Future<AppStorageStat?> appStorageStat(String relativePath) async {
  final file = File(await _absPath(relativePath));
  if (!await file.exists()) return null;
  final stat = await file.stat();
  return AppStorageStat(
    size: stat.size,
    modifiedMs: stat.modified.millisecondsSinceEpoch,
  );
}
