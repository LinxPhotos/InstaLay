import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/canvas_config.dart';
import '../models/canvas_template.dart';
import 'safe_json_file.dart';

class TemplateStore {
  TemplateStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  static bool _corruptLogged = false;

  Future<File> _file() async {
    if (kIsWeb) {
      throw UnsupportedError('Templates require non-web storage for now.');
    }
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'insta_lay'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, 'templates.json'));
  }

  Future<List<CanvasTemplate>> loadAll() async {
    final file = await _file();
    final decoded = await readJsonFile(file, label: 'TemplateStore');
    if (decoded == null) return [];
    if (decoded is! List) {
      _logCorruptOnce('TemplateStore: expected JSON array, got ${decoded.runtimeType}');
      await _quarantine(file);
      return [];
    }
    try {
      return decoded
          .map((e) => CanvasTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _logCorruptOnce('TemplateStore: failed to parse templates ($e)');
      await _quarantine(file);
      return [];
    }
  }

  Future<void> _saveAll(List<CanvasTemplate> items) async {
    final file = await _file();
    await writeJsonFileAtomic(
      file,
      items.map((e) => e.toJson()).toList(),
    );
  }

  Future<CanvasTemplate> saveAsTemplate({
    required String name,
    required CanvasConfig config,
  }) async {
    final tpl = CanvasTemplate(
      id: _uuid.v4(),
      name: name,
      config: config,
      createdAt: DateTime.now(),
    );
    final all = await loadAll();
    all.insert(0, tpl);
    await _saveAll(all);
    return tpl;
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((t) => t.id == id);
    await _saveAll(all);
  }

  Future<CanvasTemplate> update(CanvasTemplate template) async {
    final all = await loadAll();
    final idx = all.indexWhere((t) => t.id == template.id);
    final next = template.copyWith(updatedAt: DateTime.now());
    if (idx >= 0) {
      all[idx] = next;
    } else {
      all.insert(0, next);
    }
    await _saveAll(all);
    return next;
  }

  static void _logCorruptOnce(String message) {
    if (_corruptLogged) return;
    _corruptLogged = true;
    debugPrint(message);
  }

  Future<void> _quarantine(File file) async {
    if (!await file.exists()) return;
    try {
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      await file.rename('${file.path}.corrupt.$stamp');
    } catch (e) {
      debugPrint('TemplateStore: quarantine failed ($e)');
    }
  }
}
