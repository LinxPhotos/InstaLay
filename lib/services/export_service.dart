import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
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
import 'app_storage.dart';
import 'export_path_write.dart';
import 'canvas_renderer.dart';
import 'image_codec_service.dart';
import 'image_pipeline.dart';
import 'project_store.dart';
import 'source_bitmap_cache.dart';
import 'source_file_bytes.dart';
import 'text_rasterizer.dart';

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
    final bytes = await readSourceFileBytes(path);
    return ImageCodecService.decodeAsync(
      bytes,
      pathHint: path,
      maxLongEdge: maxLongEdge,
    );
  }

  /// Renders the first export frame (or a cheaper estimate sample when
  /// [longEdge] / [sourceMaxLongEdge] are set below export resolution).
  ///
  /// When [layoutId] is set, samples that layout; otherwise the active layout.
  Future<img.Image?> renderFirstFrame(
    ProjectVersion version, {
    String? layoutId,
    int? longEdge,
    int? sourceMaxLongEdge,
  }) async {
    final layout = layoutId == null
        ? version.activeLayout
        : _layoutById(version, layoutId);
    if (layout == null) return null;
    final ordered = [...layout.photos]..sort((a, b) => a.order.compareTo(b.order));
    if (ordered.isEmpty && layout.texts.isEmpty) return null;
    final config = layout.config;
    final edge = longEdge ?? config.exportLongEdge;
    final decodeEdge = sourceMaxLongEdge ??
        ImageCodecService.previewDecodeLongEdge(
          outputLongEdge: edge,
          photoScale: 1,
          fit: FitHint.cover,
        );
    final sources = <img.Image>[];
    for (final photo in ordered) {
      final decoded =
          await loadImage(photo.sourcePath, maxLongEdge: decodeEdge);
      if (decoded != null) sources.add(decoded);
    }
    if (sources.isEmpty && layout.texts.isEmpty) return null;
    if (config.layoutMode == LayoutMode.tapestry) {
      final textBitmaps = <img.Image>[];
      for (final t in layout.texts) {
        textBitmaps.add(await TextRasterizer.toImage(t));
      }
      final slices = CanvasRenderer.renderTapestrySlices(
        sources: sources,
        photos: ordered,
        texts: layout.texts,
        textBitmaps: textBitmaps,
        config: config,
        longEdge: edge,
        algorithm: config.exportAlgorithm,
        slideCount: layout.slideCount,
      );
      return slices.isEmpty ? null : slices.first;
    }
    if (sources.isEmpty) return null;
    return CanvasRenderer.renderPhoto(
      source: sources.first,
      config: config,
      longEdge: edge,
      algorithm: config.exportAlgorithm,
      photo: ordered.first,
    );
  }

  /// Export every layout in [version] that has photos or text (pan-layout).
  ///
  /// File names are prefixed with layout index + name when more than one
  /// layout is exported (`01_Batch_frame_001.jpg`, …).
  Future<ExportResult> exportVersion({
    required Project project,
    required ProjectVersion version,
    ResampleAlgorithm? algorithm,
    int? longEdge,
    ExportCodecSettings? codecOverride,
    bool? tapestryExportWholeStripOverride,
    List<String>? outputPaths,
    void Function(int completed, int total)? onProgress,
  }) {
    return _exportLayouts(
      project: project,
      version: version,
      layouts: [
        for (final layout in version.layouts)
          if (_layoutHasExportableContent(layout)) layout,
      ],
      algorithm: algorithm,
      longEdge: longEdge,
      codecOverride: codecOverride,
      tapestryExportWholeStripOverride: tapestryExportWholeStripOverride,
      outputPaths: outputPaths,
      onProgress: onProgress,
    );
  }

  /// Export a single layout by id (per-layout).
  Future<ExportResult> exportLayout({
    required Project project,
    required ProjectVersion version,
    required String layoutId,
    ResampleAlgorithm? algorithm,
    int? longEdge,
    ExportCodecSettings? codecOverride,
    bool? tapestryExportWholeStripOverride,
    List<String>? outputPaths,
    void Function(int completed, int total)? onProgress,
  }) {
    final layout = _layoutById(version, layoutId);
    if (layout == null || !_layoutHasExportableContent(layout)) {
      return Future.value(
        const ExportResult(paths: [], identityThumbPath: null),
      );
    }
    return _exportLayouts(
      project: project,
      version: version,
      layouts: [layout],
      algorithm: algorithm,
      longEdge: longEdge,
      codecOverride: codecOverride,
      tapestryExportWholeStripOverride: tapestryExportWholeStripOverride,
      outputPaths: outputPaths,
      onProgress: onProgress,
    );
  }

  /// Planned basenames (`frame_001.jpg`, …) in export order.
  static List<String> plannedExportFileNames({
    required ProjectVersion version,
    required List<LayoutCanvas> layouts,
    required ExportCodecSettings codec,
    bool? tapestryExportWholeStripOverride,
  }) {
    if (layouts.isEmpty) return const [];
    final prefixNames = version.layouts.length > 1;
    final names = <String>[];
    for (final layout in layouts) {
      final config = layout.config;
      final wholeStrip = config.layoutMode == LayoutMode.tapestry &&
          (tapestryExportWholeStripOverride ??
              config.tapestryExportWholeStrip);
      final frameCount = _exportFrameCount(
        layout: layout,
        wholeStrip: wholeStrip,
      );
      if (frameCount == 0) continue;

      final layoutOrdinal = version.layouts.indexWhere((l) => l.id == layout.id);
      final namePrefix = prefixNames
          ? '${_layoutFilePrefix(layoutOrdinal < 0 ? 0 : layoutOrdinal, layout)}_'
          : '';
      for (var i = 0; i < frameCount; i++) {
        final stem = wholeStrip && frameCount == 1
            ? 'tapestry'
            : 'frame_${(i + 1).toString().padLeft(3, '0')}';
        names.add('$namePrefix$stem.${codec.format.extension}');
      }
    }
    return names;
  }

  /// Heuristic per-frame size from canvas dimensions (no decode/render).
  static Future<SizeEstimate> estimateExportFrameSize({
    required CanvasConfig config,
    required int longEdge,
    required ExportCodecSettings codec,
  }) async {
    final frame = CanvasRenderer.sizeFor(config: config, longEdge: longEdge);
    final sample = img.Image(
      width: frame.width,
      height: frame.height,
      numChannels: 4,
    );
    img.fill(sample, color: img.ColorRgba8(128, 128, 128, 255));
    return ImageCodecService.estimateSize(sample, codec);
  }

  Future<ExportResult> _exportLayouts({
    required Project project,
    required ProjectVersion version,
    required List<LayoutCanvas> layouts,
    ResampleAlgorithm? algorithm,
    int? longEdge,
    ExportCodecSettings? codecOverride,
    bool? tapestryExportWholeStripOverride,
    List<String>? outputPaths,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (layouts.isEmpty) {
      return const ExportResult(paths: [], identityThumbPath: null);
    }
    final outDir = await _store.exportDir(project.id, version.id);
    final codec = codecOverride ?? layouts.first.config.codec;
    final plannedNames = plannedExportFileNames(
      version: version,
      layouts: layouts,
      codec: codec,
      tapestryExportWholeStripOverride: tapestryExportWholeStripOverride,
    );
    if (plannedNames.isEmpty) {
      return const ExportResult(paths: [], identityThumbPath: null);
    }
    if (outputPaths != null && outputPaths.length != plannedNames.length) {
      throw ArgumentError(
        'outputPaths length ${outputPaths.length} != ${plannedNames.length} frames',
      );
    }

    final paths = <String>[];
    var totalBytes = 0;
    String? thumbPath;
    var completed = 0;
    final totalFrames = plannedNames.length;
    onProgress?.call(completed, totalFrames);

    var nameIndex = 0;
    for (final layout in layouts) {
      final config = layout.config;
      final edge = longEdge ?? config.exportLongEdge;
      final algo = algorithm ?? config.exportAlgorithm;
      final layoutCodec = codecOverride ?? config.codec;

      final ordered = [...layout.photos]
        ..sort((a, b) => a.order.compareTo(b.order));
      final sources = <img.Image>[];
      for (final photo in ordered) {
        final decoded = await loadImage(photo.sourcePath);
        if (decoded != null) sources.add(decoded);
      }

      final textBitmaps = <img.Image>[];
      if (config.layoutMode == LayoutMode.tapestry) {
        for (final t in layout.texts) {
          textBitmaps.add(await TextRasterizer.toImage(t));
        }
      }

      final wholeStrip = config.layoutMode == LayoutMode.tapestry &&
          (tapestryExportWholeStripOverride ??
              config.tapestryExportWholeStrip);

      final encodeJob = ExportLayoutEncodeJob(
        sources: [for (final s in sources) _toRgbaBitmap(s)],
        textBitmaps: [for (final t in textBitmaps) _toRgbaBitmap(t)],
        photoJsons: [for (final photo in ordered) photo.toJson()],
        textJsons: [for (final t in layout.texts) t.toJson()],
        configJson: config.toJson(),
        longEdge: edge,
        algorithmName: algo.name,
        slideCount: layout.slideCount,
        isTapestry: config.layoutMode == LayoutMode.tapestry,
        wholeStrip: wholeStrip,
        codecJson: layoutCodec.toJson(),
      );

      List<Uint8List> frameBytes;
      if (layoutCodec.format == ExportFormat.avif) {
        final rgbas = await Isolate.run(
          () => ImagePipeline.exportLayoutFrameRgbas(encodeJob),
        );
        frameBytes = [];
        for (final rgba in rgbas) {
          await Future<void>.delayed(Duration.zero);
          final image = img.Image.fromBytes(
            width: rgba.width,
            height: rgba.height,
            bytes: rgba.rgba.buffer,
            numChannels: 4,
            order: img.ChannelOrder.rgba,
          );
          frameBytes.add(
            (await ImageCodecService.encode(image, layoutCodec)).bytes,
          );
        }
      } else {
        frameBytes = await Isolate.run(
          () => ImagePipeline.exportLayoutEncodedFrames(encodeJob),
        );
      }

      for (final bytes in frameBytes) {
        final name = plannedNames[nameIndex];
        final dest = outputPaths != null
            ? outputPaths[nameIndex]
            : p.join(outDir.path, name);
        await _writeExportFile(dest, bytes);
        paths.add(dest);
        totalBytes += bytes.lengthInBytes;
        nameIndex++;
        completed++;
        onProgress?.call(completed, totalFrames);
      }

      if (thumbPath == null &&
          (sources.isNotEmpty || layout.texts.isNotEmpty)) {
        final jpeg = await Isolate.run(
          () => ImagePipeline.identityThumbToJpg(
            IdentityThumbJob(
              sources: encodeJob.sources,
              configJson: encodeJob.configJson,
              photoJsons: encodeJob.photoJsons,
              textJsons: encodeJob.textJsons,
              textBitmaps: encodeJob.textBitmaps,
              slideCount: layout.slideCount,
            ),
          ),
        );
        thumbPath = p.join(outDir.path, 'identity_${_uuid.v4()}.jpg');
        await AppStorage.writeBytes(thumbPath, jpeg);
      }
    }

    return ExportResult(
      paths: paths,
      identityThumbPath: thumbPath,
      totalBytes: totalBytes,
    );
  }

  static int _exportFrameCount({
    required LayoutCanvas layout,
    required bool wholeStrip,
  }) {
    if (layout.config.layoutMode == LayoutMode.tapestry) {
      if (layout.photos.isEmpty && layout.texts.isEmpty) return 0;
      return wholeStrip ? 1 : layout.slideCount;
    }
    return layout.photos.isEmpty ? 0 : layout.photos.length;
  }

  static Future<void> _writeExportFile(String path, Uint8List bytes) =>
      writeExportPath(path, bytes);

  static bool _layoutHasExportableContent(LayoutCanvas layout) =>
      layout.photos.isNotEmpty || layout.texts.isNotEmpty;

  static LayoutCanvas? _layoutById(ProjectVersion version, String layoutId) {
    for (final layout in version.layouts) {
      if (layout.id == layoutId) return layout;
    }
    return null;
  }

  static String _layoutFilePrefix(int index, LayoutCanvas layout) {
    final safe = layout.name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final label = safe.isEmpty ? 'layout' : safe;
    return '${(index + 1).toString().padLeft(2, '0')}_$label';
  }

  /// Rebuild the home-screen preview for [version] and return its path.
  ///
  /// Home-list preview for one [layout] (batch or tapestry).
  Future<String?> refreshLayoutPreviewThumb({
    required Project project,
    required ProjectVersion version,
    required LayoutCanvas layout,
  }) async {
    if (layout.photos.isEmpty && layout.texts.isEmpty) return null;

    final ordered = [...layout.photos]..sort((a, b) => a.order.compareTo(b.order));
    final sources = <img.Image>[];
    for (final photo in ordered) {
      final decoded = await loadImage(
        photo.sourcePath,
        maxLongEdge: 720,
      );
      if (decoded != null) sources.add(decoded);
    }
    if (sources.isEmpty && layout.texts.isEmpty) return null;

    final textBitmaps = <img.Image>[];
    if (layout.config.layoutMode == LayoutMode.tapestry) {
      for (final t in layout.texts) {
        textBitmaps.add(await TextRasterizer.toImage(t));
      }
    }

    final jpeg = await Isolate.run(
      () => ImagePipeline.identityThumbToJpg(
        IdentityThumbJob(
          sources: [
            for (final source in sources) _toRgbaBitmap(source),
          ],
          configJson: layout.config.toJson(),
          photoJsons: [for (final photo in ordered) photo.toJson()],
          textJsons: [for (final t in layout.texts) t.toJson()],
          textBitmaps: [
            for (final bitmap in textBitmaps) _toRgbaBitmap(bitmap),
          ],
          slideCount: layout.slideCount,
        ),
      ),
    );

    final media = await _store.mediaDir(project.id);
    final thumbPath = p.join(
      media.path,
      'preview_${version.id}_${layout.id}.jpg',
    );
    await AppStorage.writeBytes(thumbPath, jpeg);
    return thumbPath;
  }

  /// Identity layout preview (legacy filename); prefer [refreshLayoutPreviewThumb].
  Future<String?> refreshIdentityThumb({
    required Project project,
    required ProjectVersion version,
  }) async {
    final layout = version.identityLayout;
    if (layout == null) return null;
    return refreshLayoutPreviewThumb(
      project: project,
      version: version,
      layout: layout,
    );
  }

  static RgbaBitmap _toRgbaBitmap(img.Image image) {
    return RgbaBitmap(
      rgba: Uint8List.fromList(image.getBytes(order: img.ChannelOrder.rgba)),
      width: image.width,
      height: image.height,
    );
  }

  /// Warm the source RGBA cache after import (background-friendly).
  Future<void> warmSourceBitmap(
    String sourcePath, {
    int? maxLongEdge,
  }) async {
    final budget = maxLongEdge ?? interactiveSourceLongEdge;
    await _ensureSource(sourcePath, budget);
  }

  /// Unframed source thumbnail (tapestry photo rail) — no canvas matte/fit.
  Future<RgbaBitmap> previewSourceRgba({
    required String sourcePath,
    int longEdge = 360,
  }) async {
    // Prefer the warmed interactive decode; downscale for the rail.
    final source = await _ensureSource(sourcePath, interactiveSourceLongEdge);
    if (math.max(source.width, source.height) <= longEdge) return source;
    return Isolate.run(
      () => ImagePipeline.downscaleToLongEdge(source, longEdge),
    );
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
    int slideCount = 1,
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
          photoJsons: [for (final p in ordered) p.toJson()],
          slideCount: slideCount,
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
    final fileBytes = await readSourceFileBytes(sourcePath);
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
