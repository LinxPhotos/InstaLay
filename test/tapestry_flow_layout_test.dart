import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/models/canvas_config.dart';
import 'package:instalay/models/project.dart';
import 'package:instalay/widgets/live_canvas.dart';

Future<ui.Image> _solidImage(int w, int h) async {
  final data = Uint8List(w * h * 4);
  final completer = ui.ImageDescriptor.raw(
    await ui.ImmutableBuffer.fromUint8List(data),
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await completer.instantiateCodec();
  final frame = await codec.getNextFrame();
  return frame.image;
}

PhotoItem _p(String id, int order, {double offsetX = 0, double offsetY = 0}) =>
    PhotoItem(
      id: id,
      sourcePath: '/x/$id.jpg',
      order: order,
      offsetX: offsetX,
      offsetY: offsetY,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tapestryFlowOrigin appends after a custom-positioned tile', () async {
    final img = await _solidImage(100, 100);
    addTearDown(() => img.dispose());

    const border = 8.0;
    const innerH = 1000.0;
    const gap = 0.0;
    final ordered = [
      _p('a', 0),
      _p('b', 1, offsetX: 500, offsetY: border),
      _p('c', 2),
    ];
    final origin = CanvasLayout.tapestryFlowOrigin(
      ordered: ordered,
      images: [img, img, img],
      photoId: 'c',
      border: border,
      innerH: innerH,
      gap: gap,
    );
    final bBounds = CanvasLayout.tapestryPhotoBounds(
      photo: ordered[1],
      image: img,
      innerH: innerH,
    );
    expect(origin.dx, greaterThan(bBounds.right - 1));
  });

  test('slidesNeededForTapestryContent grows for off-strip positions', () async {
    final img = await _solidImage(100, 100);
    addTearDown(() => img.dispose());
    const config = CanvasConfig();
    final ordered = [_p('a', 0, offsetX: 8000, offsetY: 8)];
    final slides = CanvasLayout.slidesNeededForTapestryContent(
      ordered: ordered,
      images: [img],
      config: config,
    );
    expect(slides, greaterThan(1));
  });
}
