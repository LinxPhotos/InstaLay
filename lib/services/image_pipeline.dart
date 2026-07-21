import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/canvas_config.dart';
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
    this.quality = 82,
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
    this.quality = 82,
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

/// Multi-source tapestry framing job (RGBA bitmaps already decoded).
class TapestryFrameJob {
  const TapestryFrameJob({
    required this.sources,
    required this.configJson,
    required this.longEdge,
    required this.algorithmName,
    this.quality = 82,
  });

  final List<RgbaBitmap> sources;
  final Map<String, dynamic> configJson;
  final int longEdge;
  final String algorithmName;
  final int quality;
}

class RgbaBitmap {
  const RgbaBitmap({
    required this.rgba,
    required this.width,
    required this.height,
  });

  final Uint8List rgba;
  final int width;
  final int height;
}

/// CPU framing + JPEG encode helpers that run inside [Isolate.run].
abstract final class ImagePipeline {
  static Uint8List frameRgbaToJpg(FrameJob job) {
    final source = img.Image.fromBytes(
      width: job.width,
      height: job.height,
      bytes: job.rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final framed = _framePhoto(
      source: source,
      configJson: job.configJson,
      longEdge: job.longEdge,
      algorithmName: job.algorithmName,
      photoJson: job.photoJson,
    );
    return CanvasRenderer.encodeJpg(framed, quality: job.quality);
  }

  static Uint8List decodeFrameToJpg(DecodeFrameJob job) {
    var source = ImageCodecService.decode(
      job.fileBytes,
      pathHint: job.pathHint,
    );
    if (source == null) {
      throw StateError('Cannot decode ${job.pathHint ?? 'bytes'}');
    }
    source = ImageCodecService.limitLongEdge(source, job.maxLongEdge);
    final framed = _framePhoto(
      source: source,
      configJson: job.configJson,
      longEdge: job.longEdge,
      algorithmName: job.algorithmName,
      photoJson: job.photoJson,
    );
    return CanvasRenderer.encodeJpg(framed, quality: job.quality);
  }

  /// Frame tapestry slices and return one JPEG per carousel frame.
  static List<Uint8List> frameTapestryToJpgs(TapestryFrameJob job) {
    final sources = <img.Image>[
      for (final bmp in job.sources)
        img.Image.fromBytes(
          width: bmp.width,
          height: bmp.height,
          bytes: bmp.rgba.buffer,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        ),
    ];
    final config = CanvasConfig.fromJson(job.configJson);
    final algorithm = ResampleAlgorithm.values.firstWhere(
      (a) => a.name == job.algorithmName,
      orElse: () => ResampleAlgorithm.linear,
    );
    final slices = CanvasRenderer.renderTapestrySlices(
      sources: sources,
      config: config,
      longEdge: job.longEdge,
      algorithm: algorithm,
    );
    return [
      for (final slice in slices)
        CanvasRenderer.encodeJpg(slice, quality: job.quality),
    ];
  }

  static img.Image _framePhoto({
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
      orElse: () => ResampleAlgorithm.linear,
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
