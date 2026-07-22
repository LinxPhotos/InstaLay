import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

final Map<String, Future<void>> _pendingWrites = {};
int _tempFileSequence = 0;

/// Read JSON from [file], recovering from missing/empty/corrupt data.
///
/// Returns `null` when the file is absent, whitespace-only, or invalid JSON
/// (corrupt files are renamed aside once so the next write can start fresh).
Future<Object?> readJsonFile(File file, {required String label}) async {
  if (!await file.exists()) return null;
  final text = await file.readAsString();
  if (text.trim().isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException catch (e) {
    debugPrint('$label: corrupt JSON ($e); backing up and recovering');
    await _backupCorrupt(file);
    return null;
  }
}

/// Write [value] as indented JSON via temp file + rename (Windows-safe).
Future<void> writeJsonFileAtomic(File file, Object value) async {
  final path = file.absolute.path;
  final previous = _pendingWrites[path] ?? Future<void>.value();
  late final Future<void> write;
  write = previous
      .catchError((Object _) {})
      .then((_) => _writeJsonFileAtomic(file, value));
  _pendingWrites[path] = write;

  try {
    await write;
  } finally {
    if (identical(_pendingWrites[path], write)) {
      _pendingWrites.remove(path);
    }
  }
}

Future<void> _writeJsonFileAtomic(File file, Object value) async {
  await file.parent.create(recursive: true);
  final encoded = const JsonEncoder.withIndent('  ').convert(value);
  final tmp = File('${file.path}.tmp.$pid.${_tempFileSequence++}');
  await tmp.writeAsString(encoded, flush: true);
  try {
    // File.rename replaces an existing file, without exposing a deliberate
    // delete/rename gap to concurrent readers.
    await tmp.rename(file.path);
  } finally {
    if (await tmp.exists()) await tmp.delete();
  }
}

Future<void> _backupCorrupt(File file) async {
  try {
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final backup = File('${file.path}.corrupt.$stamp');
    await file.rename(backup.path);
  } catch (e) {
    debugPrint('Failed to backup corrupt file ${file.path}: $e');
    try {
      await file.delete();
    } catch (_) {}
  }
}
