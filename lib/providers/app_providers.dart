import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/canvas_config.dart';
import '../models/canvas_template.dart';
import '../models/matte_palette.dart';
import '../models/project.dart';
import '../services/export_service.dart';
import '../services/instagram_share.dart';
import '../services/license_service.dart';
import '../services/matte_palette_store.dart';
import '../services/project_store.dart';
import '../services/template_store.dart';

final projectStoreProvider = Provider<ProjectStore>((ref) => ProjectStore());
final templateStoreProvider = Provider<TemplateStore>((ref) => TemplateStore());
final mattePaletteStoreProvider =
    Provider<MattePaletteStore>((ref) => MattePaletteStore());
final instagramShareProvider = Provider<InstagramShare>((ref) => InstagramShare());

final licenseServiceProvider = Provider<LicenseService>((ref) => LicenseService());

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
}

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref.watch(projectStoreProvider));
});

final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(ProjectsNotifier.new);

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() => ref.read(projectStoreProvider).loadAll();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(projectStoreProvider).loadAll());
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
