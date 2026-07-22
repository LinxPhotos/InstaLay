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
    final bytes = await File(path).readAsBytes();
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
    );
  }

  Future<ExportResult> _exportLayouts({
    required Project project,
    required ProjectVersion version,
    required List<LayoutCanvas> layouts,
    ResampleAlgorithm? algorithm,
    int? longEdge,
    ExportCodecSettings? codecOverride,
  }) async {
    if (layouts.isEmpty) {
      return const ExportResult(paths: [], identityThumbPath: null);
    }
    final outDir = await _store.exportDir(project.id, version.id);
    final prefixNames = version.layouts.length > 1;
    final paths = <String>[];
    var totalBytes = 0;
    String? thumbPath;

    for (final layout in layouts) {
      final config = layout.config;
      final edge = longEdge ?? config.exportLongEdge;
      final algo = algorithm ?? config.exportAlgorithm;
      final codec = codecOverride ?? config.codec;

      final sources = <img.Image>[];
      final ordered = [...layout.photos]
        ..sort((a, b) => a.order.compareTo(b.order));
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

      final frames = <img.Image>[];
      if (config.layoutMode == LayoutMode.tapestry) {
        frames.addAll(
          CanvasRenderer.renderTapestrySlices(
            sources: sources,
            photos: ordered,
            texts: layout.texts,
            textBitmaps: textBitmaps,
            config: config,
            longEdge: edge,
            algorithm: algo,
            slideCount: layout.slideCount,
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

      final layoutOrdinal = version.layouts.indexWhere((l) => l.id == layout.id);
      final namePrefix = prefixNames
          ? '${_layoutFilePrefix(layoutOrdinal < 0 ? 0 : layoutOrdinal, layout)}_'
          : '';
      for (var i = 0; i < frames.length; i++) {
        final encoded = await ImageCodecService.encode(frames[i], codec);
        final name =
            '${namePrefix}frame_${(i + 1).toString().padLeft(3, '0')}.${codec.format.extension}';
        final path = p.join(outDir.path, name);
        await File(path).writeAsBytes(encoded.bytes);
        paths.add(path);
        totalBytes += encoded.byteLength;
      }

      if (thumbPath == null &&
          (sources.isNotEmpty || layout.texts.isNotEmpty)) {
        final thumb = CanvasRenderer.renderIdentityThumb(
          sources: sources,
          config: config,
          height: 160,
          maxWidth: 640,
          photos: ordered,
          slideCount: layout.slideCount,
          texts: layout.texts,
          textBitmaps: textBitmaps,
        );
        thumbPath = p.join(outDir.path, 'identity_${_uuid.v4()}.jpg');
        await File(thumbPath).writeAsBytes(
          CanvasRenderer.encodeJpg(thumb, quality: 85),
        );
      }
    }

    return ExportResult(
      paths: paths,
      identityThumbPath: thumbPath,
      totalBytes: totalBytes,
    );
  }

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
  /// Uses [ProjectVersion.identityLayout] (active with photos, else first with
  /// photos). Renders a framed canvas at that layout's aspect.
  Future<String?> refreshIdentityThumb({
    required Project project,
    required ProjectVersion version,
  }) async {
    final layout = version.identityLayout;
    if (layout == null) return null;
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

    final thumb = CanvasRenderer.renderIdentityThumb(
      sources: sources,
      config: layout.config,
      height: 160,
      maxWidth: 640,
      photos: ordered,
      slideCount: layout.slideCount,
      texts: layout.texts,
      textBitmaps: textBitmaps,
    );

    final media = await _store.mediaDir(project.id);
    final thumbPath = p.join(media.path, 'preview_${version.id}.jpg');
    await File(thumbPath).writeAsBytes(
      CanvasRenderer.encodeJpg(thumb, quality: 85),
      flush: true,
    );
    return thumbPath;
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
