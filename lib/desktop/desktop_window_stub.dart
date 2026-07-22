import 'package:flutter/widgets.dart';

/// True on Windows / macOS / Linux (not web, not mobile).
bool get isDesktopWindowHost => false;

/// Restore saved geometry (or defaults) before the first frame is shown.
Future<void> bootstrapDesktopWindow() async {}

/// Listens for move/resize/maximize and persists window geometry.
class DesktopWindowBinder extends StatelessWidget {
  const DesktopWindowBinder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
