import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'app_paths.dart';
import 'image_pipeline.dart';
import 'thumb_cache.dart';

/// Disk + memory cache of decoded source RGBA bitmaps for interactive editing.
///
/// Keyed by source identity + decode long-edge budget (not framing params), so
/// matte/border/aspect edits reuse the same decode.
class SourceBitmapCache {
  SourceBitmapCache({
    this.maxMemoryEntries = 16,
    Directory? rootDirectory,
  }) : _rootOverride = rootDirectory;

  static const cacheVersion = 1;
  static const _magic = [0x49, 0x4C, 0x53, 0x42]; // ILSB
  static const _headerBytes = 16; // magic(4) + version(4) + w(4) + h(4)

  final int maxMemoryEntries;
  final Directory? _rootOverride;
  Directory? _cachedDir;
  final LinkedHashMap<String, RgbaBitmap> _memory = LinkedHashMap();

  Future<Directory> _root() async {
    if (_rootOverride != null) return _rootOverride;
    if (_cachedDir != null) return _cachedDir!;
    if (kIsWeb) {
      throw UnsupportedError('Source bitmap cache is not available on web.');
    }
    final dir = Directory(
      p.join((await appSupportRoot()).path, 'source_bitmap_cache'),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    _cachedDir = dir;
    return dir;
  }

  Future<File> _fileFor(String fingerprint) async =>
      File(p.join((await _root()).path, '$fingerprint.rgba'));

  /// Stable key from source file identity + decode budget.
  Future<String> fingerprint({
    required String sourcePath,
    required int maxLongEdge,
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
      'edge': maxLongEdge,
    };
    return ThumbCache.fnv1a64Hex(jsonEncode(payload));
  }

  RgbaBitmap? readMemory(String fingerprint) {
    final hit = _memory.remove(fingerprint);
    if (hit == null) return null;
    _memory[fingerprint] = hit; // LRU: move to end
    return hit;
  }

  void putMemory(String fingerprint, RgbaBitmap bitmap) {
    _memory.remove(fingerprint);
    _memory[fingerprint] = bitmap;
    while (_memory.length > maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  /// Returns cached RGBA on hit, or null on miss / failure.
  Future<RgbaBitmap?> read(String fingerprint) async {
    final mem = readMemory(fingerprint);
    if (mem != null) return mem;
    try {
      final file = await _fileFor(fingerprint);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final bitmap = _decodeBlob(bytes);
      if (bitmap == null) return null;
      putMemory(fingerprint, bitmap);
      return bitmap;
    } catch (e, st) {
      debugPrint('SourceBitmapCache read failed: $e\n$st');
      return null;
    }
  }

  Future<void> write(String fingerprint, RgbaBitmap bitmap) async {
    putMemory(fingerprint, bitmap);
    try {
      final file = await _fileFor(fingerprint);
      await file.parent.create(recursive: true);
      final blob = _encodeBlob(bitmap);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(blob, flush: true);
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } catch (e, st) {
      debugPrint('SourceBitmapCache write failed: $e\n$st');
    }
  }

  /// Load from cache or run [decode] and store the result.
  Future<RgbaBitmap> ensure({
    required String sourcePath,
    required int maxLongEdge,
    required Future<RgbaBitmap?> Function() decode,
  }) async {
    final key = await fingerprint(
      sourcePath: sourcePath,
      maxLongEdge: maxLongEdge,
    );
    final hit = await read(key);
    if (hit != null) return hit;

    final decoded = await decode();
    if (decoded == null) {
      throw StateError('Cannot decode $sourcePath');
    }
    await write(key, decoded);
    return decoded;
  }

  static Uint8List _encodeBlob(RgbaBitmap bitmap) {
    final rgba = bitmap.rgba;
    final expected = bitmap.width * bitmap.height * 4;
    if (rgba.lengthInBytes < expected) {
      throw ArgumentError(
        'RGBA length ${rgba.lengthInBytes} < expected $expected',
      );
    }
    final out = Uint8List(_headerBytes + expected);
    final bd = ByteData.sublistView(out);
    out[0] = _magic[0];
    out[1] = _magic[1];
    out[2] = _magic[2];
    out[3] = _magic[3];
    bd.setUint32(4, cacheVersion, Endian.little);
    bd.setUint32(8, bitmap.width, Endian.little);
    bd.setUint32(12, bitmap.height, Endian.little);
    out.setRange(_headerBytes, _headerBytes + expected, rgba);
    return out;
  }

  static RgbaBitmap? _decodeBlob(Uint8List bytes) {
    if (bytes.lengthInBytes < _headerBytes) return null;
    if (bytes[0] != _magic[0] ||
        bytes[1] != _magic[1] ||
        bytes[2] != _magic[2] ||
        bytes[3] != _magic[3]) {
      return null;
    }
    final bd = ByteData.sublistView(bytes);
    final version = bd.getUint32(4, Endian.little);
    if (version != cacheVersion) return null;
    final width = bd.getUint32(8, Endian.little);
    final height = bd.getUint32(12, Endian.little);
    if (width <= 0 || height <= 0 || width > 16384 || height > 16384) {
      return null;
    }
    final expected = width * height * 4;
    if (bytes.lengthInBytes < _headerBytes + expected) return null;
    final rgba = Uint8List.sublistView(
      bytes,
      _headerBytes,
      _headerBytes + expected,
    );
    // Copy so sublistView isn't tied to a huge mmap-style buffer lifetime.
    return RgbaBitmap(
      rgba: Uint8List.fromList(rgba),
      width: width,
      height: height,
    );
  }
}
