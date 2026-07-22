import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jxl_ffi/jxl_ffi.dart';

import 'package:instalay/models/export_codec.dart';
import 'package:instalay/services/image_codec_service.dart';

void main() {
  img.Image solid() {
    final image = img.Image(width: 64, height: 48);
    img.fill(image, color: img.ColorRgba8(180, 120, 90, 255));
    return image;
  }

  test('jpeg encode respects quality size trend', () async {
    final image = solid();
    final hi = await ImageCodecService.encode(
      image,
      const ExportCodecSettings(format: ExportFormat.jpeg, jpegQuality: 95),
    );
    final lo = await ImageCodecService.encode(
      image,
      const ExportCodecSettings(format: ExportFormat.jpeg, jpegQuality: 40),
    );
    expect(lo.byteLength, lessThan(hi.byteLength));
  });

  test('png / webp / jxl / roundtrip decode', () async {
    final image = solid();

    final png = await ImageCodecService.encode(
      image,
      const ExportCodecSettings(format: ExportFormat.png),
    );
    expect(ImageCodecService.decode(png.bytes, pathHint: 'x.png'), isNotNull);

    final webp = await ImageCodecService.encode(
      image,
      const ExportCodecSettings(format: ExportFormat.webp),
    );
    expect(ImageCodecService.decode(webp.bytes, pathHint: 'x.webp'), isNotNull);

    final jxl = await ImageCodecService.encode(
      image,
      const ExportCodecSettings(
        format: ExportFormat.jpegXl,
        jxlMode: JxlMode.lossless,
      ),
    );
    final decoded = ImageCodecService.decode(jxl.bytes, pathHint: 'x.jxl');
    expect(decoded, isNotNull);
    expect(decoded!.width, 64);
    expect(decoded.height, 48);
  });

  test('jxl lossy distance increases shrink file', () async {
    final image = solid();
    final tight = await ImageCodecService.encode(
      image,
      const ExportCodecSettings(
        format: ExportFormat.jpegXl,
        jxlMode: JxlMode.lossy,
        jxlDistance: 3.0,
      ),
    );
    final loose = await ImageCodecService.encode(
      image,
      const ExportCodecSettings(
        format: ExportFormat.jpegXl,
        jxlMode: JxlMode.lossy,
        jxlDistance: 0.5,
      ),
    );
    expect(tight.byteLength, lessThan(loose.byteLength));
  });

  test('jxl ffi native roundtrip (skips when unavailable)', () async {
    if (!JxlFfi.isAvailable) return;

    final image = solid();
    final jxl = await ImageCodecService.encode(
      image,
      const ExportCodecSettings(
        format: ExportFormat.jpegXl,
        jxlMode: JxlMode.lossless,
      ),
    );
    final decoded = ImageCodecService.decode(jxl.bytes, pathHint: 'x.jxl');
    expect(decoded, isNotNull);
    expect(decoded!.width, 64);
    expect(decoded.height, 48);
  });
}
