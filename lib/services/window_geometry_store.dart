import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last desktop window frame (logical pixels), persisted across launches.
@immutable
class WindowGeometry {
  const WindowGeometry({
    required this.width,
    required this.height,
    this.x,
    this.y,
    this.maximized = false,
  });

  final double width;
  final double height;
  final double? x;
  final double? y;
  final bool maximized;

  Size get size => Size(width, height);

  Offset? get position =>
      x == null || y == null ? null : Offset(x!, y!);
}

/// Reads/writes [WindowGeometry] via [SharedPreferences].
class WindowGeometryStore {
  WindowGeometryStore._();

  static const prefsKeyPrefix = 'instalay_window_v1';
  static const defaultSize = Size(1600, 900);
  static const minSize = Size(800, 500);

  static const _w = '${prefsKeyPrefix}_w';
  static const _h = '${prefsKeyPrefix}_h';
  static const _x = '${prefsKeyPrefix}_x';
  static const _y = '${prefsKeyPrefix}_y';
  static const _max = '${prefsKeyPrefix}_maximized';

  static Future<WindowGeometry?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final w = prefs.getDouble(_w);
      final h = prefs.getDouble(_h);
      if (w == null || h == null || w < 200 || h < 200) return null;
      return WindowGeometry(
        width: w,
        height: h,
        x: prefs.getDouble(_x),
        y: prefs.getDouble(_y),
        maximized: prefs.getBool(_max) ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(WindowGeometry geometry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_w, geometry.width);
      await prefs.setDouble(_h, geometry.height);
      if (geometry.x != null) {
        await prefs.setDouble(_x, geometry.x!);
      }
      if (geometry.y != null) {
        await prefs.setDouble(_y, geometry.y!);
      }
      await prefs.setBool(_max, geometry.maximized);
    } catch (_) {
      // Best-effort preference.
    }
  }
}
