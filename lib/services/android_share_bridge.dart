import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One file staged from an Android share intent (already copied to app cache).
class AndroidSharedMediaItem {
  const AndroidSharedMediaItem({
    required this.cachePath,
    required this.displayName,
    required this.mimeType,
  });

  final String cachePath;
  final String displayName;
  final String mimeType;

  static AndroidSharedMediaItem? fromMap(Map<dynamic, dynamic>? raw) {
    if (raw == null) return null;
    final path = raw['cachePath'] as String?;
    final name = raw['displayName'] as String?;
    final mime = raw['mimeType'] as String?;
    if (path == null || path.isEmpty) return null;
    return AndroidSharedMediaItem(
      cachePath: path,
      displayName: name ?? '',
      mimeType: mime ?? 'application/octet-stream',
    );
  }
}

typedef AndroidShareReceivedHandler = void Function(
  List<AndroidSharedMediaItem> items,
);

/// Android `ACTION_SEND` / `ACTION_SEND_MULTIPLE` bridge (no-op elsewhere).
abstract final class AndroidShareBridge {
  static const MethodChannel _channel =
      MethodChannel('com.linxphotos.instalay/share');

  static AndroidShareReceivedHandler? _onReceived;
  static var _handlerRegistered = false;

  static bool get isSupported =>
      !kIsWeb && Platform.isAndroid;

  static void registerOnShareReceived(AndroidShareReceivedHandler? handler) {
    if (!isSupported) return;
    _onReceived = handler;
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShareReceived') {
        final items = await drainPending();
        if (items.isNotEmpty) {
          _onReceived?.call(items);
        }
      }
    });
  }

  static Future<List<AndroidSharedMediaItem>> drainPending() async {
    if (!isSupported) return const [];
    final raw = await _channel.invokeMethod<List<dynamic>>('drainPendingShares');
    if (raw == null || raw.isEmpty) return const [];
    return [
      for (final entry in raw)
        if (AndroidSharedMediaItem.fromMap(entry as Map<dynamic, dynamic>?) !=
            null)
          AndroidSharedMediaItem.fromMap(entry as Map<dynamic, dynamic>)!,
    ];
  }
}
