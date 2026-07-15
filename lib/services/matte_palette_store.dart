import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/color_swatches.dart';
import '../models/matte_palette.dart';

/// Persists user matte collections / groups (builtins stay in code).
class MattePaletteStore {
  MattePaletteStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  static const _zoneExtraId = 'zone_system_extra';

  Future<File> _file() async {
    if (kIsWeb) {
      throw UnsupportedError('Matte palette storage is not available on web yet.');
    }
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'insta_lay'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, 'matte_palette.json'));
  }

  Future<MattePalette> loadCustom() async {
    final file = await _file();
    if (!await file.exists()) {
      return const MattePalette(collections: [], standaloneGroups: []);
    }
    final raw = jsonDecode(await file.readAsString()) as Map;
    return MattePalette.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<MattePalette> loadMerged() async {
    return MattePalette.merge(MattePalette.builtins(), await loadCustom());
  }

  Future<void> saveCustom(MattePalette custom) async {
    final file = await _file();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(custom.toJson()),
    );
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
