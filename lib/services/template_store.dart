import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/canvas_config.dart';
import '../models/canvas_template.dart';
import 'app_storage.dart';
import 'json_storage.dart';

class TemplateStore {
  TemplateStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  static bool _corruptLogged = false;

  static const _path = 'templates.json';

  Future<List<CanvasTemplate>> loadAll() async {
    await AppStorage.init();
    final decoded = await readJsonAtPath(_path, label: 'TemplateStore');
    if (decoded == null) return [];
    if (decoded is! List) {
      _logCorruptOnce('TemplateStore: expected JSON array, got ${decoded.runtimeType}');
      await _quarantineIndex();
      return [];
    }
    try {
      return decoded
          .map((e) => CanvasTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _logCorruptOnce('TemplateStore: failed to parse templates ($e)');
      await _quarantineIndex();
      return [];
    }
  }

  Future<void> _saveAll(List<CanvasTemplate> items) async {
    await writeJsonAtPath(
      _path,
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

  Future<void> _quarantineIndex() async {
    if (!await AppStorage.exists(_path)) return;
    try {
      final stamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final bytes = await AppStorage.readBytes(_path);
      if (bytes != null) {
        await AppStorage.writeBytes('$_path.corrupt.$stamp', bytes);
      }
      await AppStorage.delete(_path);
    } catch (e) {
      debugPrint('TemplateStore: quarantine failed ($e)');
    }
  }
}
