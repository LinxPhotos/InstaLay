import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Middle-button drag to scroll horizontally (click without drag is not consumed).
class MiddleMouseScrollPan {
  int? _pointer;
  double _accumDx = 0;
  var _dragging = false;

  static const double slop = 4;

  bool handlesPointer(int pointer) => _pointer == pointer;

  bool get isDragging => _dragging;

  void onPointerDown(PointerDownEvent event) {
    if (event.buttons & kMiddleMouseButton == 0) return;
    _pointer = event.pointer;
    _accumDx = 0;
    _dragging = false;
  }

  /// Returns true when the move was handled as a pan gesture.
  bool onPointerMove(PointerMoveEvent event, ScrollController controller) {
    if (event.pointer != _pointer) return false;
    if (!controller.hasClients) return false;

    _accumDx += event.delta.dx;
    if (!_dragging) {
      if (_accumDx.abs() < slop) return false;
      _dragging = true;
    }

    final position = controller.position;
    if (!position.hasContentDimensions) return true;
    final next = (controller.offset - event.delta.dx).clamp(
      0.0,
      position.maxScrollExtent,
    );
    controller.jumpTo(next);
    return true;
  }

  /// Returns true when the gesture ended as a click (no drag).
  bool onPointerUp(PointerEvent event) {
    if (event.pointer != _pointer) return false;
    final click = !_dragging;
    _pointer = null;
    _dragging = false;
    _accumDx = 0;
    return click;
  }
}
