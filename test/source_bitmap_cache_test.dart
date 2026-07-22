import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:instalay/services/image_pipeline.dart';
import 'package:instalay/services/source_bitmap_cache.dart';

void main() {
  test('source bitmap fingerprint is stable for same payload', () async {
    final cache = SourceBitmapCache(maxMemoryEntries: 4);
    final dir = await Directory.systemTemp.createTemp('instalay_src_fp_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'a.jpg'));
    await file.writeAsBytes([1, 2, 3]);

    final a = await cache.fingerprint(sourcePath: file.path, maxLongEdge: 1440);
    final b = await cache.fingerprint(sourcePath: file.path, maxLongEdge: 1440);
    final c = await cache.fingerprint(sourcePath: file.path, maxLongEdge: 720);
    expect(a, b);
    expect(a, isNot(c));
    expect(a.length, 16);
  });

  test('memory cache returns RGBA without disk', () {
    final cache = SourceBitmapCache(maxMemoryEntries: 4);
    final rgba = Uint8List.fromList([10, 20, 30, 255, 1, 2, 3, 255]);
    final bitmap = RgbaBitmap(rgba: rgba, width: 2, height: 1);
    cache.putMemory('abc', bitmap);
    final hit = cache.readMemory('abc');
    expect(hit, isNotNull);
    expect(hit!.width, 2);
    expect(hit.height, 1);
    expect(hit.rgba, rgba);
  });

  test('disk round-trip preserves RGBA blob', () async {
    final dir = await Directory.systemTemp.createTemp('instalay_src_disk_');
    addTearDown(() => dir.delete(recursive: true));

    final cache = SourceBitmapCache(maxMemoryEntries: 2, rootDirectory: dir);
    final file = File(p.join(dir.path, 'src.bin'));
    await file.writeAsBytes([9, 9, 9]);

    final key = await cache.fingerprint(sourcePath: file.path, maxLongEdge: 64);
    final rgba = Uint8List(4 * 3 * 2);
    for (var i = 0; i < rgba.length; i++) {
      rgba[i] = i % 256;
    }
    final bitmap = RgbaBitmap(rgba: rgba, width: 3, height: 2);
    await cache.write(key, bitmap);

    // Overflow LRU so the next read must come from disk.
    cache.putMemory(
      'other1',
      RgbaBitmap(rgba: Uint8List(4), width: 1, height: 1),
    );
    cache.putMemory(
      'other2',
      RgbaBitmap(rgba: Uint8List(4), width: 1, height: 1),
    );
    cache.putMemory(
      'other3',
      RgbaBitmap(rgba: Uint8List(4), width: 1, height: 1),
    );
    expect(cache.readMemory(key), isNull);

    final hit = await cache.read(key);
    expect(hit, isNotNull);
    expect(hit!.width, 3);
    expect(hit.height, 2);
    expect(hit.rgba, rgba);
  });
}
