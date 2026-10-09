import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/canvas_config.dart';
import '../models/project.dart';
import 'app_paths.dart';
import 'app_storage.dart';
import 'json_storage.dart';

const _projectIdDirPattern =
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

/// Relative prefix for project media / exports (app storage key).
class ProjectStoragePath {
  const ProjectStoragePath(this.path);

  final String path;
}

class ProjectStore {
  ProjectStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  static const _projectsRoot = 'projects';
  static const _indexPath = 'projects/projects.json';
  static bool _corruptLogged = false;

  Future<List<Project>> loadAll() async {
    await AppStorage.init();
    final decoded = await readJsonAtPath(_indexPath, label: 'ProjectStore');
    if (decoded == null) return [];
    if (decoded is! List) {
      _logCorruptOnce('ProjectStore: expected JSON array, got ${decoded.runtimeType}');
      await _quarantineIndex();
      return [];
    }
    try {
      final projects = <Project>[];
      var needsPersist = false;
      for (final e in decoded) {
        final raw = Project.fromJson(Map<String, dynamic>.from(e as Map));
        final fixed = _rewriteLegacyMediaPaths(raw);
        if (!_projectPathsEqual(raw, fixed)) needsPersist = true;
        projects.add(fixed);
      }
      final recovered = await _recoverOrphanProjects(projects);
      if (recovered.isNotEmpty) {
        projects.addAll(recovered);
        needsPersist = true;
      }
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // Persist rewritten absolute paths once after insta_lay → instalay migrate.
      if (needsPersist) {
        await _saveAll(projects);
      }
      return projects;
    } catch (e) {
      _logCorruptOnce('ProjectStore: failed to parse projects ($e)');
      await _quarantineIndex();
      return [];
    }
  }

  /// After app-data folder rename, stored absolute media paths still say
  /// `…/insta_lay/…` while files live under `…/instalay/…`.
  static Project _rewriteLegacyMediaPaths(Project project) {
    return project.copyWith(
      versions: [
        for (final version in project.versions)
          version.copyWith(
            sources: [
              for (final source in version.sources)
                source.copyWith(
                  sourcePath: rewriteLegacyAppDataPath(source.sourcePath),
                ),
            ],
            layouts: [
              for (final layout in version.layouts)
                layout.copyWith(
                  photos: [
                    for (final photo in layout.photos)
                      photo.copyWith(
                        sourcePath:
                            rewriteLegacyAppDataPath(photo.sourcePath),
                      ),
                  ],
                  previewThumbPath: layout.previewThumbPath == null
                      ? null
                      : rewriteLegacyAppDataPath(layout.previewThumbPath!),
                ),
            ],
            previewThumbPath: version.previewThumbPath == null
                ? null
                : rewriteLegacyAppDataPath(version.previewThumbPath!),
            exportPaths: [
              for (final path in version.exportPaths)
                rewriteLegacyAppDataPath(path),
            ],
          ),
      ],
    );
  }

  static bool _projectPathsEqual(Project a, Project b) {
    if (a.versions.length != b.versions.length) return false;
    for (var i = 0; i < a.versions.length; i++) {
      final va = a.versions[i];
      final vb = b.versions[i];
      if (va.previewThumbPath != vb.previewThumbPath) return false;
      if (va.exportPaths.length != vb.exportPaths.length) return false;
      for (var j = 0; j < va.exportPaths.length; j++) {
        if (va.exportPaths[j] != vb.exportPaths[j]) return false;
      }
      if (va.sources.length != vb.sources.length) return false;
      for (var j = 0; j < va.sources.length; j++) {
        if (va.sources[j].sourcePath != vb.sources[j].sourcePath) {
          return false;
        }
      }
      if (va.layouts.length != vb.layouts.length) return false;
      for (var j = 0; j < va.layouts.length; j++) {
        final la = va.layouts[j];
        final lb = vb.layouts[j];
        if (la.photos.length != lb.photos.length) return false;
        for (var k = 0; k < la.photos.length; k++) {
          if (la.photos[k].sourcePath != lb.photos[k].sourcePath) {
            return false;
          }
        }
        if (la.previewThumbPath != lb.previewThumbPath) return false;
      }
    }
    return true;
  }

