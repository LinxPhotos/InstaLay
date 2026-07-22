import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/canvas_config.dart';
import '../models/canvas_template.dart';
import '../models/matte_palette.dart';
import '../models/project.dart';
import '../services/export_save.dart';
import '../services/export_service.dart';
import '../services/instagram_share.dart';
import '../services/license_service.dart';
import '../services/linx_auth_store.dart';
import '../services/linx_launch_intent.dart';
import '../services/matte_palette_store.dart';
import '../services/project_store.dart';
import '../services/template_store.dart';

final projectStoreProvider = Provider<ProjectStore>((ref) => ProjectStore());
final templateStoreProvider = Provider<TemplateStore>((ref) => TemplateStore());
final mattePaletteStoreProvider =
    Provider<MattePaletteStore>((ref) => MattePaletteStore());
final instagramShareProvider = Provider<InstagramShare>((ref) => InstagramShare());
final exportSaveProvider = Provider<ExportSave>((ref) => ExportSave());

final licenseServiceProvider = Provider<LicenseService>((ref) => LicenseService());

final linxAuthStoreProvider = Provider<LinxAuthStore>((ref) => LinxAuthStore());

final linxAuthProvider =
    AsyncNotifierProvider<LinxAuthNotifier, LinxAuthStore>(LinxAuthNotifier.new);

class LinxAuthNotifier extends AsyncNotifier<LinxAuthStore> {
  @override
  Future<LinxAuthStore> build() async {
    final store = ref.read(linxAuthStoreProvider);
    await store.load();
    return store;
  }
}

/// Pending Linx → InstaLay deep-link intent (consumed once by home/editor).
final pendingLinxLaunchProvider =
    StateProvider<LinxLaunchIntent?>((ref) => null);

final licenseProvider =
    AsyncNotifierProvider<LicenseNotifier, LicenseService>(LicenseNotifier.new);

class LicenseNotifier extends AsyncNotifier<LicenseService> {
  @override
  Future<LicenseService> build() async {
    final svc = ref.read(licenseServiceProvider);
    await svc.load();
    return svc;
  }

  Future<bool> activate(String key) async {
    final svc = state.value ?? await future;
    final ok = await svc.activate(key);
    state = AsyncData(svc);
    return ok;
  }

  Future<void> identifyCustomer(String customerUserId) async {
    final svc = state.value ?? await future;
    await svc.identifyCustomer(customerUserId);
    state = AsyncData(svc);
  }

  Future<void> restorePurchases() async {
    final svc = state.value ?? await future;
    await svc.restorePurchases();
    state = AsyncData(svc);
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref.watch(projectStoreProvider));
});

