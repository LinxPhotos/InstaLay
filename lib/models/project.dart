import 'canvas_config.dart';

class PhotoItem {
  const PhotoItem({
    required this.id,
    required this.sourcePath,
    this.fileName,
    this.order = 0,
    this.offsetX = 0,
    this.offsetY = 0,
    this.scale = 1,
  });

  final String id;
  final String sourcePath;
  final String? fileName;
  final int order;
  final double offsetX;
  final double offsetY;
  final double scale;

  PhotoItem copyWith({
    String? sourcePath,
    String? fileName,
    int? order,
    double? offsetX,
    double? offsetY,
    double? scale,
  }) {
    return PhotoItem(
      id: id,
      sourcePath: sourcePath ?? this.sourcePath,
      fileName: fileName ?? this.fileName,
      order: order ?? this.order,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourcePath': sourcePath,
        'fileName': fileName,
        'order': order,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'scale': scale,
      };

  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    return PhotoItem(
      id: json['id'] as String,
      sourcePath: json['sourcePath'] as String,
      fileName: json['fileName'] as String?,
      order: json['order'] as int? ?? 0,
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
    );
  }
}

/// A frozen or editable snapshot of a layout.
class ProjectVersion {
  const ProjectVersion({
    required this.id,
    required this.versionNumber,
    required this.config,
    required this.photos,
    required this.createdAt,
    this.label,
    this.frozen = false,
    this.postedToInstagramAt,
    this.previewThumbPath,
    this.exportPaths = const [],
  });

  final String id;
  final int versionNumber;
  final String? label;
  final CanvasConfig config;
  final List<PhotoItem> photos;
  final DateTime createdAt;
  final bool frozen;
  final DateTime? postedToInstagramAt;
  final String? previewThumbPath;
  final List<String> exportPaths;

  bool get isPosted => postedToInstagramAt != null;

  ProjectVersion copyWith({
    String? label,
    CanvasConfig? config,
    List<PhotoItem>? photos,
    bool? frozen,
    DateTime? postedToInstagramAt,
    String? previewThumbPath,
    List<String>? exportPaths,
  }) {
    return ProjectVersion(
      id: id,
      versionNumber: versionNumber,
      label: label ?? this.label,
      config: config ?? this.config,
      photos: photos ?? this.photos,
      createdAt: createdAt,
      frozen: frozen ?? this.frozen,
      postedToInstagramAt: postedToInstagramAt ?? this.postedToInstagramAt,
      previewThumbPath: previewThumbPath ?? this.previewThumbPath,
      exportPaths: exportPaths ?? this.exportPaths,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'versionNumber': versionNumber,
        'label': label,
        'config': config.toJson(),
        'photos': photos.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'frozen': frozen,
        'postedToInstagramAt': postedToInstagramAt?.toIso8601String(),
        'previewThumbPath': previewThumbPath,
        'exportPaths': exportPaths,
      };

  factory ProjectVersion.fromJson(Map<String, dynamic> json) {
    return ProjectVersion(
      id: json['id'] as String,
      versionNumber: json['versionNumber'] as int? ?? 1,
      label: json['label'] as String?,
      config: CanvasConfig.fromJson(
        Map<String, dynamic>.from(json['config'] as Map? ?? const {}),
      ),
      photos: (json['photos'] as List? ?? const [])
          .map((e) => PhotoItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      frozen: json['frozen'] as bool? ?? false,
      postedToInstagramAt: json['postedToInstagramAt'] != null
          ? DateTime.tryParse(json['postedToInstagramAt'] as String)
          : null,
      previewThumbPath: json['previewThumbPath'] as String?,
      exportPaths: (json['exportPaths'] as List? ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.versions,
    this.activeVersionId,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProjectVersion> versions;
  final String? activeVersionId;

  ProjectVersion? get activeVersion {
    if (versions.isEmpty) return null;
    if (activeVersionId != null) {
      for (final v in versions) {
        if (v.id == activeVersionId) return v;
      }
    }
    return versions.last;
  }

  Project copyWith({
    String? name,
    DateTime? updatedAt,
    List<ProjectVersion>? versions,
    String? activeVersionId,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      versions: versions ?? this.versions,
      activeVersionId: activeVersionId ?? this.activeVersionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'versions': versions.map((v) => v.toJson()).toList(),
        'activeVersionId': activeVersionId,
      };

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      versions: (json['versions'] as List? ?? const [])
          .map(
            (e) => ProjectVersion.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      activeVersionId: json['activeVersionId'] as String?,
    );
  }
}
