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

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

/// Decode / encode pipeline for JPEG, JPEG XL, PNG, WebP, AVIF.
abstract final class ImageCodecService {
  static img.Image? decode(Uint8List bytes, {String? pathHint}) {
    final lower = pathHint?.toLowerCase() ?? '';
    if (lower.endsWith('.jxl') || _looksLikeJxl(bytes)) {
      try {
        final jxl = JxlDecoder.decode(bytes);
        final rgba = jxl.toRgba8();
        return img.Image.fromBytes(
          width: jxl.width,
          height: jxl.height,
          bytes: rgba.buffer,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );
      } catch (_) {
        // fall through
      }
    }

    return img.decodeImage(bytes);
  }

  /// Async decode covering AVIF (plugin) and JXL / raster via [decode].
  static Future<img.Image?> decodeAsync(
    Uint8List bytes, {
    String? pathHint,
  }) async {
    final sync = decode(bytes, pathHint: pathHint);
    if (sync != null) return sync;

    final lower = pathHint?.toLowerCase() ?? '';
    if (lower.endsWith('.avif') || _looksLikeAvif(bytes)) {
      try {
        final frames = await decodeAvif(bytes);
        if (frames.isEmpty) return null;
        final uiImage = frames.first.image;
        final bd =
            await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (bd == null) return null;
        return img.Image.fromBytes(
          width: uiImage.width,
          height: uiImage.height,
          bytes: bd.buffer,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );
      } catch (e) {
        debugPrint('AVIF decode failed: $e');
        return null;
      }
    }
    return img.decodeImage(bytes);
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
