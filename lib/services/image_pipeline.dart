import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/canvas_config.dart';
import '../models/project.dart';
import '../models/resample_algorithm.dart';
import 'canvas_renderer.dart';
import 'image_codec_service.dart';
import 'resampler.dart';

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
    this.photoJsons = const [],
    this.slideCount = 1,
    this.quality = 82,
  });

  final List<RgbaBitmap> sources;
  final Map<String, dynamic> configJson;
  final int longEdge;
  final String algorithmName;
  final List<Map<String, dynamic>> photoJsons;
  final int slideCount;
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

/// CPU framing helpers that run inside [Isolate.run].
abstract final class ImagePipeline {
  static RgbaBitmap frameRgbaToRgba(FrameJob job) {
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
    return _toRgbaBitmap(framed);
  }

  static Uint8List frameRgbaToJpg(FrameJob job) {
    final framed = frameRgbaToRgba(job);
    return CanvasRenderer.encodeJpg(
      img.Image.fromBytes(
        width: framed.width,
        height: framed.height,
        bytes: framed.rgba.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      ),
      quality: job.quality,
    );
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

  /// Frame tapestry slices and return one RGBA bitmap per carousel frame.
  static List<RgbaBitmap> frameTapestryToRgbas(TapestryFrameJob job) {
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
      photos: [
        for (final j in job.photoJsons) PhotoItem.fromJson(j),
      ],
      slideCount: job.slideCount,
    );
    return [for (final slice in slices) _toRgbaBitmap(slice)];
  }

  /// Frame tapestry slices and return one JPEG per carousel frame.
  static List<Uint8List> frameTapestryToJpgs(TapestryFrameJob job) {
    return [
      for (final slice in frameTapestryToRgbas(job))
        CanvasRenderer.encodeJpg(
          img.Image.fromBytes(
            width: slice.width,
            height: slice.height,
            bytes: slice.rgba.buffer,
            numChannels: 4,
            order: img.ChannelOrder.rgba,
          ),
          quality: job.quality,
        ),
    ];
  }

  /// Downscale a decoded source bitmap so its long edge is at most [longEdge].
  /// Returns [source] unchanged when already within budget.
  static RgbaBitmap downscaleToLongEdge(RgbaBitmap source, int longEdge) {
    final maxDim = math.max(source.width, source.height);
    if (maxDim <= longEdge || longEdge <= 0) return source;
    final scale = longEdge / maxDim;
    final w = (source.width * scale).round().clamp(1, longEdge);
    final h = (source.height * scale).round().clamp(1, longEdge);
    final image = img.Image.fromBytes(
      width: source.width,
      height: source.height,
      bytes: source.rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final resized = Resampler.resize(
      image,
      width: w,
      height: h,
      algorithm: ResampleAlgorithm.linear,
    );
    return _toRgbaBitmap(resized);
  }

  static RgbaBitmap _toRgbaBitmap(img.Image framed) {
    return RgbaBitmap(
      rgba: Uint8List.fromList(framed.getBytes(order: img.ChannelOrder.rgba)),
      width: framed.width,
      height: framed.height,
    );
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
