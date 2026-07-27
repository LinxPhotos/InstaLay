import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Classic light/dark grid used under transparent mattes in the editor.
abstract final class TransparencyCheckerboard {
  static const light = Color(0xFFD8D6D0);
  static const dark = Color(0xFFB0AEA6);

  /// Paint a checkerboard filling [rect] in logical pixels.
  static void paint(
    Canvas canvas,
    Rect rect, {
    double cell = 12,
  }) {
    final lightPaint = Paint()..color = light;
    final darkPaint = Paint()..color = dark;
    canvas.drawRect(rect, lightPaint);
    final cols = (rect.width / cell).ceil();
    final rows = (rect.height / cell).ceil();
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        if ((row + col).isOdd) continue;
        final left = rect.left + col * cell;
        final top = rect.top + row * cell;
        canvas.drawRect(
          Rect.fromLTWH(
            left,
            top,
            cell.clamp(0, rect.right - left),
            cell.clamp(0, rect.bottom - top),
          ),
          darkPaint,
        );
      }
    }
  }
}

/// Small repeating checkerboard as a [Decoration] (for chips / previews).
class CheckerboardDecoration extends Decoration {
  const CheckerboardDecoration({
    this.cell = 6,
    this.borderRadius,
    this.border,
  });

  final double cell;
  final BorderRadius? borderRadius;
  final BoxBorder? border;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _CheckerboardPainter(
      cell: cell,
      borderRadius: borderRadius,
      border: border,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckerboardDecoration &&
          cell == other.cell &&
          borderRadius == other.borderRadius &&
          border == other.border;

  @override
  int get hashCode => Object.hash(cell, borderRadius, border);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('cell', cell))
      ..add(DiagnosticsProperty('borderRadius', borderRadius))
      ..add(DiagnosticsProperty('border', border));
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    if (borderRadius != null) {
      return Path()..addRRect(borderRadius!.toRRect(rect));
    }
    return Path()..addRect(rect);
  }
}

class _CheckerboardPainter extends BoxPainter {
  _CheckerboardPainter({
    required this.cell,
    this.borderRadius,
    this.border,
  });

  final double cell;
  final BorderRadius? borderRadius;
  final BoxBorder? border;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final rect = offset & size;
    canvas.save();
    if (borderRadius != null) {
      canvas.clipRRect(borderRadius!.toRRect(rect));
    }
    TransparencyCheckerboard.paint(canvas, rect, cell: cell);
    canvas.restore();
    border?.paint(
      canvas,
      rect,
      shape: BoxShape.rectangle,
      borderRadius: borderRadius,
    );
  }
}
