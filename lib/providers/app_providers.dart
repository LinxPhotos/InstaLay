import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/canvas_config.dart';
import '../models/canvas_template.dart';
import '../models/project.dart';
import '../services/export_service.dart';
import '../services/instagram_share.dart';
import '../services/license_service.dart';
import '../services/project_store.dart';
import '../services/template_store.dart';

final projectStoreProvider = Provider<ProjectStore>((ref) => ProjectStore());
final templateStoreProvider = Provider<TemplateStore>((ref) => TemplateStore());
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
