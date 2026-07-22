import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/canvas_config.dart';
import '../models/project.dart';
import '../models/resample_algorithm.dart';

/// Disk + memory cache of framed preview JPEG bytes.
///
/// v2 stores JPEG directly so cache hits avoid a JXL→JPEG isolate round-trip.
class ThumbCache {
  ThumbCache({this.maxMemoryEntries = 64});

  static const cacheVersion = 2;

  final int maxMemoryEntries;
  Directory? _cachedDir;
  final LinkedHashMap<String, Uint8List> _memory = LinkedHashMap();

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
      File(p.join((await _root()).path, '$fingerprint.jpg'));

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
      'rot': photo?.rotationDeg ?? 0,
      'cl': photo?.cropLeft ?? 0,
      'ct': photo?.cropTop ?? 0,
      'cr': photo?.cropRight ?? 0,
      'cb': photo?.cropBottom ?? 0,
    };
    return fnv1a64Hex(jsonEncode(payload));
  }

  /// Fingerprint for a multi-photo tapestry preview (all sources + framing).
  Future<String> tapestryFingerprint({
    required List<PhotoItem> photos,
    required CanvasConfig config,
    required int longEdge,
    required ResampleAlgorithm algorithm,
  }) async {
    final sources = <Map<String, Object?>>[];
    for (final photo in photos) {
      final file = File(photo.sourcePath);
      var size = 0;
      var modifiedMs = 0;
      try {
        final stat = await file.stat();
        size = stat.size;
        modifiedMs = stat.modified.millisecondsSinceEpoch;
      } catch (_) {}
      sources.add({
        'path': photo.sourcePath,
        'size': size,
        'mtime': modifiedMs,
        'order': photo.order,
        'z': photo.zIndex,
        'ox': photo.offsetX,
        'oy': photo.offsetY,
        'sc': photo.scale,
        'rot': photo.rotationDeg,
        'cl': photo.cropLeft,
        'ct': photo.cropTop,
        'cr': photo.cropRight,
        'cb': photo.cropBottom,
      });
    }
    final payload = <String, Object?>{
      'v': cacheVersion,
      'kind': 'tapestry',
      'sources': sources,
      'edge': longEdge,
      'algo': algorithm.name,
      'aspect': config.aspect.id,
      'border': config.borderPx,
      'swatch': config.swatch.id,
      'swatchArgb': config.swatch.argb,
      'texture': config.texture.name,
      'gap': config.tapestryGapPx,
    };
    return fnv1a64Hex(jsonEncode(payload));
  }

  Uint8List? readMemory(String fingerprint) {
    final hit = _memory.remove(fingerprint);
    if (hit == null) return null;
    _memory[fingerprint] = hit; // LRU: move to end
    return hit;
  }

  void putMemory(String fingerprint, Uint8List jpeg) {
    _memory.remove(fingerprint);
    _memory[fingerprint] = jpeg;
    while (_memory.length > maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  /// Returns display JPEG on hit, or null on miss / failure.
  Future<Uint8List?> readDisplayJpeg(String fingerprint) async {
    final mem = readMemory(fingerprint);
    if (mem != null) return mem;
    try {
      final file = await _fileFor(fingerprint);
      if (!await file.exists()) return null;
      final jpeg = await file.readAsBytes();
      if (jpeg.isEmpty) return null;
      putMemory(fingerprint, jpeg);
      return jpeg;
    } catch (e, st) {
      debugPrint('ThumbCache read failed: $e\n$st');
      return null;
    }
  }

  Future<void> writeJpeg(String fingerprint, Uint8List jpeg) async {
    putMemory(fingerprint, jpeg);
    try {
      final file = await _fileFor(fingerprint);
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(jpeg, flush: true);
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