  Future<void> _saveAll(List<Project> projects) async {
    await writeJsonAtPath(
      _indexPath,
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
    await AppStorage.deleteTree(p.join(_projectsRoot, projectId));
  }

  Future<ProjectStoragePath> mediaDir(String projectId) async {
    return ProjectStoragePath(p.join(_projectsRoot, projectId, 'media'));
  }

  Future<ProjectStoragePath> exportDir(String projectId, String versionId) async {
    return ProjectStoragePath(
      p.join(_projectsRoot, projectId, 'exports', versionId),
    );
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

    final pool = source.sources.isNotEmpty
        ? source.sources
        : ProjectVersion.sourcesFromLayouts(source.layouts);

    // Remap shared source ids; layouts keep the same id ↔ source link.
    final idMap = <String, String>{
      for (final asset in pool) asset.id: _uuid.v4(),
    };
    final clonedSources = [
      for (final asset in pool)
        SourceAsset(
          id: idMap[asset.id]!,
          sourcePath: asset.sourcePath,
          fileName: asset.fileName,
        ),
    ];

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
                  id: idMap[ph.id] ?? _uuid.v4(),
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
                  borderPx: ph.borderPx,
                  borderColorArgb: ph.borderColorArgb,
                ),
              )
              .toList(),
          texts: layout.texts
              .map(
                (t) => TextItem(
                  id: _uuid.v4(),
                  text: t.text,
                  offsetX: t.offsetX,
                  offsetY: t.offsetY,
                  scale: t.scale,
                  rotationDeg: t.rotationDeg,
                  zIndex: t.zIndex,
                  fontFamily: t.fontFamily,
                  fontSize: t.fontSize,
                  colorArgb: t.colorArgb,
                  fontWeight: t.fontWeight,
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
      sources: clonedSources,
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

  static final _projectIdDir = RegExp(_projectIdDirPattern, caseSensitive: false);

  static bool _isMediaFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  Future<List<Project>> _recoverOrphanProjects(List<Project> indexed) async {
    if (kIsWeb) return const [];
    final known = {for (final p in indexed) p.id};
    final dirNames = await AppStorage.listChildDirectoryNames(_projectsRoot);
    final out = <Project>[];
    for (final id in dirNames) {
      if (!_projectIdDir.hasMatch(id) || known.contains(id)) continue;
      final recovered = await _recoverProjectFromDisk(id);
      if (recovered != null) out.add(recovered);
    }
    return out;
  }

  Future<Project?> _recoverProjectFromDisk(String projectId) async {
    final mediaRel = p.join(_projectsRoot, projectId, 'media');
    final names = await AppStorage.listFileNames(mediaRel);
    final sources = <SourceAsset>[];
    final root = await appDataRoot();
    for (final name in names) {
      if (!_isMediaFileName(name)) continue;
      if (name.toLowerCase().startsWith('preview_')) continue;
      final id = p.basenameWithoutExtension(name);
      if (!_projectIdDir.hasMatch(id)) continue;
      final absPath = p.join(root.path, mediaRel, name);
      sources.add(
        SourceAsset(
          id: id,
          sourcePath: absPath,
          fileName: name,
        ),
      );
    }
    if (sources.isEmpty) return null;

    final dirStat = await AppStorage.stat(mediaRel);
    final recoveredAt = dirStat == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(dirStat.modifiedMs);
    final versionId = _uuid.v4();
    final layoutId = _uuid.v4();
    final version = ProjectVersion(
      id: versionId,
      versionNumber: 1,
      label: 'v1 (recovered)',
      activeLayoutId: layoutId,
      sources: sources,
      layouts: [
        LayoutCanvas(
          id: layoutId,
          name: 'Batch',
          config: const CanvasConfig(),
          photos: [
            for (var i = 0; i < sources.length; i++)
              sources[i].toPhotoItem(order: i, zIndex: i),
          ],
        ),
      ],
      createdAt: recoveredAt,
    );
    debugPrint(
      'ProjectStore: recovered orphan project $projectId '
      '(${sources.length} sources)',
    );
    return Project(
      id: projectId,
      name: 'Recovered project',
      createdAt: recoveredAt,
      updatedAt: DateTime.now(),
      activeVersionId: versionId,
      versions: [version],
    );
  }

  Future<void> _quarantineIndex() async {
    if (!await AppStorage.exists(_indexPath)) return;
    try {
      final stamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final bytes = await AppStorage.readBytes(_indexPath);
      if (bytes != null) {
        await AppStorage.writeBytes(
          '$_indexPath.corrupt.$stamp',
          bytes,
        );
      }
      await AppStorage.delete(_indexPath);
    } catch (e) {
      debugPrint('ProjectStore: quarantine failed ($e)');
    }
  }
}
