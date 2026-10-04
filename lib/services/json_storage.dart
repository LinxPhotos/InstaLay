import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'app_storage.dart';

/// Read JSON from app storage, recovering from missing/empty/corrupt data.
Future<Object?> readJsonAtPath(String relativePath, {required String label}) async {
  final bytes = await AppStorage.readBytes(relativePath);
  if (bytes == null || bytes.isEmpty) return null;
  final text = utf8.decode(bytes);
  if (text.trim().isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException catch (e) {
    debugPrint('$label: corrupt JSON ($e); backing up and recovering');
    await _backupCorrupt(relativePath);
    return null;
  }
}

Future<void> writeJsonAtPath(String relativePath, Object value) async {
  final encoded = const JsonEncoder.withIndent('  ').convert(value);
  await AppStorage.writeBytes(relativePath, Uint8List.fromList(utf8.encode(encoded)));
}

Future<void> _backupCorrupt(String relativePath) async {
  if (!await AppStorage.exists(relativePath)) return;
  try {
    final stamp =
        DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final bytes = await AppStorage.readBytes(relativePath);
    if (bytes != null) {
      await AppStorage.writeBytes('$relativePath.corrupt.$stamp', bytes);
    }
    await AppStorage.delete(relativePath);
  } catch (e) {
    debugPrint('json_storage: backup failed ($e)');
  }
}
