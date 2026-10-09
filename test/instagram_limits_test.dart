import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/models/canvas_config.dart';
import 'package:instalay/models/instagram_limits.dart';
import 'package:instalay/models/project.dart';

void main() {
  test('layoutExceedsCarouselLimit detects batch overflow', () {
    final photos = [
      for (var i = 0; i < 21; i++)
        PhotoItem(id: 'p$i', sourcePath: '/tmp/p$i.jpg', order: i),
    ];
    final layout = LayoutCanvas(
      id: 'l1',
      name: 'Batch',
      config: const CanvasConfig(),
      photos: photos,
    );
    expect(InstagramLimits.layoutExceedsCarouselLimit(layout), isTrue);
    expect(InstagramLimits.batchCarouselIndexExceedsLimit(19), isFalse);
    expect(InstagramLimits.batchCarouselIndexExceedsLimit(20), isTrue);
  });

  test('layoutExceedsCarouselLimit detects tapestry slide overflow', () {
    final layout = LayoutCanvas(
      id: 't1',
      name: 'Tapestry',
      config: const CanvasConfig(layoutMode: LayoutMode.tapestry),
      photos: const [],
      tapestrySlideCount: 22,
    );
    expect(InstagramLimits.layoutExceedsCarouselLimit(layout), isTrue);
  });
}
