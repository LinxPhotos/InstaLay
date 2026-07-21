import 'dart:async';
import 'dart:io';
import 'dart:isolate';

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
import 'thumb_cache.dart';

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
    ThumbCache? thumbCache,
  })  : _uuid = uuid ?? const Uuid(),
        _thumbCache = thumbCache ?? ThumbCache();

  final ProjectStore _store;
  final Uuid _uuid;
  final ThumbCache _thumbCache;

  /// Sidebar / grid preview long edge — sharp enough on a ~560px panel, cheap to frame.
  static const int interactivePreviewLongEdge = 720;

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

  Future<Uint8List> previewPhotoBytes({
    required String sourcePath,
    required CanvasConfig config,
    required int longEdge,
    PhotoItem? photo,
    ResampleAlgorithm? algorithm,
    bool useDiskCache = true,
  }) async {
    final algo = algorithm ?? ResampleAlgorithm.linear;
    final cacheEnabled = useDiskCache && !kIsWeb;
    String? fingerprint;
    if (cacheEnabled) {
      fingerprint = await _thumbCache.fingerprint(
        sourcePath: sourcePath,
        config: config,
        longEdge: longEdge,
        algorithm: algo,
        photo: photo,
      );
      final hit = await _thumbCache.readDisplayJpeg(fingerprint);
      if (hit != null) return hit;
    }

    final jpeg = await _computePreviewJpeg(
      sourcePath: sourcePath,
      config: config,
      longEdge: longEdge,
      photo: photo,
      algorithm: algo,
    );

    if (fingerprint != null) {
      unawaited(_thumbCache.writeJpeg(fingerprint, jpeg));
    }
    return jpeg;
  }

  /// SCRL-style tapestry carousel frames at interactive preview resolution.
  Future<List<Uint8List>> previewTapestryBytes({
    required List<PhotoItem> photos,
    required CanvasConfig config,
    int? longEdge,
    ResampleAlgorithm? algorithm,
    bool useDiskCache = true,
  }) async {
    final ordered = [...photos]..sort((a, b) => a.order.compareTo(b.order));
    if (ordered.isEmpty) return const [];

    final edge = longEdge ?? interactivePreviewLongEdge;
    final algo = algorithm ?? ResampleAlgorithm.linear;
    final cacheEnabled = useDiskCache && !kIsWeb;
    String? fingerprint;
    if (cacheEnabled) {
      fingerprint = await _thumbCache.tapestryFingerprint(
        photos: ordered,
        config: config,
        longEdge: edge,
        algorithm: algo,
      );
      final hit = await _thumbCache.readDisplayJpeg(fingerprint);
      if (hit != null) {
        return _splitPackedJpegs(hit);
      }
    }

    final bitmaps = <RgbaBitmap>[];
    final maxDecode = ImageCodecService.previewDecodeLongEdge(
      outputLongEdge: edge,
      photoScale: 1,
      fit: FitHint.contain,
    );
    for (final photo in ordered) {
      final decoded = await _decodeForPreview(
        photo.sourcePath,
        maxDecode: maxDecode,
      );
      if (decoded == null) continue;
      bitmaps.add(decoded);
    }
    if (bitmaps.isEmpty) return const [];

    final slices = await Isolate.run(
      () => ImagePipeline.frameTapestryToJpgs(
        TapestryFrameJob(
          sources: bitmaps,
          configJson: config.toJson(),
          longEdge: edge,
          algorithmName: algo.name,
        ),
      ),
    );

    if (fingerprint != null && slices.isNotEmpty) {
      unawaited(_thumbCache.writeJpeg(fingerprint, _packJpegs(slices)));
    }
    return slices;
  }

  Future<Uint8List> _computePreviewJpeg({
    required String sourcePath,
    required CanvasConfig config,
    required int longEdge,
    PhotoItem? photo,
    required ResampleAlgorithm algorithm,
  }) async {
    final fileBytes = await File(sourcePath).readAsBytes();
    final maxDecode = ImageCodecService.previewDecodeLongEdge(
      outputLongEdge: longEdge,
      photoScale: photo?.scale ?? 1,
      fit: switch (config.fitMode) {
        FitMode.contain => FitHint.contain,
        FitMode.cover => FitHint.cover,
        FitMode.fill => FitHint.fill,
      },
    );
    final configJson = config.toJson();
    final photoJson = photo?.toJson();
    final algoName = algorithm.name;
    final lower = sourcePath.toLowerCase();
    final isJxl = lower.endsWith('.jxl');
    final isAvif = lower.endsWith('.avif');

    if (isJxl) {
      return Isolate.run(
        () => ImagePipeline.decodeFrameToJpg(
          DecodeFrameJob(
            fileBytes: fileBytes,
            pathHint: sourcePath,
            maxLongEdge: maxDecode,
            configJson: configJson,
            longEdge: longEdge,
            algorithmName: algoName,
            photoJson: photoJson,
          ),
        ),
      );
    }

    if (!isAvif) {
      final platform = await ImageCodecService.decodeViaPlatform(
        fileBytes,
        maxLongEdge: maxDecode,
      );
      if (platform != null) {
        final rgba = platform.rgba;
        final width = platform.width;
        final height = platform.height;
        return Isolate.run(
          () => ImagePipeline.frameRgbaToJpg(
            FrameJob(
              rgba: rgba,
              width: width,
              height: height,
              configJson: configJson,
              longEdge: longEdge,
              algorithmName: algoName,
              photoJson: photoJson,
            ),
          ),
        );
      }
    }

    final decoded = await ImageCodecService.decodeAsync(
      fileBytes,
      pathHint: sourcePath,
      maxLongEdge: maxDecode,
    );
    if (decoded == null) {
      throw StateError('Cannot decode $sourcePath');
    }
    final rgba = Uint8List.fromList(
      decoded.getBytes(order: img.ChannelOrder.rgba),
    );
    final width = decoded.width;
    final height = decoded.height;
    return Isolate.run(
      () => ImagePipeline.frameRgbaToJpg(
        FrameJob(
          rgba: rgba,
          width: width,
          height: height,
          configJson: configJson,
          longEdge: longEdge,
          algorithmName: algoName,
          photoJson: photoJson,
        ),
      ),
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

  /// Pack multiple JPEGs into one cache blob: [count:u32][len:u32][bytes]...
  static Uint8List _packJpegs(List<Uint8List> parts) {
    var total = 4;
    for (final part in parts) {
      total += 4 + part.length;
    }
    final out = Uint8List(total);
    final bd = ByteData.sublistView(out);
    bd.setUint32(0, parts.length, Endian.little);
    var offset = 4;
    for (final part in parts) {
      bd.setUint32(offset, part.length, Endian.little);
      offset += 4;
      out.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return out;
  }

  static List<Uint8List> _splitPackedJpegs(Uint8List packed) {
    if (packed.length < 4) return const [];
    // Legacy single-JPEG cache entries (SOI) — treat as one slice.
    if (packed[0] == 0xFF && packed[1] == 0xD8) {
      return [packed];
    }
    final bd = ByteData.sublistView(packed);
    final count = bd.getUint32(0, Endian.little);
    if (count == 0 || count > 256) return const [];
    final out = <Uint8List>[];
    var offset = 4;
    for (var i = 0; i < count; i++) {
      if (offset + 4 > packed.length) return const [];
      final len = bd.getUint32(offset, Endian.little);
      offset += 4;
      if (len <= 0 || offset + len > packed.length) return const [];
      out.add(Uint8List.sublistView(packed, offset, offset + len));
      offset += len;
    }
    return out;
  }
}
