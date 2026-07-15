import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/canvas_config.dart';
import '../models/export_codec.dart';
import '../models/project.dart';
import '../models/resample_algorithm.dart';
import 'canvas_renderer.dart';
import 'image_codec_service.dart';

/// Sendable payload for background preview / frame work.
class FrameJob {
  const FrameJob({
    required this.rgba,
    required this.width,
    required this.height,
    required this.configJson,
    required this.longEdge,
    required this.algorithmName,
    this.photoJson,
    this.quality = 88,
  });

  final Uint8List rgba;
  final int width;
  final int height;
  final Map<String, dynamic> configJson;
  final int longEdge;
  final String algorithmName;
  final Map<String, dynamic>? photoJson;
  final int quality;
}

/// Sendable payload when platform decode is unavailable (JXL / pure-Dart).
class DecodeFrameJob {
  const DecodeFrameJob({
    required this.fileBytes,
    required this.configJson,
    required this.longEdge,
    required this.algorithmName,
    this.pathHint,
    this.maxLongEdge,
    this.photoJson,
    this.quality = 88,
  });

  final Uint8List fileBytes;
  final String? pathHint;
  final int? maxLongEdge;
  final Map<String, dynamic> configJson;
  final int longEdge;
  final String algorithmName;
  final Map<String, dynamic>? photoJson;
  final int quality;
}

/// JPEG for [Image.memory] + JXL for disk cache, from one framed render.
class ThumbPacket {
  const ThumbPacket({required this.jpeg, required this.jxl});

  final Uint8List jpeg;
  final Uint8List jxl;
}

/// CPU framing + JPEG/JXL encode helpers that run inside [Isolate.run].
abstract final class ImagePipeline {
  static const _thumbJxl = ExportCodecSettings(
    format: ExportFormat.jpegXl,
    jxlMode: JxlMode.lossy,
    jxlQuality: 85,
  );

  static Uint8List frameRgbaToJpg(FrameJob job) => frameRgbaToThumb(job).jpeg;

  static ThumbPacket frameRgbaToThumb(FrameJob job) {
    final source = img.Image.fromBytes(
      width: job.width,
      height: job.height,
      bytes: job.rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return _frameAndPacket(
      source: source,
      configJson: job.configJson,
      longEdge: job.longEdge,
      algorithmName: job.algorithmName,
      photoJson: job.photoJson,
      quality: job.quality,
    );
  }

  static Uint8List decodeFrameToJpg(DecodeFrameJob job) =>
      decodeFrameToThumb(job).jpeg;

  static ThumbPacket decodeFrameToThumb(DecodeFrameJob job) {
    var source = ImageCodecService.decode(
      job.fileBytes,
      pathHint: job.pathHint,
    );
    if (source == null) {
      throw StateError('Cannot decode ${job.pathHint ?? 'bytes'}');
    }
    source = ImageCodecService.limitLongEdge(source, job.maxLongEdge);
    return _frameAndPacket(
      source: source,
      configJson: job.configJson,
      longEdge: job.longEdge,
      algorithmName: job.algorithmName,
      photoJson: job.photoJson,
      quality: job.quality,
    );
  }

  /// Cache hit: JXL on disk → JPEG for Flutter [Image].
  static Uint8List jxlCacheToJpg(Uint8List jxl, {int quality = 88}) {
    final decoded = ImageCodecService.decode(jxl, pathHint: 'cache.jxl');
    if (decoded == null) {
      throw StateError('Corrupt JXL thumb cache entry');
    }
    return CanvasRenderer.encodeJpg(decoded, quality: quality);
  }

  static ThumbPacket _frameAndPacket({
    required img.Image source,
    required Map<String, dynamic> configJson,
    required int longEdge,
    required String algorithmName,
    Map<String, dynamic>? photoJson,
    required int quality,
  }) {
    final framed = _frame(
      source: source,
      configJson: configJson,
      longEdge: longEdge,
      algorithmName: algorithmName,
      photoJson: photoJson,
    );
    return ThumbPacket(
      jpeg: CanvasRenderer.encodeJpg(framed, quality: quality),
      jxl: ImageCodecService.encodeJxl(framed, settings: _thumbJxl),
    );
  }

  static img.Image _frame({
    required img.Image source,
    required Map<String, dynamic> configJson,
    required int longEdge,
    required String algorithmName,
    Map<String, dynamic>? photoJson,
  }) {
    final config = CanvasConfig.fromJson(configJson);
    final photo = photoJson == null ? null : PhotoItem.fromJson(photoJson);
    final algorithm = ResampleAlgorithm.values.firstWhere(
      (a) => a.name == algorithmName,
      orElse: () => ResampleAlgorithm.defaultThumbnail,
    );
    return CanvasRenderer.renderPhoto(
      source: source,
      config: config,
      longEdge: longEdge,
      algorithm: algorithm,
      photo: photo,
    );
  }
}
