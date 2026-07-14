import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:insta_lay/models/canvas_config.dart';
import 'package:insta_lay/models/color_swatches.dart';
import 'package:insta_lay/models/resample_algorithm.dart';
import 'package:insta_lay/services/canvas_renderer.dart';
import 'package:insta_lay/services/resampler.dart';

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
    );
    expect(slices, isNotEmpty);
    for (final s in slices) {
      expect(s.width / s.height, closeTo(4 / 5, 0.05));
    }
  });
}
