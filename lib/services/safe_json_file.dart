import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
  await file.parent.create(recursive: true);
  final encoded = const JsonEncoder.withIndent('  ').convert(value);
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(encoded, flush: true);
  if (await file.exists()) await file.delete();
  await tmp.rename(file.path);
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
