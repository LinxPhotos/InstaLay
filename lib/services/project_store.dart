import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/canvas_config.dart';
import '../models/project.dart';

class ProjectStore {
  ProjectStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  static const _projectsFile = 'projects.json';

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
    if (!await file.exists()) return [];
    final raw = jsonDecode(await file.readAsString()) as List;
    return raw
        .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _saveAll(List<Project> projects) async {
    final file = await _indexFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        projects.map((e) => e.toJson()).toList(),
      ),
    );
  }

  Future<Project> create({
    String? name,
    CanvasConfig? config,
  }) async {
    final now = DateTime.now();
    final versionId = _uuid.v4();
    final project = Project(
      id: _uuid.v4(),
      name: name ?? 'Layout ${now.month}/${now.day}',
      createdAt: now,
      updatedAt: now,
      activeVersionId: versionId,
      versions: [
        ProjectVersion(
          id: versionId,
          versionNumber: 1,
          label: 'v1',
          config: config ?? const CanvasConfig(),
          photos: const [],
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

  /// Freeze after posting to Instagram.
  Future<Project> commitToInstagram(Project project) async {
    final active = project.activeVersion;
    if (active == null) throw StateError('No active version');
    final frozen = active.copyWith(
      frozen: true,
      postedToInstagramAt: DateTime.now(),
    );
    final versions =
        project.versions.map((v) => v.id == frozen.id ? frozen : v).toList();
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
    final clone = ProjectVersion(
      id: _uuid.v4(),
      versionNumber: nextNum,
      label: 'v$nextNum',
      config: source.config,
      photos: source.photos
          .map(
            (ph) => PhotoItem(
              id: _uuid.v4(),
              sourcePath: ph.sourcePath,
              fileName: ph.fileName,
              order: ph.order,
              offsetX: ph.offsetX,
              offsetY: ph.offsetY,
              scale: ph.scale,
            ),
          )
          .toList(),
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
}
