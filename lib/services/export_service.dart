import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/canvas_config.dart';
import '../models/export_codec.dart';
import '../models/project.dart';
import '../models/resample_algorithm.dart';
import 'canvas_renderer.dart';
import 'image_codec_service.dart';
import 'project_store.dart';

class ExportResult {
  const ExportResult({
    required this.paths,
    required this.identityThumbPath,
    this.totalBytes = 0,
  });

  final List<String> paths;
  final String? identityThumbPath;
  final int totalBytes;
}

class ExportService {
  ExportService(this._store, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final ProjectStore _store;
  final Uuid _uuid;

  Future<img.Image?> loadImage(String path) async {
    final bytes = await File(path).readAsBytes();
    return ImageCodecService.decodeAsync(bytes, pathHint: path);
  }

  Future<img.Image?> renderFirstFrame(ProjectVersion version) async {
    final ordered = [...version.photos]..sort((a, b) => a.order.compareTo(b.order));
    if (ordered.isEmpty) return null;
    final sources = <img.Image>[];
    for (final photo in ordered) {
      final decoded = await loadImage(photo.sourcePath);
      if (decoded != null) sources.add(decoded);
    }
    if (sources.isEmpty) return null;
    final config = version.config;
    if (config.layoutMode == LayoutMode.tapestry) {
      final slices = CanvasRenderer.renderTapestrySlices(
        sources: sources,
        config: config,
        longEdge: config.exportLongEdge,
        algorithm: config.exportAlgorithm,
      );
      return slices.isEmpty ? null : slices.first;
    }
    return CanvasRenderer.renderPhoto(
      source: sources.first,
      config: config,
      longEdge: config.exportLongEdge,
      algorithm: config.exportAlgorithm,
      photo: ordered.first,
    );
  }

  Future<ExportResult> exportVersion({
    required Project project,
    required ProjectVersion version,
    ResampleAlgorithm? algorithm,
    int? longEdge,
    ExportCodecSettings? codecOverride,
  }) async {
    final config = version.config;
    final edge = longEdge ?? config.exportLongEdge;
    final algo = algorithm ?? config.exportAlgorithm;
    final codec = codecOverride ?? config.codec;
    final outDir = await _store.exportDir(project.id, version.id);

    final sources = <img.Image>[];
    final ordered = [...version.photos]..sort((a, b) => a.order.compareTo(b.order));
    for (final photo in ordered) {
      final decoded = await loadImage(photo.sourcePath);
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
    var totalBytes = 0;
    for (var i = 0; i < frames.length; i++) {
      final encoded = await ImageCodecService.encode(frames[i], codec);
      final name =
          'frame_${(i + 1).toString().padLeft(3, '0')}.${codec.format.extension}';
      final path = p.join(outDir.path, name);
      await File(path).writeAsBytes(encoded.bytes);
      paths.add(path);
      totalBytes += encoded.byteLength;
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
      await File(thumbPath).writeAsBytes(
        CanvasRenderer.encodeJpg(thumb, quality: 85),
      );
    }

    return ExportResult(
      paths: paths,
      identityThumbPath: thumbPath,
      totalBytes: totalBytes,
    );
  }

  Future<Uint8List> previewPhotoBytes({
    required String sourcePath,
    required CanvasConfig config,
    required int longEdge,
    PhotoItem? photo,
    ResampleAlgorithm? algorithm,
  }) async {
    final decoded = await loadImage(sourcePath);
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
