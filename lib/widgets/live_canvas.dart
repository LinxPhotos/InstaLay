import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/canvas_config.dart';
import '../models/instagram_limits.dart';
import '../models/project.dart';
import '../services/canvas_renderer.dart';
import '../theme/app_theme.dart';

/// Pure layout math for live Skia compositing (mirrors [CanvasRenderer] geometry).
abstract final class CanvasLayout {
  /// Export-pixel canvas size used as the live coordinate system.
  static Size canvasSize(CanvasConfig config) {
    final s = CanvasRenderer.sizeFor(
      config: config,
      longEdge: config.exportLongEdge,
    );
    return Size(s.width.toDouble(), s.height.toDouble());
  }

  static double borderPx(CanvasConfig config) {
    final longEdge = config.exportLongEdge;
    return config.borderPx.toDouble().clamp(0, longEdge / 2);
  }

  static Rect innerRect(CanvasConfig config) {
    final size = canvasSize(config);
    final b = borderPx(config);
    return Rect.fromLTWH(
      b,
      b,
      math.max(1, size.width - 2 * b),
      math.max(1, size.height - 2 * b),
    );
  }

  /// Where [source] is drawn inside [box], matching CPU fit/cover/fill + scale.
  static Rect photoDest({
    required Size sourceSize,
    required Rect box,
    required FitMode mode,
    double scale = 1,
    Offset offset = Offset.zero,
  }) {
    final srcR = sourceSize.width / math.max(1, sourceSize.height);
    final boxR = box.width / math.max(1, box.height);

    late double tw;
    late double th;
    switch (mode) {
      case FitMode.contain:
        if (srcR > boxR) {
          tw = box.width;
          th = box.width / srcR;
        } else {
          th = box.height;
          tw = box.height * srcR;
        }
      case FitMode.cover:
        if (srcR > boxR) {
          th = box.height;
          tw = box.height * srcR;
        } else {
          tw = box.width;
          th = box.width / srcR;
        }
      case FitMode.fill:
        tw = box.width;
        th = box.height;
    }

    tw = math.max(1, tw * scale);
    th = math.max(1, th * scale);

    final left = box.left + (box.width - tw) / 2 + offset.dx;
    final top = box.top + (box.height - th) / 2 + offset.dy;
    return Rect.fromLTWH(left, top, tw, th);
  }

  /// Tapestry: each source scaled to [innerH], preserving aspect.
  static List<Size> tapestryTileSizes({
    required List<Size> sourceSizes,
    required double innerH,
  }) {
    return [
      for (final s in sourceSizes)
        Size(
          math.max(1, s.width / math.max(1, s.height) * innerH),
          innerH,
        ),
    ];
  }

  static double tapestryStripWidth({
    required List<Size> tileSizes,
    required double border,
    required double gap,
  }) {
    var w = border * 2;
    for (var i = 0; i < tileSizes.length; i++) {
      w += tileSizes[i].width;
      if (i < tileSizes.length - 1) w += gap;
    }
    return math.max(border * 2 + 1, w);
  }

  /// Dest rect for photo [index] on the tapestry strip (pre-rotation).
  /// Uses absolute [PhotoItem.offsetX]/[Y] when any photo has a custom
  /// transform; otherwise sequential height-fit layout.
  static Rect tapestryPhotoRect({
    required List<PhotoItem> photos,
    required List<ui.Image> images,
    required int index,
    required double border,
    required double innerH,
    required double gap,
  }) {
    assert(photos.length == images.length);
    final custom = photos.any((p) => p.hasCustomTransform);

    if (custom) {
      final photo = photos[index];
      final img = images[index];
      final base = tapestryBaseSize(
        Size(img.width.toDouble(), img.height.toDouble()),
        innerH,
        photo: photo,
      );
      return Rect.fromLTWH(
        photo.offsetX,
        photo.offsetY,
        math.max(1, base.width * photo.scale),
        math.max(1, base.height * photo.scale),
      );
    }

    var x = border;
    for (var i = 0; i < images.length; i++) {
      final img = images[i];
      final base = tapestryBaseSize(
        Size(img.width.toDouble(), img.height.toDouble()),
        innerH,
        photo: photos[i],
      );
      if (i == index) {
        return Rect.fromLTWH(x, border, base.width, base.height);
      }
      x += base.width + gap;
    }
    return Rect.zero;
  }

