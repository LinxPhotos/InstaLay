import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/canvas_config.dart';
import '../models/project.dart';
import '../models/resample_algorithm.dart';
import 'paper_texture_generator.dart';
import 'resampler.dart';

class CanvasSize {
  const CanvasSize(this.width, this.height);
  final int width;
  final int height;
}

/// Builds framed canvases and SCRL-style tapestry slices.
abstract final class CanvasRenderer {
  static CanvasSize sizeFor({
    required CanvasConfig config,
    required int longEdge,
  }) {
    final r = config.aspect.ratio;
    if (r >= 1) {
      return CanvasSize(longEdge, (longEdge / r).round().clamp(1, longEdge));
    }
    return CanvasSize((longEdge * r).round().clamp(1, longEdge), longEdge);
  }

  static img.Image decodeBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unable to decode image');
    }
    return decoded;
  }

  /// Single-photo framed canvas (batch mode).
  static img.Image renderPhoto({
    required img.Image source,
    required CanvasConfig config,
    required int longEdge,
    ResampleAlgorithm? algorithm,
    PhotoItem? photo,
  }) {
    final algo = algorithm ?? config.exportAlgorithm;
    final canvasSize = sizeFor(config: config, longEdge: longEdge);
    final border = config.borderPx.clamp(0, longEdge ~/ 2);
    final innerW = (canvasSize.width - border * 2).clamp(1, canvasSize.width);
    final innerH = (canvasSize.height - border * 2).clamp(1, canvasSize.height);

    final canvas = _blankCanvas(canvasSize, config);

    final placed = _fitImage(
      source,
      innerW,
      innerH,
      config.fitMode,
      algo,
      scale: photo?.scale ?? 1,
    );

    final ox = border +
        ((innerW - placed.width) / 2).round() +
        (photo?.offsetX ?? 0).round();
    final oy = border +
        ((innerH - placed.height) / 2).round() +
        (photo?.offsetY ?? 0).round();

    img.compositeImage(canvas, placed, dstX: ox.toInt(), dstY: oy.toInt());
    return canvas;
  }

  /// Horizontal tapestry of all photos, then sliced into aspect-ratio frames.
  static List<img.Image> renderTapestrySlices({
    required List<img.Image> sources,
    required CanvasConfig config,
    required int longEdge,
    ResampleAlgorithm? algorithm,
  }) {
    if (sources.isEmpty) return const [];

    final algo = algorithm ?? config.exportAlgorithm;
    final frame = sizeFor(config: config, longEdge: longEdge);
    final border = config.borderPx.clamp(0, longEdge ~/ 2);
    final innerH = (frame.height - border * 2).clamp(1, frame.height);
    final gap = config.tapestryGapPx.clamp(0, 256);

    final scaled = <img.Image>[];
    for (final src in sources) {
      final targetH = innerH;
      final targetW = (src.width / src.height * targetH).round().clamp(1, 20000);
      scaled.add(
        Resampler.resize(src, width: targetW, height: targetH, algorithm: algo),
      );
    }

    var totalW = border * 2;
    for (var i = 0; i < scaled.length; i++) {
      totalW += scaled[i].width;
      if (i < scaled.length - 1) totalW += gap;
    }

    final strip = _blankCanvas(CanvasSize(totalW, frame.height), config);
    var x = border;
    for (var i = 0; i < scaled.length; i++) {
      img.compositeImage(strip, scaled[i], dstX: x, dstY: border);
      x += scaled[i].width + gap;
    }

    // Slice into IG-width frames; last frame left-aligned remainder padded.
    final slices = <img.Image>[];
    final step = frame.width;
    for (var sx = 0; sx + step <= strip.width; sx += step) {
      slices.add(img.copyCrop(strip, x: sx, y: 0, width: step, height: frame.height));
    }
    if (slices.isEmpty) {
      // Short tapestry: pad to one frame.
      final one = _blankCanvas(frame, config);
      img.compositeImage(one, strip, dstX: 0, dstY: 0);
      slices.add(one);
    } else if (strip.width % step != 0) {
      final rem = strip.width % step;
      final last = _blankCanvas(frame, config);
      final crop = img.copyCrop(
        strip,
        x: strip.width - rem,
        y: 0,
        width: rem,
        height: frame.height,
      );
      img.compositeImage(last, crop, dstX: 0, dstY: 0);
      slices.add(last);
    }
    return slices;
  }

  /// Compact identity thumb for project list rows (wide, height-constrained).
  static img.Image renderIdentityThumb({
    required List<img.Image> sources,
    required CanvasConfig config,
    required int height,
    required int maxWidth,
  }) {
    if (sources.isEmpty) {
      return _blankCanvas(CanvasSize(maxWidth, height), config);
    }

    final thumbs = <img.Image>[];
    for (final src in sources.take(12)) {
      final w = (src.width / src.height * height).round().clamp(1, maxWidth);
      thumbs.add(
        Resampler.resize(
          src,
          width: w,
          height: height,
          algorithm: config.thumbnailAlgorithm,
        ),
      );
    }

    var totalW = 0;
    for (final t in thumbs) {
      totalW += t.width;
    }
    totalW = totalW.clamp(height, maxWidth);

    final out = _blankCanvas(CanvasSize(totalW, height), config);
    var x = 0;
    for (final t in thumbs) {
      if (x >= maxWidth) break;
      final drawW = (t.width).clamp(1, maxWidth - x);
      if (drawW < t.width) {
        final cropped = img.copyCrop(t, x: 0, y: 0, width: drawW, height: height);
        img.compositeImage(out, cropped, dstX: x, dstY: 0);
      } else {
        img.compositeImage(out, t, dstX: x, dstY: 0);
      }
      x += drawW;
    }

    // Stretch visually to full column width by padding remaining with matte if short.
    if (out.width < maxWidth) {
      final wide = _blankCanvas(CanvasSize(maxWidth, height), config);
      img.compositeImage(wide, out, dstX: 0, dstY: 0);
      return wide;
    }
    return out;
  }

  static img.Image _blankCanvas(CanvasSize size, CanvasConfig config) {
    final c = config.swatch.color;
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    final canvas = img.Image(
      width: size.width,
      height: size.height,
      numChannels: 4,
    );
    img.fill(
      canvas,
      color: img.ColorRgba8(r, g, b, 255),
    );
    PaperTextureGenerator.apply(canvas, config.texture);
    return canvas;
  }

  static img.Image _fitImage(
    img.Image source,
    int boxW,
    int boxH,
    FitMode mode,
    ResampleAlgorithm algo, {
    double scale = 1,
  }) {
    final srcR = source.width / source.height;
    final boxR = boxW / boxH;

    late int tw, th;
    switch (mode) {
      case FitMode.contain:
        if (srcR > boxR) {
          tw = boxW;
          th = (boxW / srcR).round().clamp(1, boxH);
        } else {
          th = boxH;
          tw = (boxH * srcR).round().clamp(1, boxW);
        }
      case FitMode.cover:
        if (srcR > boxR) {
          th = boxH;
          tw = (boxH * srcR).round();
        } else {
          tw = boxW;
          th = (boxW / srcR).round();
        }
      case FitMode.fill:
        tw = boxW;
        th = boxH;
    }

    tw = (tw * scale).round().clamp(1, 20000);
    th = (th * scale).round().clamp(1, 20000);

    var resized = Resampler.resize(source, width: tw, height: th, algorithm: algo);

    if (mode == FitMode.cover && (tw > boxW || th > boxH)) {
      final cx = ((tw - boxW) / 2).round().clamp(0, tw - 1);
      final cy = ((th - boxH) / 2).round().clamp(0, th - 1);
      resized = img.copyCrop(
        resized,
        x: cx,
        y: cy,
        width: boxW.clamp(1, resized.width),
        height: boxH.clamp(1, resized.height),
      );
    }
    return resized;
  }

  static Uint8List encodePng(img.Image image) =>
      Uint8List.fromList(img.encodePng(image));

  static Uint8List encodeJpg(img.Image image, {int quality = 92}) =>
      Uint8List.fromList(img.encodeJpg(image, quality: quality));
}
