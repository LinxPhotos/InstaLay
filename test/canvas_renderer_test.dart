import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:instalay/models/aspect_presets.dart';
import 'package:instalay/models/canvas_config.dart';
import 'package:instalay/models/color_swatches.dart';
import 'package:instalay/models/project.dart';
import 'package:instalay/models/resample_algorithm.dart';
import 'package:instalay/services/canvas_renderer.dart';
import 'package:instalay/services/image_codec_service.dart';
import 'package:instalay/services/resampler.dart';

void main() {
  test('default swatch is sheer cloud light grey', () {
    expect(CanvasSwatchCatalog.defaultSwatch.id, 'sheer_cloud');
  });

  test('lanczos resize changes dimensions', () {
    final src = img.Image(width: 100, height: 80);
    img.fill(src, color: img.ColorRgba8(200, 200, 200, 255));
    final out = Resampler.resize(
      src,
      width: 50,
      height: 40,
      algorithm: ResampleAlgorithm.lanczos3,
    );
    expect(out.width, 50);
    expect(out.height, 40);
  });

  test('renderPhoto produces target aspect', () {
    final src = img.Image(width: 800, height: 600);
    img.fill(src, color: img.ColorRgba8(180, 180, 180, 255));
    const config = CanvasConfig();
    final framed = CanvasRenderer.renderPhoto(
      source: src,
      config: config,
      longEdge: 1000,
      algorithm: ResampleAlgorithm.linear,
    );
    expect(framed.width / framed.height, closeTo(4 / 5, 0.02));
    expect(framed.height, 1000);
  });

  test('sizeFor treats longEdge as export height', () {
    const portrait = CanvasConfig();
    final p = CanvasRenderer.sizeFor(config: portrait, longEdge: 1440);
    expect(p.height, 1440);
    expect(p.width / p.height, closeTo(4 / 5, 0.001));

    const landscape = CanvasConfig(aspect: AspectPreset.landscape169);
    final l = CanvasRenderer.sizeFor(config: landscape, longEdge: 1080);
    expect(l.height, 1080);
    expect(l.width / l.height, closeTo(16 / 9, 0.001));
  });

  test('identity thumb matches layout aspect and draws photo', () {
    final src = img.Image(width: 800, height: 600);
    img.fill(src, color: img.ColorRgba8(40, 120, 200, 255));
    const config = CanvasConfig(
      borderPx: 20,
      // Near-white matte — old strip thumbs looked blank when photos missed.
      swatch: CanvasSwatchCatalog.allWhite,
    );
    final thumb = CanvasRenderer.renderIdentityThumb(
      sources: [src],
      config: config,
      height: 160,
      maxWidth: 640,
      renderLongEdge: 400,
    );
    expect(thumb.width / thumb.height, closeTo(4 / 5, 0.03));
    expect(thumb.height, lessThanOrEqualTo(160));
    expect(thumb.width, lessThanOrEqualTo(640));

    // Sample center — must not be pure white matte (photo was drawn).
    final cx = thumb.width ~/ 2;
    final cy = thumb.height ~/ 2;
    final pixel = thumb.getPixel(cx, cy);
    expect(pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt(), lessThan(700));
  });

  test('tapestry identity thumb uses first slide aspect not wide strip', () {
    final a = img.Image(width: 400, height: 300);
    img.fill(a, color: img.ColorRgba8(100, 100, 100, 255));
    final b = img.Image(width: 400, height: 300);
    img.fill(b, color: img.ColorRgba8(140, 140, 140, 255));
    final thumb = CanvasRenderer.renderIdentityThumb(
      sources: [a, b],
      config: const CanvasConfig(
        layoutMode: LayoutMode.tapestry,
        borderPx: 20,
      ),
      height: 160,
      maxWidth: 640,
      slideCount: 3,
      renderLongEdge: 400,
    );
    expect(thumb.width / thumb.height, closeTo(4 / 5, 0.05));
    // Legacy strip was ~4:1 (640×160); framed first slide must be taller.
    expect(thumb.width / thumb.height, lessThan(2.0));
  });

  test('tapestry yields multiple slices', () {
    final a = img.Image(width: 400, height: 300);
    img.fill(a, color: img.ColorRgba8(100, 100, 100, 255));
    final b = img.Image(width: 400, height: 300);
    img.fill(b, color: img.ColorRgba8(140, 140, 140, 255));
    final slices = CanvasRenderer.renderTapestrySlices(
      sources: [a, b],
      config: const CanvasConfig(layoutMode: LayoutMode.tapestry, borderPx: 20),
      longEdge: 800,
      algorithm: ResampleAlgorithm.linear,
      slideCount: 3,
    );
    expect(slices.length, 3);
    for (final s in slices) {
      expect(s.width / s.height, closeTo(4 / 5, 0.05));
    }
  });

  test('export rotate-before-resize matches resize-then-rotate footprint', () {
    // High-res source with a sharp edge so rotation has something to sample.
    final src = img.Image(width: 800, height: 600);
    img.fill(src, color: img.ColorRgba8(20, 20, 20, 255));
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width ~/ 2; x++) {
        src.setPixelRgba(x, y, 220, 220, 220, 255);
      }
    }
    const config = CanvasConfig(layoutMode: LayoutMode.tapestry, borderPx: 0);
    final photos = [
      PhotoItem(id: '1', sourcePath: '', order: 0, rotationDeg: 25),
    ];

    final fast = CanvasRenderer.renderTapestrySlices(
      sources: [src],
      photos: photos,
      config: config,
      longEdge: 200,
      algorithm: ResampleAlgorithm.linear,
      slideCount: 1,
    ).single;
    final hq = CanvasRenderer.renderTapestrySlices(
      sources: [src],
      photos: photos,
      config: config,
      longEdge: 200,
      algorithm: ResampleAlgorithm.linear,
      slideCount: 1,
      rotateBeforeResize: true,
    ).single;

    expect(hq.width, fast.width);
    expect(hq.height, fast.height);
    // Same canvas size; pixels need not be identical (sampling order differs).
    expect(hq.width, greaterThan(0));
  });

  test('limitLongEdge caps the longer side', () {
    final src = img.Image(width: 4000, height: 3000);
    img.fill(src, color: img.ColorRgba8(10, 10, 10, 255));
    final limited = ImageCodecService.limitLongEdge(src, 1000);
    expect(limited.width, 1000);
    expect(limited.height, 750);
  });

  test('previewDecodeLongEdge scales with output size', () {
    final edge = ImageCodecService.previewDecodeLongEdge(
      outputLongEdge: 360,
      photoScale: 1,
      fit: FitHint.contain,
    );
    expect(edge, greaterThanOrEqualTo(360));
    expect(edge, lessThan(4000));
  });
}