  /// Unscaled height-fit size for a source at [innerH] (honors crop aspect).
  static Size tapestryBaseSize(
    Size sourceSize,
    double innerH, {
    PhotoItem? photo,
  }) {
    final h = math.max(1.0, innerH);
    final srcW = math.max(
      1.0,
      sourceSize.width * (photo?.cropWidthFrac ?? 1.0),
    );
    final srcH = math.max(
      1.0,
      sourceSize.height * (photo?.cropHeightFrac ?? 1.0),
    );
    final w = srcW / srcH * h;
    return Size(math.max(1, w), h);
  }

  /// How many carousel slides are needed to show [sourceSizes] side-by-side
  /// at identical height (content strip width ÷ frame width, rounded up).
  static int slidesNeededForSources({
    required List<Size> sourceSizes,
    required CanvasConfig config,
  }) {
    if (sourceSizes.isEmpty) return InstagramLimits.minCarouselSlides;
    final frame = canvasSize(config);
    final border = borderPx(config);
    final innerH = math.max(1.0, frame.height - 2 * border);
    final tiles = tapestryTileSizes(sourceSizes: sourceSizes, innerH: innerH);
    final stripW = tapestryStripWidth(
      tileSizes: tiles,
      border: border,
      gap: config.tapestryGapPx.toDouble(),
    );
    final needed = (stripW / frame.width).ceil();
    return InstagramLimits.clampSlideCount(needed);
  }

  /// Keep at least [minOverlap] of [rect] inside the strip (prevents losing photos).
  static Offset clampPhotoOrigin({
    required Offset origin,
    required Size photoSize,
    required Size stripSize,
    double minOverlap = 32,
  }) {
    final maxX = stripSize.width - minOverlap;
    final maxY = stripSize.height - minOverlap;
    final minX = minOverlap - photoSize.width;
    final minY = minOverlap - photoSize.height;
    return Offset(
      origin.dx.clamp(math.min(minX, maxX), math.max(minX, maxX)),
      origin.dy.clamp(math.min(minY, maxY), math.max(minY, maxY)),
    );
  }
}

/// Instant batch framed canvas — Skia composite, no CPU re-bake.
class LiveFramedCanvas extends StatelessWidget {
  const LiveFramedCanvas({
    super.key,
    required this.config,
    this.image,
    this.photo,
    this.fit = BoxFit.contain,
  });

