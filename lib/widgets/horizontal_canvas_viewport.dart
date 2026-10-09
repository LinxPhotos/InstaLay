import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Horizontal overflow for batch/tapestry previews: scrollbar when content is
/// wider than the viewport, and wheel / trackpad pan along X.
class HorizontalCanvasViewport extends StatefulWidget {
  const HorizontalCanvasViewport({
    super.key,
    required this.viewportHeight,
    required this.contentWidth,
    required this.child,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  /// Space below the canvas so the horizontal scrollbar does not cover art.
  static const double scrollbarGutter = 14;

  final double viewportHeight;
  final double contentWidth;
  final Widget child;
  final ScrollController? controller;
  final EdgeInsets padding;

  @override
  State<HorizontalCanvasViewport> createState() =>
      _HorizontalCanvasViewportState();
}

class _HorizontalCanvasViewportState extends State<HorizontalCanvasViewport> {
  late final ScrollController _controller;
  var _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _ownsController = true;
      _controller = ScrollController();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      return;
    }

    var delta = event.scrollDelta.dx;
    if (delta == 0) delta = event.scrollDelta.dy;
    if (delta == 0) return;

    final next = (_controller.offset + delta).clamp(
      0.0,
      position.maxScrollExtent,
    );
    _controller.jumpTo(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportW = constraints.maxWidth;
        final contentW = math.max(widget.contentWidth, viewportW);
        final totalH = widget.viewportHeight + scrollbarGutter;
        return SizedBox(
          height: totalH,
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            interactive: true,
            notificationPredicate: (_) => true,
            child: Listener(
              onPointerSignal: _onPointerSignal,
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: widget.padding,
                child: SizedBox(
                  width: contentW,
                  height: totalH,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: contentW,
                      height: widget.viewportHeight,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
