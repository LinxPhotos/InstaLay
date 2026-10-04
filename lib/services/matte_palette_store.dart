import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/color_swatches.dart';
import '../models/matte_palette.dart';
import 'app_storage.dart';
import 'json_storage.dart';

/// Persists user matte collections / groups (builtins stay in code).
class MattePaletteStore {
  MattePaletteStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  static const _zoneExtraId = 'zone_system_extra';
  static bool _corruptLogged = false;
  static const _empty = MattePalette(collections: [], standaloneGroups: []);
  static const _path = 'matte_palette.json';

  Future<MattePalette> loadCustom() async {
    await AppStorage.init();
    final decoded = await readJsonAtPath(_path, label: 'MattePaletteStore');
    if (decoded == null) return _empty;
    if (decoded is! Map) {
      _logCorruptOnce(
        'MattePaletteStore: expected JSON object, got ${decoded.runtimeType}',
      );
      await _quarantineIndex();
      return _empty;
    }
    try {
      return MattePalette.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      _logCorruptOnce('MattePaletteStore: failed to parse palette ($e)');
      await _quarantineIndex();
      return _empty;
    }
  }

  Future<MattePalette> loadMerged() async {
    return MattePalette.merge(MattePalette.builtins(), await loadCustom());
  }

  Future<void> saveCustom(MattePalette custom) async {
    await writeJsonAtPath(_path, custom.toJson());
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
      debugPrint('MattePaletteStore: quarantine failed ($e)');
    }
  }

  Future<MattePalette> addCollection({
    required String name,
    String? description,
  }) async {
    final custom = await loadCustom();
    await saveCustom(
      MattePalette(
        collections: [
          ...custom.collections,
          SwatchCollection(
            id: _uuid.v4(),
            name: name.trim(),
            description: description?.trim(),
            groups: const [],
          ),
        ],
        standaloneGroups: custom.standaloneGroups,
      ),
    );
    return loadMerged();
  }

  /// [collectionId] null → standalone group. `zone_system` appends into Zone system.
  Future<MattePalette> addGroup({
    required String name,
    String? description,
    String? collectionId,
  }) async {
    final custom = await loadCustom();
    final group = SwatchGroup(
      id: _uuid.v4(),
      name: name.trim(),
      description: description?.trim(),
      swatches: const [],
    );

    if (collectionId == null) {
      await saveCustom(
        MattePalette(
          collections: custom.collections,
          standaloneGroups: [...custom.standaloneGroups, group],
        ),
      );
      return loadMerged();
    }

    final targetId =
        collectionId == 'zone_system' ? _zoneExtraId : collectionId;
    final cols = [...custom.collections];
    final idx = cols.indexWhere((c) => c.id == targetId);
    if (idx < 0) {
      cols.add(
        SwatchCollection(
          id: targetId,
          name: collectionId == 'zone_system' ? 'Zone system' : name,
          groups: [group],
        ),
      );
    } else {
      final old = cols[idx];
      cols[idx] = old.copyWith(groups: [...old.groups, group]);
    }

    await saveCustom(
      MattePalette(collections: cols, standaloneGroups: custom.standaloneGroups),
    );
    return loadMerged();
  }

  Future<MattePalette> addSwatch({
    required String groupId,
    required String name,
    required Color color,
  }) async {
    final custom = await loadCustom();
    final swatch = CanvasSwatch(
      id: _uuid.v4(),
      name: name.trim(),
      color: color,
      zone: PhotoZone.zoneVIII,
    );

    var patched = false;

    List<SwatchGroup> patchGroups(List<SwatchGroup> groups) {
      final out = <SwatchGroup>[];
      for (final g in groups) {
        if (g.id == groupId) {
          patched = true;
          out.add(g.copyWith(swatches: [...g.swatches, swatch]));
        } else {
          out.add(g);
        }
      }
      return out;
    }

    final cols = [
      for (final c in custom.collections)
        c.copyWith(groups: patchGroups(c.groups)),
    ];
    var standalone = patchGroups(custom.standaloneGroups);

    if (!patched) {
      // Builtin group (Zone / Taupes): keep user colors in a parallel extras group.
      standalone = [
        ...standalone,
        SwatchGroup(
          id: '${groupId}__user',
          name: 'Custom mattes',
          description: 'Colors added to $groupId',
          swatches: [swatch],
        ),
      ];
    }

    await saveCustom(
      MattePalette(collections: cols, standaloneGroups: standalone),
    );
    return loadMerged();
  }
}
