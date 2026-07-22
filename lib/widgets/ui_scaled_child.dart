import 'package:flutter/widgets.dart';

/// Applies persisted UI zoom without rewriting layout size or using a
/// [Transform]/[FittedBox].
///
/// Earlier whole-UI zoom laid out into `windowSize / scale` then painted with
/// a scale matrix (or FittedBox). That fought window constraints — especially
/// on un-maximize, when a pinned [SizedBox] could briefly adopt a stale
/// maximized [MediaQuery] size and overflow right/bottom — and desynced hit
/// targets from painted widgets (Canvases/Settings felt dead).
///
/// Zoom here is **textScaler-only**: layout still tracks the real window;
/// Ctrl/Cmd +/−/0 and the AppBar percent control remain wired to the same
/// [scale] factor. Full chrome zoom needs a different approach later.
class UiScaledChild extends StatelessWidget {
  const UiScaledChild({
    super.key,
    required this.scale,
    required this.child,
  });

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if ((scale - 1.0).abs() < 0.001) return child;

    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(scale),
      ),
      child: child,
    );
  }
}
