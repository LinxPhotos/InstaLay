import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/canvas_config.dart';
import '../models/project.dart';
import '../models/resample_algorithm.dart';
import 'image_pipeline.dart';

/// Disk cache of framed thumbnails as JPEG XL (`.jxl`).
///
/// UI still consumes JPEG (Flutter [Image] lacks JXL); cache hits decode JXL →
/// JPEG cheaply vs re-reading camera files and re-framing.
class ThumbCache {
  ThumbCache();

  static const cacheVersion = 1;

  Directory? _cachedDir;

  Future<Directory> _root() async {
    if (_cachedDir != null) return _cachedDir!;
    if (kIsWeb) {
      throw UnsupportedError('Thumb cache is not available on web.');
    }
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'insta_lay', 'thumb_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _cachedDir = dir;
    return dir;
  }

  Future<File> _fileFor(String fingerprint) async =>
      File(p.join((await _root()).path, '$fingerprint.jxl'));

  /// Stable key from source identity + framing inputs that affect the thumb.
  Future<String> fingerprint({
    required String sourcePath,
    required CanvasConfig config,
    required int longEdge,
    required ResampleAlgorithm algorithm,
    PhotoItem? photo,
  }) async {
    final file = File(sourcePath);
    var size = 0;
    var modifiedMs = 0;
    try {
      final stat = await file.stat();
      size = stat.size;
      modifiedMs = stat.modified.millisecondsSinceEpoch;
    } catch (_) {
      // Missing source — still key path so we don't collide wrongly.
    }

    final payload = <String, Object?>{
      'v': cacheVersion,
      'path': sourcePath,
      'size': size,
      'mtime': modifiedMs,
      'edge': longEdge,
      'algo': algorithm.name,
      'aspect': config.aspect.id,
      'border': config.borderPx,
      'fit': config.fitMode.name,
      'swatch': config.swatch.id,
      'swatchArgb': config.swatch.argb,
      'texture': config.texture.name,
      'layout': config.layoutMode.name,
      'gap': config.tapestryGapPx,
      'ox': photo?.offsetX ?? 0,
      'oy': photo?.offsetY ?? 0,
      'sc': photo?.scale ?? 1,
    };
    return fnv1a64Hex(jsonEncode(payload));
  }

  /// Returns display JPEG on hit, or null on miss / failure.
  Future<Uint8List?> readDisplayJpeg(String fingerprint) async {
    try {
      final file = await _fileFor(fingerprint);
      if (!await file.exists()) return null;
      final jxl = await file.readAsBytes();
      if (jxl.isEmpty) return null;
      return Isolate.run(() => ImagePipeline.jxlCacheToJpg(jxl));
    } catch (e, st) {
      debugPrint('ThumbCache read failed: $e\n$st');
      return null;
    }
  }

  Future<void> writeJxl(String fingerprint, Uint8List jxl) async {
    try {
      final file = await _fileFor(fingerprint);
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(jxl, flush: true);
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } catch (e, st) {
      debugPrint('ThumbCache write failed: $e\n$st');
    }
  }

  /// FNV-1a 64-bit → 16 hex chars (no extra crypto dependency).
  static String fnv1a64Hex(String input) {
    // BigInt: Dart VM signed 64-bit ints make `& 0xFFFFFFFFFFFFFFFF` / toUnsigned(64) a no-op.
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = BigInt.parse('ffffffffffffffff', radix: 16);
    for (final unit in utf8.encode(input)) {
      hash ^= BigInt.from(unit);
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
