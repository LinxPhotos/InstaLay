import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/canvas_config.dart';
import '../models/project.dart';
import 'safe_json_file.dart';

class ProjectStore {
  ProjectStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  static const _projectsFile = 'projects.json';
  static bool _corruptLogged = false;

  Future<Directory> _root() async {
    if (kIsWeb) {
      throw UnsupportedError('Local project files are not available on web yet.');
    }
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'insta_lay', 'projects'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _indexFile() async => File(p.join((await _root()).path, _projectsFile));

  Future<List<Project>> loadAll() async {
    final file = await _indexFile();
    final decoded = await readJsonFile(file, label: 'ProjectStore');
    if (decoded == null) return [];
    if (decoded is! List) {
      _logCorruptOnce('ProjectStore: expected JSON array, got ${decoded.runtimeType}');
      await _quarantine(file);
      return [];
    }
    try {
      return decoded
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      _logCorruptOnce('ProjectStore: failed to parse projects ($e)');
      await _quarantine(file);
      return [];
    }
  }

  Future<void> _saveAll(List<Project> projects) async {
    final file = await _indexFile();
    await writeJsonFileAtomic(
      file,
      projects.map((e) => e.toJson()).toList(),
    );
  }

  Future<Project> create({
    String? name,
    CanvasConfig? config,
  }) async {
    final now = DateTime.now();
    final versionId = _uuid.v4();
    final layoutId = _uuid.v4();
    final initialConfig = config ?? const CanvasConfig();
    final project = Project(
      id: _uuid.v4(),
      name: name ?? 'Project ${now.month}/${now.day}',
      createdAt: now,
      updatedAt: now,
      activeVersionId: versionId,
      versions: [
        ProjectVersion(
          id: versionId,
          versionNumber: 1,
          label: 'v1',
          activeLayoutId: layoutId,
          layouts: [
            LayoutCanvas(
              id: layoutId,
              name: initialConfig.layoutMode == LayoutMode.tapestry
                  ? 'Tapestry'
                  : 'Batch',
              config: initialConfig,
              photos: const [],
            ),
          ],
          createdAt: now,
        ),
      ],
    );
    final all = await loadAll();
    all.insert(0, project);
    await _saveAll(all);
    return project;
  }

  Future<Project> save(Project project) async {
    final updated = project.copyWith(updatedAt: DateTime.now());
    final all = await loadAll();
    final idx = all.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) {
      all[idx] = updated;
    } else {
      all.insert(0, updated);
    }
    await _saveAll(all);
    return updated;
  }

  Future<void> delete(String projectId) async {
    final all = await loadAll();
    all.removeWhere((p) => p.id == projectId);
    await _saveAll(all);
    final media = Directory(p.join((await _root()).path, projectId));
    if (await media.exists()) await media.delete(recursive: true);
  }

