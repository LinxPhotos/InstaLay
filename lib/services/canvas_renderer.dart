import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/aspect_presets.dart';
import '../models/canvas_config.dart';
import '../models/instagram_limits.dart';
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
    // [longEdge] is the export *height* (UI: "Export height"). Width follows aspect.
    final r = config.aspect.ratio;
    final height = longEdge.clamp(1, 100000);
    final width = (height * r).round().clamp(1, 100000);
    return CanvasSize(width, height);
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

  /// Horizontal tapestry strip of [slideCount] frames, then sliced into exports.
  ///
  /// [photos] (same length/order as [sources]) supply placement. When every
  /// photo is still at the default transform, photos are auto-laid out
  /// sequentially; otherwise [PhotoItem.offsetX]/[Y] are top-left strip coords.
  ///
  /// [texts] + [textBitmaps] (same length) are composited by zIndex with photos.
  /// Rasterize texts on the UI isolate via [TextRasterizer] before calling.
  ///
  /// When [rotateBeforeResize] is true (true export), photos are rotated at
  /// source resolution then downsampled — sharper diagonals than resize-then-
  /// rotate. Identity thumbs / edit-path callers leave this false.
  static List<img.Image> renderTapestrySlices({
    required List<img.Image> sources,
    required CanvasConfig config,
    required int longEdge,
    ResampleAlgorithm? algorithm,
    List<PhotoItem>? photos,
    List<TextItem> texts = const [],
    List<img.Image> textBitmaps = const [],
    int? slideCount,
    bool rotateBeforeResize = false,
  }) {
    if (sources.isEmpty && textBitmaps.isEmpty) return const [];

    final algo = algorithm ?? config.exportAlgorithm;
    final frame = sizeFor(config: config, longEdge: longEdge);
    final border = config.borderPx.clamp(0, longEdge ~/ 2);
    final innerH = (frame.height - border * 2).clamp(1, frame.height);
    final gap = config.tapestryGapPx.clamp(0, 256);
    final slides = (slideCount ?? 1).clamp(1, 20);

    final stripW = frame.width * slides;
    final strip = _blankCanvas(CanvasSize(stripW, frame.height), config);

    final meta = photos == null
        ? [
            for (var i = 0; i < sources.length; i++)
              PhotoItem(id: '$i', sourcePath: '', order: i),
          ]
        : ([...photos]..sort((a, b) => a.order.compareTo(b.order)));

    final placements = sources.isEmpty
        ? const <({double left, double top, double width, double height})>[]
        : _tapestryPlacements(
            sources: sources,
            photos: meta,
            border: border,
            innerH: innerH,
            gap: gap,
            tileAspect: config.tapestryTileAspect,
          );

    // Unified paint order: photos + texts by zIndex.
    final layers = <({bool isText, int index, int z})>[
      for (var i = 0; i < meta.length; i++)
        (isText: false, index: i, z: meta[i].zIndex),
      for (var i = 0; i < texts.length && i < textBitmaps.length; i++)
        (isText: true, index: i, z: texts[i].zIndex),
    ]..sort((a, b) {
        final c = a.z.compareTo(b.z);
        return c != 0 ? c : a.index.compareTo(b.index);
      });

    for (final layer in layers) {
      if (!layer.isText) {
        final i = layer.index;
        if (i >= sources.length || i >= placements.length) continue;
        final place = placements[i];
        final src = sources[i];
        final photo = meta[i];
        final crop = photo.sourceCropPixels(
          sourceWidth: src.width,
          sourceHeight: src.height,
        );
        var cropped = (crop.left == 0 &&
                crop.top == 0 &&
                crop.width == src.width &&
                crop.height == src.height)
            ? src
            : img.copyCrop(
                src,
                x: crop.left,
                y: crop.top,
                width: crop.width,
                height: crop.height,
              );
        var destW = place.width.round().clamp(1, 20000);
        var destH = place.height.round().clamp(1, 20000);
        var destX = place.left.round();
        var destY = place.top.round();
        final tileAspect = config.tapestryTileAspect;
        if (tileAspect != null) {
          switch (config.fitMode) {
            case FitMode.cover:
              cropped = _coverCropToAspect(cropped, tileAspect.ratio);
            case FitMode.contain:
              final srcAspect =
                  cropped.width / mathMax1(cropped.height);
              final tileA = tileAspect.ratio;
              if (srcAspect > tileA) {
                destH = math.max(1, (destW / srcAspect).round());
                destY = place.top.round() +
                    ((place.height - destH) / 2).round();
              } else {
                destW = math.max(1, (destH * srcAspect).round());
                destX = place.left.round() +
                    ((place.width - destW) / 2).round();
              }
            case FitMode.fill:
              break;
          }
        }
        final placed = _resizeAndRotatePhoto(
          cropped: cropped,
          destW: destW,
          destH: destH,
          rotationDeg: photo.rotationDeg,
          algorithm: algo,
          rotateBeforeResize: rotateBeforeResize,
        );
        img.compositeImage(
          strip,
          placed,
          dstX: destX,
          dstY: destY,
        );
      } else {
        final i = layer.index;
        final text = texts[i];
        var placed = textBitmaps[i];
        final rot = text.rotationDeg;
        if (rot.abs() > 0.01) {
          placed = img.copyRotate(placed, angle: rot);
        }
        img.compositeImage(
          strip,
          placed,
          dstX: text.offsetX.round(),
          dstY: text.offsetY.round(),
        );
      }
    }

    final slices = <img.Image>[];
    for (var i = 0; i < slides; i++) {
      slices.add(
        img.copyCrop(
          strip,
          x: i * frame.width,
          y: 0,
          width: frame.width,
          height: frame.height,
        ),
      );
    }
    return slices;
  }

  /// Axis-aligned dest rects for each tapestry photo (pre-rotation).
  static List<({double left, double top, double width, double height})>
      _tapestryPlacements({
    required List<img.Image> sources,
    required List<PhotoItem> photos,
    required int border,
    required int innerH,
    required int gap,
    AspectPreset? tileAspect,
  }) {
    final custom = photos.any((p) => p.hasCustomTransform);

    if (custom) {
      return [
        for (var i = 0; i < sources.length; i++)
          () {
            final src = sources[i];
            final photo = photos[i];
            final crop = photo.sourceCropPixels(
              sourceWidth: src.width,
              sourceHeight: src.height,
            );
            final baseH = innerH.toDouble();
            final baseW = tileAspect != null
                ? baseH * tileAspect.ratio
                : crop.width / mathMax1(crop.height) * baseH;
            return (
              left: photo.offsetX,
              top: photo.offsetY,
              width: mathMax1(baseW * photo.scale),
              height: mathMax1(baseH * photo.scale),
            );
          }(),
      ];
    }

    var x = border.toDouble();
    final out = <({double left, double top, double width, double height})>[];
    for (var i = 0; i < sources.length; i++) {
      final src = sources[i];
      final photo = photos[i];
      final crop = photo.sourceCropPixels(
        sourceWidth: src.width,
        sourceHeight: src.height,
      );
      final h = innerH.toDouble();
      final w = tileAspect != null
          ? h * tileAspect.ratio
          : crop.width / mathMax1(crop.height) * h;
      out.add((left: x, top: border.toDouble(), width: w, height: h));
      x += w + gap;
    }
    return out;
  }

  /// Fit [cropped] into [destW]×[destH], applying [rotationDeg].
  ///
  /// [rotateBeforeResize]: rotate at crop resolution, then Lanczos down to the
  /// AABB of the dest rect (export quality). Otherwise resize first (faster
  /// thumbs / edit framing).
  static img.Image _resizeAndRotatePhoto({
    required img.Image cropped,
    required int destW,
    required int destH,
    required double rotationDeg,
    required ResampleAlgorithm algorithm,
    required bool rotateBeforeResize,
  }) {
    final rot = rotationDeg;
    if (rot.abs() <= 0.01) {
      return Resampler.resize(
        cropped,
        width: destW,
        height: destH,
        algorithm: algorithm,
      );
    }

    if (!rotateBeforeResize) {
      final placed = Resampler.resize(
        cropped,
        width: destW,
        height: destH,
        algorithm: algorithm,
      );
      return img.copyRotate(placed, angle: rot);
    }

    // Rotate full-res crop, then downsample to the same AABB footprint that
    // resize-then-rotate would produce for destW×destH.
    final rotated = img.copyRotate(cropped, angle: rot);
    final rad = rot * math.pi / 180;
    final c = math.cos(rad).abs();
    final s = math.sin(rad).abs();
    final targetW = math.max(1, (destW * c + destH * s).round());
    final targetH = math.max(1, (destW * s + destH * c).round());
    return Resampler.resize(
      rotated,
      width: targetW,
      height: targetH,
      algorithm: algorithm,
    );
  }

  /// Crop [source] so its aspect matches [destAspect] (center cover).
  static img.Image _coverCropToAspect(img.Image source, double destAspect) {
    final srcAspect = source.width / mathMax1(source.height);
    if ((srcAspect - destAspect).abs() < 0.0005) return source;
    if (srcAspect > destAspect) {
      final w = (source.height * destAspect).round().clamp(1, source.width);
      final x = ((source.width - w) / 2).round();
      return img.copyCrop(source, x: x, y: 0, width: w, height: source.height);
    }
    final h = (source.width / destAspect).round().clamp(1, source.height);
    final y = ((source.height - h) / 2).round();
    return img.copyCrop(source, x: 0, y: y, width: source.width, height: h);
  }

  static double mathMax1(num n) => n <= 0 ? 1 : n.toDouble();

  /// Home-list identity thumb: one framed canvas at the layout aspect.
  ///
  /// Renders at [renderLongEdge] (defaults to a capped export long-edge) so
  /// tapestry photo offsets (export pixels) land correctly after scaling, then
  /// downscales to fit within [maxWidth]×[height] while preserving aspect.
  ///
  /// Batch: first photo framed. Tapestry: first carousel slide (with texts).
  static img.Image renderIdentityThumb({
    required List<img.Image> sources,
    required CanvasConfig config,
    required int height,
    required int maxWidth,
    List<PhotoItem>? photos,
    int? slideCount,
    List<TextItem> texts = const [],
    List<img.Image> textBitmaps = const [],
    int? renderLongEdge,
  }) {
    final algo = config.thumbnailAlgorithm;
    final exportEdge = mathMax1(config.exportLongEdge).round();
    final edge = (renderLongEdge ?? math.min(exportEdge, 720)).clamp(64, exportEdge);
    final coordScale = edge / exportEdge;
    final scaledPhotos = _scalePhotoCoords(photos, coordScale);
    final scaledTexts = _scaleTextCoords(texts, coordScale);
    final scaledTextBitmaps = _scaleTextBitmaps(textBitmaps, coordScale, algo);
    // Keep border/gap proportional when rendering below export long-edge.
    final thumbConfig = (coordScale - 1.0).abs() < 0.0005
        ? config
        : config.copyWith(
            borderPx: (config.borderPx * coordScale).round(),
            tapestryGapPx: (config.tapestryGapPx * coordScale).round(),
          );
    final placeholderLongEdge = math.min(maxWidth, height).clamp(64, 320);

    if (sources.isEmpty && scaledTextBitmaps.isEmpty) {
      return _blankCanvas(
        sizeFor(config: thumbConfig, longEdge: placeholderLongEdge),
        thumbConfig,
      );
    }

    img.Image framed;
    if (config.layoutMode == LayoutMode.tapestry) {
      final slides = renderTapestrySlices(
        sources: sources,
        config: thumbConfig,
        longEdge: edge,
        algorithm: algo,
        photos: scaledPhotos,
        texts: scaledTexts,
        textBitmaps: scaledTextBitmaps,
        slideCount: slideCount ??
            InstagramLimits.clampSlideCount(
              photos?.isEmpty == false ? photos!.length : sources.length,
            ),
      );
      if (slides.isEmpty) {
        return _blankCanvas(
          sizeFor(config: thumbConfig, longEdge: placeholderLongEdge),
          thumbConfig,
        );
      }
      framed = slides.first;
    } else {
      if (sources.isEmpty) {
        return _blankCanvas(
          sizeFor(config: thumbConfig, longEdge: placeholderLongEdge),
          thumbConfig,
        );
      }
      final ordered = scaledPhotos == null
          ? null
          : ([...scaledPhotos]..sort((a, b) => a.order.compareTo(b.order)));
      framed = renderPhoto(
        source: sources.first,
        config: thumbConfig,
        longEdge: edge,
        algorithm: algo,
        photo: ordered?.isNotEmpty == true ? ordered!.first : null,
      );
    }

    return _fitWithin(
      framed,
      maxWidth: maxWidth,
      maxHeight: height,
      algorithm: algo,
    );
  }

  static List<PhotoItem>? _scalePhotoCoords(
    List<PhotoItem>? photos,
    double factor,
  ) {
    if (photos == null || (factor - 1.0).abs() < 0.0005) return photos;
    return [
      for (final p in photos)
        p.copyWith(
          offsetX: p.offsetX * factor,
          offsetY: p.offsetY * factor,
        ),
    ];
  }

  static List<TextItem> _scaleTextCoords(List<TextItem> texts, double factor) {
    if (texts.isEmpty || (factor - 1.0).abs() < 0.0005) return texts;
    return [
      for (final t in texts)
        t.copyWith(
          offsetX: t.offsetX * factor,
          offsetY: t.offsetY * factor,
        ),
    ];
  }

  static List<img.Image> _scaleTextBitmaps(
    List<img.Image> bitmaps,
    double factor,
    ResampleAlgorithm algorithm,
  ) {
    if (bitmaps.isEmpty || (factor - 1.0).abs() < 0.0005) return bitmaps;
    return [
      for (final b in bitmaps)
        Resampler.resize(
          b,
          width: math.max(1, (b.width * factor).round()),
          height: math.max(1, (b.height * factor).round()),
          algorithm: algorithm,
        ),
    ];
  }

  /// Scale [src] to fit inside [maxWidth]×[maxHeight] without cropping.
  static img.Image _fitWithin(
    img.Image src, {
    required int maxWidth,
    required int maxHeight,
    required ResampleAlgorithm algorithm,
  }) {
    final scale = math.min(
      maxWidth / mathMax1(src.width),
      maxHeight / mathMax1(src.height),
    );
    final w = math.max(1, (src.width * scale).round());
    final h = math.max(1, (src.height * scale).round());
    if (w == src.width && h == src.height) return src;
    return Resampler.resize(
      src,
      width: w,
      height: h,
      algorithm: algorithm,
    );
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
