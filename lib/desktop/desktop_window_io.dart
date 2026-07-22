import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../services/window_geometry_store.dart';

/// True on Windows / macOS / Linux (not web, not mobile).
bool get isDesktopWindowHost {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS =>
      true,
    _ => false,
  };
}

/// Restore saved geometry (or defaults) before the first frame is shown.
Future<void> bootstrapDesktopWindow() async {
  if (!isDesktopWindowHost) return;

  await windowManager.ensureInitialized();

  final saved = await WindowGeometryStore.load();
  final size = saved?.size ?? WindowGeometryStore.defaultSize;

  final options = WindowOptions(
    size: size,
    center: saved?.position == null,
    minimumSize: WindowGeometryStore.minSize,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    final pos = saved?.position;
    if (pos != null) {
      await windowManager.setPosition(pos);
    }
    if (saved?.maximized == true) {
      await windowManager.maximize();
    }
    await windowManager.show();
    await windowManager.focus();
  });
}

/// Listens for move/resize/maximize and persists window geometry.
class DesktopWindowBinder extends StatefulWidget {
  const DesktopWindowBinder({super.key, required this.child});

  final Widget child;

  @override
  State<DesktopWindowBinder> createState() => _DesktopWindowBinderState();
}

class _DesktopWindowBinderState extends State<DesktopWindowBinder>
    with WindowListener {
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    if (isDesktopWindowHost) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (isDesktopWindowHost) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), _persist);
  }

  Future<void> _persist() async {
    if (!isDesktopWindowHost) return;
    try {
      final maximized = await windowManager.isMaximized();
      // When maximized, keep the last restored size already on disk; only
      // refresh the maximized flag. Reading getSize while maximized returns
      // the work-area size and would overwrite the true restore bounds.
      if (maximized) {
        final existing = await WindowGeometryStore.load();
        if (existing != null) {
          await WindowGeometryStore.save(
            WindowGeometry(
              width: existing.width,
              height: existing.height,
              x: existing.x,
              y: existing.y,
              maximized: true,
            ),
          );
        } else {
          final size = await windowManager.getSize();
          final pos = await windowManager.getPosition();
          await WindowGeometryStore.save(
            WindowGeometry(
              width: size.width,
              height: size.height,
              x: pos.dx,
              y: pos.dy,
              maximized: true,
            ),
          );
        }
        return;
      }

      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      await WindowGeometryStore.save(
        WindowGeometry(
          width: size.width,
          height: size.height,
          x: pos.dx,
          y: pos.dy,
          maximized: false,
        ),
      );
    } catch (_) {
      // Preference is best-effort.
    }
  }

  @override
  void onWindowClose() {
    _saveDebounce?.cancel();
    unawaited(_persist());
  }

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  @override
  void onWindowResize() {
    // Linux often only fires continuous resize; debounce still applies.
    if (defaultTargetPlatform == TargetPlatform.linux) {
      _scheduleSave();
    }
  }

  @override
  void onWindowMove() {
    if (defaultTargetPlatform == TargetPlatform.linux) {
      _scheduleSave();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
