import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/canvas_config.dart';
import '../models/export_codec.dart';
import '../models/project.dart';
import '../models/resample_algorithm.dart';
import 'canvas_renderer.dart';
import 'image_codec_service.dart';
import 'image_pipeline.dart';
import 'project_store.dart';
import 'source_bitmap_cache.dart';

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
  ExportService(
    this._store, {
    Uuid? uuid,
    SourceBitmapCache? sourceBitmapCache,
  })  : _uuid = uuid ?? const Uuid(),
        _sourceCache = sourceBitmapCache ?? SourceBitmapCache();

  final ProjectStore _store;
  final Uuid _uuid;
  final SourceBitmapCache _sourceCache;

  /// Sidebar / grid preview long edge — sharp enough on a ~560px panel, cheap to frame.
  static const int interactivePreviewLongEdge = 720;

  /// Default source-decode budget for interactive edits (cover @ 720 → 1440).
  static int get interactiveSourceLongEdge =>
      ImageCodecService.previewDecodeLongEdge(
        outputLongEdge: interactivePreviewLongEdge,
        photoScale: 1,
        fit: FitHint.cover,
      );

  SourceBitmapCache get sourceBitmapCache => _sourceCache;

  Future<img.Image?> loadImage(String path, {int? maxLongEdge}) async {
    final bytes = await File(path).readAsBytes();
    return ImageCodecService.decodeAsync(
      bytes,
      pathHint: path,
      maxLongEdge: maxLongEdge,
    );
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

  /// Warm the source RGBA cache after import (background-friendly).
  Future<void> warmSourceBitmap(
    String sourcePath, {
    int? maxLongEdge,
  }) async {
    if (kIsWeb) return;
    final budget = maxLongEdge ?? interactiveSourceLongEdge;
    await _ensureSource(sourcePath, budget);
  }

  /// Framed interactive preview as RGBA (no JPEG encode).
  Future<RgbaBitmap> previewPhotoRgba({
    required String sourcePath,
    required CanvasConfig config,
    required int longEdge,
    PhotoItem? photo,
    ResampleAlgorithm? algorithm,
  }) async {
    final algo = algorithm ?? ResampleAlgorithm.linear;
    final needed = ImageCodecService.previewDecodeLongEdge(
      outputLongEdge: longEdge,
      photoScale: photo?.scale ?? 1,
      fit: switch (config.fitMode) {
        FitMode.contain => FitHint.contain,
        FitMode.cover => FitHint.cover,
        FitMode.fill => FitHint.fill,
      },
    );
    final budget = math.max(interactiveSourceLongEdge, needed);
    final source = await _ensureSource(sourcePath, budget);
    return Isolate.run(
      () => ImagePipeline.frameRgbaToRgba(
        FrameJob(
          rgba: source.rgba,
          width: source.width,
          height: source.height,
          configJson: config.toJson(),
          longEdge: longEdge,
          algorithmName: algo.name,
          photoJson: photo?.toJson(),
        ),
      ),
    );
  }

  /// SCRL-style tapestry carousel frames at interactive preview resolution.
  Future<List<RgbaBitmap>> previewTapestryRgba({
    required List<PhotoItem> photos,
    required CanvasConfig config,
    int? longEdge,
    ResampleAlgorithm? algorithm,
  }) async {
    final ordered = [...photos]..sort((a, b) => a.order.compareTo(b.order));
    if (ordered.isEmpty) return const [];

    final edge = longEdge ?? interactivePreviewLongEdge;
    final algo = algorithm ?? ResampleAlgorithm.linear;
    final needed = ImageCodecService.previewDecodeLongEdge(
      outputLongEdge: edge,
      photoScale: 1,
      fit: FitHint.contain,
    );
    final budget = math.max(interactiveSourceLongEdge, needed);

    final bitmaps = <RgbaBitmap>[];
    for (final photo in ordered) {
      try {
        bitmaps.add(await _ensureSource(photo.sourcePath, budget));
      } catch (_) {
        // Skip undecodable sources.
      }
    }
    if (bitmaps.isEmpty) return const [];

    return Isolate.run(
      () => ImagePipeline.frameTapestryToRgbas(
        TapestryFrameJob(
          sources: bitmaps,
          configJson: config.toJson(),
          longEdge: edge,
          algorithmName: algo.name,
        ),
      ),
    );
  }

  Future<RgbaBitmap> _ensureSource(String sourcePath, int maxDecode) {
    return _sourceCache.ensure(
      sourcePath: sourcePath,
      maxLongEdge: maxDecode,
      decode: () => _decodeForPreview(sourcePath, maxDecode: maxDecode),
    );
  }

  Future<RgbaBitmap?> _decodeForPreview(
    String sourcePath, {
    required int maxDecode,
  }) async {
    final fileBytes = await File(sourcePath).readAsBytes();
    final lower = sourcePath.toLowerCase();
    final isAvif = lower.endsWith('.avif');
    final isJxl = lower.endsWith('.jxl');

    if (!isAvif && !isJxl) {
      final platform = await ImageCodecService.decodeViaPlatform(
        fileBytes,
        maxLongEdge: maxDecode,
      );
      if (platform != null) {
        return RgbaBitmap(
          rgba: platform.rgba,
          width: platform.width,
          height: platform.height,
        );
      }
    }

    final decoded = await ImageCodecService.decodeAsync(
      fileBytes,
      pathHint: sourcePath,
      maxLongEdge: maxDecode,
    );
    if (decoded == null) return null;
    return RgbaBitmap(
      rgba: Uint8List.fromList(decoded.getBytes(order: img.ChannelOrder.rgba)),
      width: decoded.width,
      height: decoded.height,
    );
  }
}

/// Convert framed RGBA into a [ui.Image] for [RawImage] display.
Future<ui.Image> rgbaToUiImage(RgbaBitmap bitmap) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bitmap.rgba,
    bitmap.width,
    bitmap.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
