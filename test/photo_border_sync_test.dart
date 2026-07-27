import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/models/canvas_config.dart';
import 'package:instalay/models/photo_border_sync.dart';
import 'package:instalay/models/project.dart';
import 'package:instalay/services/canvas_renderer.dart';
import 'package:instalay/models/resample_algorithm.dart';
import 'package:image/image.dart' as img;

void main() {
  PhotoItem photo(String id, {double borderPx = 0, int color = 0xFFFFFFFF}) =>
      PhotoItem(
        id: id,
        sourcePath: '',
        order: int.tryParse(id) ?? 0,
        borderPx: borderPx,
        borderColorArgb: color,
      );

  test('sync size fans out border px and updates last', () {
    const config = CanvasConfig(syncPhotoBorderPx: true);
    final photos = [photo('0'), photo('1'), photo('2')];
    final result = PhotoBorderSync.apply(
      config: config,
      photos: photos,
      photoId: '1',
      borderPx: 24,
    );
    expect(result.config.lastPhotoBorderPx, 24);
    for (final p in result.photos) {
      expect(p.borderPx, 24);
    }
  });

  test('unsynced size edits only the target photo', () {
    const config = CanvasConfig(syncPhotoBorderPx: false);
    final photos = [
      photo('0', borderPx: 10),
      photo('1', borderPx: 10),
    ];
    final result = PhotoBorderSync.apply(
      config: config,
      photos: photos,
      photoId: '0',
      borderPx: 40,
    );
    expect(result.photos[0].borderPx, 40);
    expect(result.photos[1].borderPx, 10);
    expect(result.config.lastPhotoBorderPx, 40);
  });

  test('sync color and size are independent', () {
    const config = CanvasConfig(
      syncPhotoBorderPx: true,
      syncPhotoBorderColor: false,
    );
    final photos = [
      photo('0', borderPx: 0, color: 0xFF000000),
      photo('1', borderPx: 0, color: 0xFF000000),
    ];
    final result = PhotoBorderSync.apply(
      config: config,
      photos: photos,
      photoId: '0',
      borderPx: 12,
      borderColorArgb: 0xFFFF0000,
    );
    expect(result.photos[0].borderPx, 12);
    expect(result.photos[1].borderPx, 12);
    expect(result.photos[0].borderColorArgb, 0xFFFF0000);
    expect(result.photos[1].borderColorArgb, 0xFF000000);
  });

  test('enabling sync fans out from the selected photo', () {
    const config = CanvasConfig(syncPhotoBorderPx: false);
    final photos = [
      photo('0', borderPx: 18),
      photo('1', borderPx: 0),
    ];
    final result = PhotoBorderSync.apply(
      config: config,
      photos: photos,
      photoId: '0',
      syncPhotoBorderPx: true,
    );
    expect(result.config.syncPhotoBorderPx, isTrue);
    expect(result.config.lastPhotoBorderPx, 18);
    expect(result.photos[0].borderPx, 18);
    expect(result.photos[1].borderPx, 18);
  });

  test('seed copies last-edited border onto a new photo', () {
    const config = CanvasConfig(
      lastPhotoBorderPx: 16,
      lastPhotoBorderColorArgb: 0xFF112233,
    );
    final seeded = PhotoBorderSync.seed(photo('9'), config);
    expect(seeded.borderPx, 16);
    expect(seeded.borderColorArgb, 0xFF112233);
  });

  test('border is not a custom transform', () {
    final p = photo('0', borderPx: 20);
    expect(p.hasCustomTransform, isFalse);
  });

  test('export draws opaque photo border around content', () {
    final src = img.Image(width: 100, height: 100);
    img.fill(src, color: img.ColorRgba8(0, 0, 255, 255));
    final photos = [
      PhotoItem(
        id: '0',
        sourcePath: '',
        order: 0,
        borderPx: 20,
        borderColorArgb: 0xFFFF0000,
      ),
    ];
    // Frame inset 40 so the 20px photo border stays on-canvas (outset).
    final slices = CanvasRenderer.renderTapestrySlices(
      sources: [src],
      photos: photos,
      config: const CanvasConfig(
        layoutMode: LayoutMode.tapestry,
        borderPx: 40,
      ),
      longEdge: 200,
      algorithm: ResampleAlgorithm.nearest,
      slideCount: 1,
    );
    expect(slices, isNotEmpty);
    // Just inside the frame inset, in the photo-border ring (before content).
    final ring = slices.first.getPixel(25, 25);
    expect(ring.r.toInt(), greaterThan(200));
    expect(ring.g.toInt(), lessThan(40));
    expect(ring.b.toInt(), lessThan(40));
  });
}
