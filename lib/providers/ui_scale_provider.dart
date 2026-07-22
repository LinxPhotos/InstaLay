import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted whole-UI zoom factor (1.0 = 100%). Desktop Ctrl+/−/0 shortcuts.
final uiScaleProvider =
    NotifierProvider<UiScaleNotifier, double>(UiScaleNotifier.new);

class UiScaleNotifier extends Notifier<double> {
  static const prefsKey = 'instalay_ui_scale_v1';
  static const minScale = 0.75;
  static const maxScale = 1.5;
  static const step = 0.1;
  static const defaultScale = 1.0;

  @override
  double build() {
    _restore();
    return defaultScale;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getDouble(prefsKey);
      if (raw == null) return;
      final loaded = _clamp(raw);
      if (loaded != state) state = loaded;
    } catch (_) {
      // Keep default.
    }
  }

  Future<void> setScale(double scale) async {
    final next = _clamp(scale);
    if (next == state) return;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(prefsKey, next);
    } catch (_) {
      // Preference is best-effort; UI still updates.
    }
  }

  Future<void> zoomIn() => setScale(state + step);

  Future<void> zoomOut() => setScale(state - step);

  Future<void> reset() => setScale(defaultScale);

  static double _clamp(double value) {
    final snapped = (value / step).round() * step;
    return double.parse(
      math.max(minScale, math.min(maxScale, snapped)).toStringAsFixed(1),
    );
  }
}
