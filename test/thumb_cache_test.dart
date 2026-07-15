import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:insta_lay/models/export_codec.dart';
import 'package:insta_lay/services/image_codec_service.dart';
import 'package:insta_lay/services/image_pipeline.dart';
import 'package:insta_lay/services/thumb_cache.dart';

void main() {
  test('thumb cache fingerprint is stable for same payload', () {
    const a = 'same-key-material';
    expect(ThumbCache.fnv1a64Hex(a), ThumbCache.fnv1a64Hex(a));
    expect(ThumbCache.fnv1a64Hex(a), isNot(ThumbCache.fnv1a64Hex('other')));
    expect(ThumbCache.fnv1a64Hex(a).length, 16);
  });

  test('JXL thumb cache round-trips to JPEG via pipeline', () {
    final source = img.Image(width: 32, height: 40);
    for (final p in source) {
      p
        ..r = 200
        ..g = 180
        ..b = 160
        ..a = 255;
    }
    final jxl = ImageCodecService.encodeJxl(
      source,
      settings: const ExportCodecSettings(
        format: ExportFormat.jpegXl,
        jxlMode: JxlMode.lossy,
        jxlQuality: 85,
      ),
    );
    expect(jxl, isNotEmpty);
    final jpeg = ImagePipeline.jxlCacheToJpg(jxl);
    expect(jpeg.length, greaterThan(20));
    // SOI marker
    expect(jpeg[0], 0xFF);
    expect(jpeg[1], 0xD8);
  });
}
