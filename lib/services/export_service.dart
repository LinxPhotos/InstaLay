import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/canvas_config.dart';
import '../models/project.dart';
import '../models/resample_algorithm.dart';
import 'canvas_renderer.dart';
import 'project_store.dart';

class ExportResult {
  const ExportResult({
    required this.paths,
    required this.identityThumbPath,
  });

  final List<String> paths;
  final String? identityThumbPath;
}

class ExportService {
  ExportService(this._store, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final ProjectStore _store;
  final Uuid _uuid;

  Future<img.Image?> _load(String path) async {
    final bytes = await File(path).readAsBytes();
    return img.decodeImage(bytes);
  }

  Future<ExportResult> exportVersion({
    required Project project,
    required ProjectVersion version,
    ResampleAlgorithm? algorithm,
    int? longEdge,
  }) async {
    final config = version.config;
    final edge = longEdge ?? config.exportLongEdge;
    final algo = algorithm ?? config.exportAlgorithm;
    final outDir = await _store.exportDir(project.id, version.id);

    final sources = <img.Image>[];
    final ordered = [...version.photos]..sort((a, b) => a.order.compareTo(b.order));
    for (final photo in ordered) {
      final decoded = await _load(photo.sourcePath);
      if (decoded != null) sources.add(decoded);
    }

    final frames = <img.Image>[];
    if (config.layoutMode == LayoutMode.tapestry) {
      frames.addAll(
        CanvasRenderer.renderTapestrySlices(
          sources: sources,
          config: config,
          longEdge: edge,
          algorithm: algo,
        ),
      );
    } else {
      for (var i = 0; i < sources.length; i++) {
        frames.add(
          CanvasRenderer.renderPhoto(
            source: sources[i],
            config: config,
            longEdge: edge,
            algorithm: algo,
            photo: ordered[i],
          ),
        );
      }
    }

    final paths = <String>[];
    for (var i = 0; i < frames.length; i++) {
      final name = 'frame_${(i + 1).toString().padLeft(3, '0')}.jpg';
      final path = p.join(outDir.path, name);
      await File(path).writeAsBytes(CanvasRenderer.encodeJpg(frames[i]));
      paths.add(path);
    }

    String? thumbPath;
    if (sources.isNotEmpty) {
      final thumb = CanvasRenderer.renderIdentityThumb(
        sources: sources,
        config: config,
        height: 160,
        maxWidth: 640,
      );
      thumbPath = p.join(outDir.path, 'identity_${_uuid.v4()}.jpg');
      await File(thumbPath).writeAsBytes(CanvasRenderer.encodeJpg(thumb, quality: 85));
    }

    return ExportResult(paths: paths, identityThumbPath: thumbPath);
  }

  Future<Uint8List> previewPhotoBytes({
    required String sourcePath,
    required CanvasConfig config,
    required int longEdge,
    PhotoItem? photo,
    ResampleAlgorithm? algorithm,
  }) async {
    final decoded = await _load(sourcePath);
    if (decoded == null) {
      throw StateError('Cannot decode $sourcePath');
    }
    final framed = CanvasRenderer.renderPhoto(
      source: decoded,
      config: config,
      longEdge: longEdge,
      algorithm: algorithm ?? config.thumbnailAlgorithm,
      photo: photo,
    );
    return CanvasRenderer.encodeJpg(framed, quality: 88);
  }
}