  Future<Directory> mediaDir(String projectId) async {
    final dir = Directory(p.join((await _root()).path, projectId, 'media'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> exportDir(String projectId, String versionId) async {
    final dir = Directory(
      p.join((await _root()).path, projectId, 'exports', versionId),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Persist an editable change on the active (non-frozen) version.
  Future<Project> updateActiveVersion(
    Project project,
    ProjectVersion Function(ProjectVersion current) mutate,
  ) async {
    final active = project.activeVersion;
    if (active == null) throw StateError('No active version');
    if (active.frozen) {
      throw StateError('Version is frozen after Instagram commit');
    }
    final next = mutate(active);
    final versions = project.versions
        .map((v) => v.id == next.id ? next : v)
        .toList();
    return save(project.copyWith(versions: versions));
  }

  /// Explicitly freeze the active version after the user confirms they posted.
  ///
  /// Prefer [markAsPosted] — [commitToInstagram] is kept as a stable alias.
  Future<Project> markAsPosted(Project project) async {
    final active = project.activeVersion;
    if (active == null) throw StateError('No active version');
    if (active.frozen) return project;
    final frozen = active.copyWith(
      frozen: true,
      postedToInstagramAt: DateTime.now(),
    );
    final versions =
        project.versions.map((v) => v.id == frozen.id ? frozen : v).toList();
    return save(project.copyWith(versions: versions));
  }

  /// Alias for [markAsPosted] (older call sites / docs).
  Future<Project> commitToInstagram(Project project) => markAsPosted(project);

  /// Clear a mistaken freeze without cloning a new version.
  Future<Project> unfreezeActiveVersion(Project project) async {
    final active = project.activeVersion;
    if (active == null) throw StateError('No active version');
    if (!active.frozen && active.postedToInstagramAt == null) return project;
    final thawed = active.copyWith(
      frozen: false,
      clearPostedToInstagramAt: true,
    );
    final versions =
        project.versions.map((v) => v.id == thawed.id ? thawed : v).toList();
    return save(project.copyWith(versions: versions));
  }

  /// Clone a version (often frozen) into a new editable version.
  Future<Project> cloneVersion(Project project, {String? fromVersionId}) async {
    final source = fromVersionId == null
        ? project.activeVersion
        : project.versions.cast<ProjectVersion?>().firstWhere(
              (v) => v!.id == fromVersionId,
              orElse: () => project.activeVersion,
            );
    if (source == null) throw StateError('No version to clone');

    final nextNum =
        project.versions.map((v) => v.versionNumber).fold<int>(0, mathMax) + 1;
    final clonedLayouts = <LayoutCanvas>[];
    String? activeLayoutId;
    for (final layout in source.layouts) {
      final layoutId = _uuid.v4();
      if (layout.id == source.activeLayoutId ||
          (activeLayoutId == null && layout.id == source.activeLayout?.id)) {
        activeLayoutId = layoutId;
      }
      clonedLayouts.add(
        LayoutCanvas(
          id: layoutId,
          name: layout.name,
          config: layout.config,
          previewHeight: layout.previewHeight,
          tapestrySlideCount: layout.tapestrySlideCount,
          photos: layout.photos
              .map(
                (ph) => PhotoItem(
                  id: _uuid.v4(),
                  sourcePath: ph.sourcePath,
                  fileName: ph.fileName,
                  order: ph.order,
                  zIndex: ph.zIndex,
                  offsetX: ph.offsetX,
                  offsetY: ph.offsetY,
                  scale: ph.scale,
                  rotationDeg: ph.rotationDeg,
                  cropLeft: ph.cropLeft,
                  cropTop: ph.cropTop,
                  cropRight: ph.cropRight,
                  cropBottom: ph.cropBottom,
                ),
              )
              .toList(),
        ),
      );
    }
    activeLayoutId ??= clonedLayouts.isEmpty ? null : clonedLayouts.first.id;

    final clone = ProjectVersion(
      id: _uuid.v4(),
      versionNumber: nextNum,
      label: 'v$nextNum',
      layouts: clonedLayouts,
      activeLayoutId: activeLayoutId,
      createdAt: DateTime.now(),
      frozen: false,
    );

    return save(
      project.copyWith(
        versions: [...project.versions, clone],
        activeVersionId: clone.id,
      ),
    );
  }

  Future<Project> setActiveVersion(Project project, String versionId) async {
    return save(project.copyWith(activeVersionId: versionId));
  }

  static int mathMax(int a, int b) => a > b ? a : b;

  static void _logCorruptOnce(String message) {
    if (_corruptLogged) return;
    _corruptLogged = true;
    debugPrint(message);
  }

  Future<void> _quarantine(File file) async {
    // readJsonFile already backs up FormatException; this covers wrong shape / parse.
    if (!await file.exists()) return;
    try {
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      await file.rename('${file.path}.corrupt.$stamp');
    } catch (e) {
      debugPrint('ProjectStore: quarantine failed ($e)');
    }
  }
}