final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(ProjectsNotifier.new);

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final list = await ref.read(projectStoreProvider).loadAll();
    // Backfill missing home-screen strip previews in the background.
    unawaited(ensurePreviewThumbs(list));
    return list;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final list = await ref.read(projectStoreProvider).loadAll();
    state = AsyncData(list);
    unawaited(ensurePreviewThumbs(list));
  }

  /// Generate [ProjectVersion.previewThumbPath] when missing, stale on disk,
  /// or still using a legacy wide-strip aspect that no longer matches the layout.
  Future<void> ensurePreviewThumbs(List<Project> projects) async {
    final store = ref.read(projectStoreProvider);
    final export = ref.read(exportServiceProvider);
    var changed = false;
    final next = <Project>[];

    for (final project in projects) {
      final version = project.activeVersion;
      final layout = version?.identityLayout;
      if (version == null ||
          layout == null ||
          (layout.photos.isEmpty && layout.texts.isEmpty)) {
        next.add(project);
        continue;
      }
      final path = version.previewThumbPath;
      final needsRegen = path == null ||
          !File(path).existsSync() ||
          !_thumbMatchesLayoutAspect(path, layout.config.aspect.ratio);
      if (!needsRegen) {
        next.add(project);
        continue;
      }
      try {
        final thumb = await export.refreshIdentityThumb(
          project: project,
          version: version,
        );
        if (thumb == null) {
          next.add(project);
          continue;
        }
        final updated = project.copyWith(
          versions: [
            for (final v in project.versions)
              v.id == version.id ? v.copyWith(previewThumbPath: thumb) : v,
          ],
        );
        await store.save(updated);
        next.add(updated);
        changed = true;
      } catch (_) {
        next.add(project);
      }
    }

    if (changed && ref.mounted) {
      state = AsyncData(next);
    }
  }

  /// True when the JPEG on disk is within ~8% of the layout canvas aspect.
  static bool _thumbMatchesLayoutAspect(String path, double expectedRatio) {
    try {
      final bytes = File(path).readAsBytesSync();
      if (bytes.isEmpty) return false;
      // Avoid full decode: JPEG SOF / PNG IHDR via package:image would need
      // an import; use a cheap size probe through ExportService's renderer.
      // For home-load we accept a lightweight decode of the small thumb file.
      final decoded = _tryDecodeThumbSize(bytes);
      if (decoded == null) return false;
      final actual = decoded.$1 / decoded.$2;
      final err = (actual - expectedRatio).abs() / expectedRatio;
      return err <= 0.08;
    } catch (_) {
      return false;
    }
  }

  /// Returns (width, height) if the thumb header can be read; else null.
  static (int, int)? _tryDecodeThumbSize(List<int> bytes) {
    // Minimal JPEG SOF0/2 scan — thumbs are always JPEG from encodeJpg.
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return null;
    }
    var i = 2;
    while (i + 9 < bytes.length) {
      if (bytes[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = bytes[i + 1];
      if (marker == 0xD9 || marker == 0xDA) break;
      if (i + 3 >= bytes.length) break;
      final segLen = (bytes[i + 2] << 8) | bytes[i + 3];
      if (segLen < 2) break;
      // SOF0 / SOF2 baseline / progressive
      if ((marker == 0xC0 || marker == 0xC2) && i + 8 < bytes.length) {
        final h = (bytes[i + 5] << 8) | bytes[i + 6];
        final w = (bytes[i + 7] << 8) | bytes[i + 8];
        if (w > 0 && h > 0) return (w, h);
      }
      i += 2 + segLen;
    }
    return null;
  }

  Future<Project> create({String? name}) async {
    final project = await ref.read(projectStoreProvider).create(name: name);
    await refresh();
    return project;
  }

  Future<void> save(Project project) async {
    await ref.read(projectStoreProvider).save(project);
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(projectStoreProvider).delete(id);
    await refresh();
  }
}

final templatesProvider =
    AsyncNotifierProvider<TemplatesNotifier, List<CanvasTemplate>>(
  TemplatesNotifier.new,
);

class TemplatesNotifier extends AsyncNotifier<List<CanvasTemplate>> {
  @override
  Future<List<CanvasTemplate>> build() =>
      ref.read(templateStoreProvider).loadAll();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(templateStoreProvider).loadAll());
  }

  Future<CanvasTemplate> saveAs({
    required String name,
    required CanvasConfig config,
  }) async {
    final tpl = await ref.read(templateStoreProvider).saveAsTemplate(
          name: name,
          config: config,
        );
    await refresh();
    return tpl;
  }

  Future<void> delete(String id) async {
    await ref.read(templateStoreProvider).delete(id);
    await refresh();
  }
}

final mattePaletteProvider =
    AsyncNotifierProvider<MattePaletteNotifier, MattePalette>(
  MattePaletteNotifier.new,
);

class MattePaletteNotifier extends AsyncNotifier<MattePalette> {
  @override
  Future<MattePalette> build() async {
    try {
      return await ref.read(mattePaletteStoreProvider).loadMerged();
    } catch (_) {
      return MattePalette.builtins();
    }
  }

  Future<void> _set(MattePalette palette) async {
    state = AsyncData(palette);
  }

  Future<void> addCollection({required String name, String? description}) async {
    final next = await ref.read(mattePaletteStoreProvider).addCollection(
          name: name,
          description: description,
        );
    await _set(next);
  }

  Future<void> addGroup({
    required String name,
    String? description,
    String? collectionId,
  }) async {
    final next = await ref.read(mattePaletteStoreProvider).addGroup(
          name: name,
          description: description,
          collectionId: collectionId,
        );
    await _set(next);
  }

  Future<void> addSwatch({
    required String groupId,
    required String name,
    required Color color,
  }) async {
    final next = await ref.read(mattePaletteStoreProvider).addSwatch(
          groupId: groupId,
          name: name,
          color: color,
        );
    await _set(next);
  }
}