  final CanvasConfig config;
  final ui.Image? image;
  final PhotoItem? photo;
  /// How this widget fits its parent (the artboard itself is never re-rasterized).
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final logical = CanvasLayout.canvasSize(config);
    final brightness = Theme.of(context).brightness;
    return Align(
      alignment: Alignment.topCenter,
      child: AspectRatio(
        aspectRatio: logical.width / logical.height,
        child: FittedBox(
          fit: fit,
          alignment: Alignment.topCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: AppTheme.artboardLift(brightness, config.swatch.color),
              border: Border.fromBorderSide(
                AppTheme.artboardRim(brightness, config.swatch.color),
              ),
            ),
            child: SizedBox(
              width: logical.width,
              height: logical.height,
              child: CustomPaint(
                painter: _FramedPainter(
                  config: config,
                  image: image,
                  photo: photo,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FramedPainter extends CustomPainter {
  _FramedPainter({
    required this.config,
    required this.image,
    required this.photo,
  });

  final CanvasConfig config;
  final ui.Image? image;
  final PhotoItem? photo;

  @override
  void paint(Canvas canvas, Size size) {
    final matte = Paint()..color = config.swatch.color;
    canvas.drawRect(Offset.zero & size, matte);

    final inner = CanvasLayout.innerRect(config);
    final img = image;
    if (img == null) return;

    final dest = CanvasLayout.photoDest(
      sourceSize: Size(img.width.toDouble(), img.height.toDouble()),
      box: inner,
      mode: config.fitMode,
      scale: photo?.scale ?? 1,
      offset: Offset(photo?.offsetX ?? 0, photo?.offsetY ?? 0),
    );

    canvas.save();
    canvas.clipRect(inner);
    paintImage(
      canvas: canvas,
      rect: dest,
      image: img,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FramedPainter old) {
    return old.config != config ||
        old.image != image ||
        old.photo?.scale != photo?.scale ||
        old.photo?.offsetX != photo?.offsetX ||
        old.photo?.offsetY != photo?.offsetY ||
        old.photo?.id != photo?.id;
  }
}

/// Instant tapestry carousel — stitches sources on the GPU each frame.
class LiveTapestryCanvas extends StatefulWidget {
  const LiveTapestryCanvas({
    super.key,
    required this.config,
    required this.images,
    this.fit = BoxFit.contain,
  });

  final CanvasConfig config;
  final List<ui.Image> images;
  final BoxFit fit;

  @override
  State<LiveTapestryCanvas> createState() => _LiveTapestryCanvasState();
}

class _LiveTapestryCanvasState extends State<LiveTapestryCanvas> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didUpdateWidget(covariant LiveTapestryCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length) {
      _page = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logical = CanvasLayout.canvasSize(widget.config);
    final frameCount = _frameCount();
    if (frameCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: frameCount,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              return Align(
                alignment: Alignment.topLeft,
                child: FittedBox(
                  fit: widget.fit,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: logical.width,
                    height: logical.height,
                    child: CustomPaint(
                      painter: _TapestrySlicePainter(
                        config: widget.config,
                        images: widget.images,
                        sliceIndex: index,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (frameCount > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Frame ${_page + 1} of $frameCount',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
      ],
    );
  }

  int _frameCount() {
    if (widget.images.isEmpty) return 0;
    final logical = CanvasLayout.canvasSize(widget.config);
    final border = CanvasLayout.borderPx(widget.config);
    final innerH = math.max(1.0, logical.height - 2 * border);
    final tiles = CanvasLayout.tapestryTileSizes(
      sourceSizes: [
        for (final i in widget.images)
          Size(i.width.toDouble(), i.height.toDouble()),
      ],
      innerH: innerH,
    );
    final stripW = CanvasLayout.tapestryStripWidth(
      tileSizes: tiles,
      border: border,
      gap: widget.config.tapestryGapPx.toDouble(),
    );
    final step = logical.width;
    if (stripW <= step) return 1;
    return (stripW / step).ceil();
  }
}

class _TapestrySlicePainter extends CustomPainter {
  _TapestrySlicePainter({
    required this.config,
    required this.images,
    required this.sliceIndex,
  });

  final CanvasConfig config;
  final List<ui.Image> images;
  final int sliceIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final matte = Paint()..color = config.swatch.color;
    canvas.drawRect(Offset.zero & size, matte);

    if (images.isEmpty) return;

    final border = CanvasLayout.borderPx(config);
    final innerH = math.max(1.0, size.height - 2 * border);
    final gap = config.tapestryGapPx.toDouble();
    final tiles = CanvasLayout.tapestryTileSizes(
      sourceSizes: [
        for (final i in images) Size(i.width.toDouble(), i.height.toDouble()),
      ],
      innerH: innerH,
    );

    final originX = -sliceIndex * size.width;
    var x = border + originX;
    for (var i = 0; i < images.length; i++) {
      final tile = tiles[i];
      final dest = Rect.fromLTWH(x, border, tile.width, tile.height);
      paintImage(
        canvas: canvas,
        rect: dest,
        image: images[i],
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      );
      x += tile.width + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TapestrySlicePainter old) {
    return old.config != config ||
        old.sliceIndex != sliceIndex ||
        old.images.length != images.length ||
        !identical(old.images, images);
  }
}
