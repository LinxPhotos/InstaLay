import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:image/image.dart' as img;
import 'package:koni_jxl/koni_jxl.dart';

import '../models/export_codec.dart';

class EncodedImage {
  const EncodedImage({
    required this.bytes,
    required this.format,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final ExportFormat format;
  final int width;
  final int height;

  int get byteLength => bytes.lengthInBytes;

  String get humanSize => formatBytes(byteLength);
}

class SizeEstimate {
  const SizeEstimate({
    required this.bytes,
    required this.exact,
    required this.format,
    required this.width,
    required this.height,
  });

  final int bytes;
  final bool exact;
  final ExportFormat format;
  final int width;
  final int height;

  String get humanSize => formatBytes(bytes);

  String get label => exact ? humanSize : '~$humanSize';
}

/// RGBA bitmap from a successful platform ([dart:ui]) decode.
class PlatformDecodedImage {
  const PlatformDecodedImage({
    required this.rgba,
    required this.width,
    required this.height,
  });

  final Uint8List rgba;
  final int width;
  final int height;

  img.Image toImage() => img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgba.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

/// Decode / encode pipeline for JPEG, JPEG XL, PNG, WebP, AVIF.
///
/// Prefers Flutter/Skia platform codecs ([instantiateImageCodecWithSize]) for
/// JPEG/PNG/WebP — native decode, often backed by libjpeg-turbo, with optional
/// downsample-during-decode via [maxLongEdge]. JXL stays pure-Dart; AVIF uses
/// the plugin. Heavy pure-Dart work runs in a background isolate when possible.
abstract final class ImageCodecService {
  static img.Image? decode(Uint8List bytes, {String? pathHint}) {
    final lower = pathHint?.toLowerCase() ?? '';
    if (lower.endsWith('.jxl') || _looksLikeJxl(bytes)) {
      try {
        return _decodeJxl(bytes);
      } catch (_) {
        // fall through
      }
    }

    return img.decodeImage(bytes);
  }

  /// Async decode covering AVIF (plugin), platform Skia, and JXL / raster.
  ///
  /// When [maxLongEdge] is set, platform codecs decode closer to that size
  /// (JPEG IDCT scale / Skia resample) instead of full resolution then shrink.
  static Future<img.Image?> decodeAsync(
    Uint8List bytes, {
    String? pathHint,
    int? maxLongEdge,
  }) async {
    final lower = pathHint?.toLowerCase() ?? '';
    final isJxl = lower.endsWith('.jxl') || _looksLikeJxl(bytes);
    final isAvif = lower.endsWith('.avif') || _looksLikeAvif(bytes);

    if (isJxl) {
      final packet = await Isolate.run(
        () => _encodeTransferPacket(
          decode(bytes, pathHint: pathHint),
          maxLongEdge,
        ),
      );
      return _fromTransferPacket(packet);
    }

    if (!isAvif) {
      final platform = await decodeViaPlatform(bytes, maxLongEdge: maxLongEdge);
      if (platform != null) return platform.toImage();
    }

    if (isAvif) {
      try {
        final frames = await decodeAvif(bytes);
        if (frames.isEmpty) return null;
        final uiImage = frames.first.image;
        final w = uiImage.width;
        final h = uiImage.height;
        final bd =
            await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
        uiImage.dispose();
        if (bd == null) return null;
        final image = img.Image.fromBytes(
          width: w,
          height: h,
          bytes: bd.buffer,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );
        return limitLongEdge(image, maxLongEdge);
      } catch (e) {
        debugPrint('AVIF decode failed: $e');
        return null;
      }
    }

    final packet = await Isolate.run(
      () => _encodeTransferPacket(img.decodeImage(bytes), maxLongEdge),
    );
    return _fromTransferPacket(packet);
  }

  static Map<String, Object>? _encodeTransferPacket(
    img.Image? decoded,
    int? maxLongEdge,
  ) {
    if (decoded == null) return null;
    final limited = limitLongEdge(decoded, maxLongEdge);
    return {
      'w': limited.width,
      'h': limited.height,
      'rgba': Uint8List.fromList(
        limited.getBytes(order: img.ChannelOrder.rgba),
      ),
    };
  }

  static img.Image? _fromTransferPacket(Map<String, Object>? packet) {
    if (packet == null) return null;
    final w = packet['w']! as int;
    final h = packet['h']! as int;
    final rgba = packet['rgba']! as Uint8List;
    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  /// Skia/engine decode (main isolate only). Returns null if the engine cannot
  /// decode the payload (e.g. JPEG XL).
  static Future<PlatformDecodedImage?> decodeViaPlatform(
    Uint8List bytes, {
    int? maxLongEdge,
  }) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: maxLongEdge == null
            ? null
            : (intrinsicWidth, intrinsicHeight) {
                final long = math.max(intrinsicWidth, intrinsicHeight);
                if (long <= maxLongEdge) {
                  return const ui.TargetImageSize();
                }
                final scale = maxLongEdge / long;
                return ui.TargetImageSize(
                  width: math.max(1, (intrinsicWidth * scale).round()),
                  height: math.max(1, (intrinsicHeight * scale).round()),
                );
              },
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final w = image.width;
      final h = image.height;
      final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      codec.dispose();
      if (bd == null) return null;
      return PlatformDecodedImage(
        rgba: Uint8List.fromList(bd.buffer.asUint8List()),
        width: w,
        height: h,
      );
    } catch (e) {
      debugPrint('Platform decode failed: $e');
      return null;
    }
  }

  /// Fast post-decode cap used when the codec cannot downsample natively.
  static img.Image limitLongEdge(img.Image image, int? maxLongEdge) {
    if (maxLongEdge == null) return image;
    final long = math.max(image.width, image.height);
    if (long <= maxLongEdge) return image;
    final scale = maxLongEdge / long;
    return img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.linear,
    );
  }

  /// Decode budget for preview / thumb framing: enough pixels for the fit box
  /// and photo scale, without keeping a full camera-resolution bitmap.
  static int previewDecodeLongEdge({
    required int outputLongEdge,
    double photoScale = 1,
    FitHint fit = FitHint.contain,
  }) {
    final scale = photoScale.clamp(0.1, 8.0);
    final factor = switch (fit) {
      FitHint.contain => 1.5,
      FitHint.cover => 2.0,
      FitHint.fill => 1.25,
    };
    return math.max(64, (outputLongEdge * scale * factor).ceil());
  }

  static Future<EncodedImage> encode(
    img.Image image,
    ExportCodecSettings settings,
  ) async {
    final rgba = _ensureRgba(image);
    final format = settings.format;

    late Uint8List bytes;
    switch (format) {
      case ExportFormat.jpeg:
        bytes = Uint8List.fromList(
          img.encodeJpg(
            rgba,
            quality: settings.jpegQuality.clamp(1, 100),
            chroma: settings.jpegChroma,
          ),
        );
      case ExportFormat.png:
        bytes = Uint8List.fromList(
          img.encodePng(rgba, level: settings.pngLevel.clamp(0, 9)),
        );
      case ExportFormat.webp:
        bytes = Uint8List.fromList(img.encodeWebP(rgba));
      case ExportFormat.jpegXl:
        bytes = _encodeJxl(rgba, settings);
      case ExportFormat.avif:
        bytes = await _encodeAvif(rgba, settings);
    }

    return EncodedImage(
      bytes: bytes,
      format: format,
      width: rgba.width,
      height: rgba.height,
    );
  }

  /// Fast proportional estimate from a downscaled encode.
  static Future<SizeEstimate> estimateSize(
    img.Image image,
    ExportCodecSettings settings, {
    int maxEstimateEdge = 720,
  }) async {
    var sample = image;
    final long = image.width > image.height ? image.width : image.height;
    final needsScale = long > maxEstimateEdge;
    if (needsScale) {
      final scale = maxEstimateEdge / long;
      sample = img.copyResize(
        image,
        width: (image.width * scale).round().clamp(1, image.width),
        height: (image.height * scale).round().clamp(1, image.height),
        interpolation: img.Interpolation.linear,
      );
    }

    final encoded = await encode(sample, settings);
    if (!needsScale) {
      return SizeEstimate(
        bytes: encoded.byteLength,
        exact: true,
        format: settings.format,
        width: image.width,
        height: image.height,
      );
    }

    final areaRatio =
        (image.width * image.height) / (sample.width * sample.height);
    return SizeEstimate(
      bytes: (encoded.byteLength * areaRatio).round(),
      exact: false,
      format: settings.format,
      width: image.width,
      height: image.height,
    );
  }

  static Future<int> measureEncodedBytes(
    img.Image image,
    ExportCodecSettings settings,
  ) async {
    final encoded = await encode(image, settings);
    return encoded.byteLength;
  }

  static img.Image _decodeJxl(Uint8List bytes) {
    final jxl = JxlDecoder.decode(bytes);
    final rgba = jxl.toRgba8();
    return img.Image.fromBytes(
      width: jxl.width,
      height: jxl.height,
      bytes: rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  static Uint8List _encodeJxl(img.Image rgba, ExportCodecSettings settings) {
    final w = rgba.width;
    final h = rgba.height;
    if (settings.jxlMode == JxlMode.lossless ||
        settings.effectiveJxlDistance <= 0) {
      final pixels = Uint8List(w * h * 4);
      var i = 0;
      for (final p in rgba) {
        pixels[i++] = p.r.toInt();
        pixels[i++] = p.g.toInt();
        pixels[i++] = p.b.toInt();
        pixels[i++] = p.a.toInt();
      }
      return JxlEncoder.encodeLossless(
        pixels,
        width: w,
        height: h,
        hasAlpha: true,
      );
    }

    final rgb = Uint8List(w * h * 3);
    var i = 0;
    for (final p in rgba) {
      rgb[i++] = p.r.toInt();
      rgb[i++] = p.g.toInt();
      rgb[i++] = p.b.toInt();
    }
    return JxlEncoder.encodeLossy(
      rgb,
      width: w,
      height: h,
      distance: settings.effectiveJxlDistance,
    );
  }

  /// Public JXL encode for disk thumb cache and callers.
  static Uint8List encodeJxl(
    img.Image image, {
    ExportCodecSettings settings = const ExportCodecSettings(
      format: ExportFormat.jpegXl,
      jxlMode: JxlMode.lossy,
      jxlQuality: 85,
    ),
  }) =>
      _encodeJxl(_ensureRgba(image), settings);

  static Future<Uint8List> _encodeAvif(
    img.Image rgba,
    ExportCodecSettings settings,
  ) async {
    final png = Uint8List.fromList(img.encodePng(rgba, level: 1));
    final q = settings.avifQuality.clamp(1, 100);
    final maxQ = ((100 - q) * 63 / 100).round().clamp(0, 63);
    final minQ = (maxQ * 0.6).round().clamp(0, maxQ);
    return encodeAvif(
      png,
      speed: settings.avifSpeed.clamp(1, 10),
      maxQuantizer: maxQ,
      minQuantizer: minQ,
      maxQuantizerAlpha: maxQ,
      minQuantizerAlpha: minQ,
    );
  }

  static img.Image _ensureRgba(img.Image image) {
    if (image.numChannels == 4) return image;
    return image.convert(numChannels: 4);
  }

  static bool _looksLikeJxl(Uint8List b) {
    if (b.length < 2) return false;
    if (b[0] == 0xFF && b[1] == 0x0A) return true;
    if (b.length >= 12 &&
        b[4] == 0x4A &&
        b[5] == 0x58 &&
        b[6] == 0x4C &&
        b[7] == 0x20) {
      return true;
    }
    return false;
  }

  static bool _looksLikeAvif(Uint8List b) {
    if (b.length < 12) return false;
    return b[4] == 0x66 &&
        b[5] == 0x74 &&
        b[6] == 0x79 &&
        b[7] == 0x70;
  }
}

/// Fit mode hint for [ImageCodecService.previewDecodeLongEdge] without importing
/// Flutter widgets into isolate workers.
enum FitHint { contain, cover, fill }
