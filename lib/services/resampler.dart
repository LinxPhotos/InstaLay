import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/resample_algorithm.dart';

/// Lanczos / classic interpolators for thumbnail & export pipelines.
abstract final class Resampler {
  static img.Image resize(
    img.Image source, {
    required int width,
    required int height,
    required ResampleAlgorithm algorithm,
  }) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Invalid target size ${width}x$height');
    }
    if (source.width == width && source.height == height) {
      return img.Image.from(source);
    }

    return switch (algorithm) {
      ResampleAlgorithm.nearest => img.copyResize(
          source,
          width: width,
          height: height,
          interpolation: img.Interpolation.nearest,
        ),
      ResampleAlgorithm.linear => img.copyResize(
          source,
          width: width,
          height: height,
          interpolation: img.Interpolation.linear,
        ),
      ResampleAlgorithm.cubic => img.copyResize(
          source,
          width: width,
          height: height,
          interpolation: img.Interpolation.cubic,
        ),
      ResampleAlgorithm.lanczos2 => _lanczosResize(source, width, height, 2),
      ResampleAlgorithm.lanczos3 => _lanczosResize(source, width, height, 3),
    };
  }

  static img.Image _lanczosResize(
    img.Image source,
    int dstW,
    int dstH,
    int a,
  ) {
    // Separable Lanczos: horizontal then vertical.
    final tmp = img.Image(width: dstW, height: source.height, numChannels: 4);
    final scaleX = source.width / dstW;
    final scaleY = source.height / dstH;

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < dstW; x++) {
        final srcX = (x + 0.5) * scaleX - 0.5;
        final sample = _sample1D(
          source,
          srcX,
          y.toDouble(),
          axisX: true,
          a: a,
          scale: scaleX,
        );
        tmp.setPixelRgba(x, y, sample[0], sample[1], sample[2], sample[3]);
      }
    }

    final out = img.Image(width: dstW, height: dstH, numChannels: 4);
    for (var y = 0; y < dstH; y++) {
      final srcY = (y + 0.5) * scaleY - 0.5;
      for (var x = 0; x < dstW; x++) {
        final sample = _sample1D(
          tmp,
          x.toDouble(),
          srcY,
          axisX: false,
          a: a,
          scale: scaleY,
        );
        out.setPixelRgba(x, y, sample[0], sample[1], sample[2], sample[3]);
      }
    }
    return out;
  }

  static List<int> _sample1D(
    img.Image src,
    double focusA,
    double focusB, {
    required bool axisX,
    required int a,
    required double scale,
  }) {
    final radius = a * math.max(1.0, scale);
    final center = axisX ? focusA : focusB;
    final fixed = axisX ? focusB.round().clamp(0, src.height - 1) : focusA.round().clamp(0, src.width - 1);

    var r = 0.0, g = 0.0, b = 0.0, al = 0.0, wSum = 0.0;
    final i0 = (center - radius).floor();
    final i1 = (center + radius).ceil();

    for (var i = i0; i <= i1; i++) {
      final w = _lanczos((center - i) / (scale > 1 ? scale : 1.0), a);
      if (w == 0) continue;
      if (axisX) {
        final x = i.clamp(0, src.width - 1);
        final p = src.getPixel(x, fixed);
        r += p.r * w;
        g += p.g * w;
        b += p.b * w;
        al += p.a * w;
      } else {
        final y = i.clamp(0, src.height - 1);
        final p = src.getPixel(fixed, y);
        r += p.r * w;
        g += p.g * w;
        b += p.b * w;
        al += p.a * w;
      }
      wSum += w;
    }

    if (wSum.abs() < 1e-8) {
      final px = axisX
          ? src.getPixel(center.round().clamp(0, src.width - 1), fixed)
          : src.getPixel(fixed, center.round().clamp(0, src.height - 1));
      return [px.r.toInt(), px.g.toInt(), px.b.toInt(), px.a.toInt()];
    }

    return [
      (r / wSum).round().clamp(0, 255),
      (g / wSum).round().clamp(0, 255),
      (b / wSum).round().clamp(0, 255),
      (al / wSum).round().clamp(0, 255),
    ];
  }

  static double _lanczos(double x, int a) {
    final ax = x.abs();
    if (ax < 1e-8) return 1;
    if (ax >= a) return 0;
    final pix = math.pi * x;
    return (a * math.sin(pix) * math.sin(pix / a)) / (pix * pix);
  }
}
