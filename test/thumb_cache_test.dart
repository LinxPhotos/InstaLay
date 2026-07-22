import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:instalay/services/canvas_renderer.dart';
import 'package:instalay/services/thumb_cache.dart';

void main() {
  test('thumb cache fingerprint is stable for same payload', () {
    const a = 'same-key-material';
    expect(ThumbCache.fnv1a64Hex(a), ThumbCache.fnv1a64Hex(a));
    expect(ThumbCache.fnv1a64Hex(a), isNot(ThumbCache.fnv1a64Hex('other')));
    expect(ThumbCache.fnv1a64Hex(a).length, 16);
  });

  test('memory cache returns JPEG without disk', () {
    final cache = ThumbCache(maxMemoryEntries: 4);
    final source = img.Image(width: 16, height: 20);
    for (final p in source) {
      p
        ..r = 200
        ..g = 180
        ..b = 160
        ..a = 255;
    }
    final jpeg = CanvasRenderer.encodeJpg(source, quality: 80);
    cache.putMemory('abc', jpeg);
    final hit = cache.readMemory('abc');
    expect(hit, isNotNull);
    expect(hit![0], 0xFF);
    expect(hit[1], 0xD8);
  });
}
