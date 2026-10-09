import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/project.dart';
import 'app_storage.dart';
import 'json_storage.dart';

/// Rolling on-disk snapshots before each project index write (undo bad saves).
class ProjectHistoryEntry {
  const ProjectHistoryEntry({
    required this.id,
    required this.savedAt,
    required this.relativePath,
  });

  final String id;
  final DateTime savedAt;
  final String relativePath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'savedAt': savedAt.toUtc().toIso8601String(),
        'relativePath': relativePath,
      };

  factory ProjectHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ProjectHistoryEntry(
      id: json['id'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
      relativePath: json['relativePath'] as String,
    );
  }
}

abstract final class ProjectHistory {
  ProjectHistory._();

  static const maxSnapshotsPerProject = 40;
  static const _uuid = Uuid();

  static String _historyRoot(String projectId) =>
      p.join('projects', projectId, 'history');

  static String _manifestPath(String projectId) =>
      p.join(_historyRoot(projectId), 'manifest.json');

  /// Writes [previous] to history when it differs from the incoming save.
  static Future<void> recordIfChanged({
    required Project previous,
    required Project next,
  }) async {
    if (projectDataEquals(previous, next)) return;
    await recordSnapshot(previous);
  }

  /// Compare project payload, ignoring [Project.updatedAt] bumps.
  static bool projectDataEquals(Project a, Project b) {
    final ja = Map<String, dynamic>.from(a.toJson())..remove('updatedAt');
    final jb = Map<String, dynamic>.from(b.toJson())..remove('updatedAt');
    return _jsonCanonical(ja) == _jsonCanonical(jb);
  }

  static Future<void> recordSnapshot(Project project) async {
    await AppStorage.init();
    final id = _uuid.v4();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final fileName = '$stamp-$id.json';
    final relativePath = p.join(_historyRoot(project.id), 'snapshots', fileName);
    await writeJsonAtPath(relativePath, project.toJson());

    final manifest = await _loadManifest(project.id);
    manifest.insert(
      0,
      ProjectHistoryEntry(
        id: id,
        savedAt: DateTime.now(),
        relativePath: relativePath,
      ),
    );
    while (manifest.length > maxSnapshotsPerProject) {
      final dropped = manifest.removeLast();
      try {
        await AppStorage.delete(dropped.relativePath);
      } catch (e) {
        debugPrint('ProjectHistory: delete old snapshot failed ($e)');
      }
    }
    await writeJsonAtPath(
      _manifestPath(project.id),
      manifest.map((e) => e.toJson()).toList(),
    );
  }

  static Future<List<ProjectHistoryEntry>> listEntries(String projectId) async {
    await AppStorage.init();
    return _loadManifest(projectId);
  }

  static Future<Project?> loadSnapshotProject(String relativePath) async {
    await AppStorage.init();
    final decoded = await readJsonAtPath(relativePath, label: 'ProjectHistory');
    if (decoded is! Map) return null;
    try {
      return Project.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('ProjectHistory: parse snapshot failed ($e)');
      return null;
    }
  }

  /// Replace live project data with a snapshot (same project id / media paths).
  static Future<Project> restoreSnapshot({
    required Project current,
    required ProjectHistoryEntry entry,
  }) async {
    final snap = await loadSnapshotProject(entry.relativePath);
    if (snap == null) {
      throw StateError('Snapshot file missing or corrupt');
    }
    if (snap.id != current.id) {
      throw StateError('Snapshot project id mismatch');
    }
    return Project(
      id: current.id,
      name: current.name,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      versions: snap.versions,
      activeVersionId: snap.activeVersionId ?? current.activeVersionId,
    );
  }

  static Future<List<ProjectHistoryEntry>> _loadManifest(String projectId) async {
    final decoded =
        await readJsonAtPath(_manifestPath(projectId), label: 'ProjectHistory');
    if (decoded is! List) return [];
    return [
      for (final e in decoded)
        if (e is Map)
          ProjectHistoryEntry.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  static String _jsonCanonical(Object json) =>
      jsonEncode(json, toEncodable: (o) => o);
}
