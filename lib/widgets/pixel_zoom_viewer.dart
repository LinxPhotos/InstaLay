import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Pan/zoom viewer that opens at **1:1 pixel zoom** (one image pixel ≈ one
/// device pixel), not forced into a square aspect-ratio box.
class PixelZoomViewer extends StatefulWidget {
  const PixelZoomViewer({
    super.key,
    required this.bytes,
    this.controller,
    this.imageWidth,
    this.imageHeight,
    this.minScale = 0.05,
    this.maxScale = 16,
    this.backgroundColor = const Color(0xFF2A2A28),
  });

  final Uint8List bytes;
  final TransformationController? controller;
  final int? imageWidth;
  final int? imageHeight;
  final double minScale;
  final double maxScale;
  final Color backgroundColor;

  @override
  State<PixelZoomViewer> createState() => _PixelZoomViewerState();
}

class _PixelZoomViewerState extends State<PixelZoomViewer> {
  TransformationController? _owned;
  Size? _viewport;
  Size? _imagePx;
  double? _appliedDpr;
  bool _centered = false;

  TransformationController get _controller =>
      widget.controller ?? (_owned ??= TransformationController());

  @override
  void initState() {
    super.initState();
    _probeImageSize();
  }

  @override
  void didUpdateWidget(covariant PixelZoomViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes ||
        oldWidget.imageWidth != widget.imageWidth ||
        oldWidget.imageHeight != widget.imageHeight) {
      _centered = false;
      _probeImageSize();
    }
  }

  Future<void> _probeImageSize() async {
    if (widget.imageWidth != null && widget.imageHeight != null) {
      _imagePx = Size(
        widget.imageWidth!.toDouble(),
        widget.imageHeight!.toDouble(),
      );
      _tryCenter();
      return;
    }
    final codec = await ui.instantiateImageCodec(widget.bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    if (!mounted) {
      img.dispose();
      return;
    }
    setState(() {
      _imagePx = Size(img.width.toDouble(), img.height.toDouble());
    });
    img.dispose();
    _tryCenter();
  }

  /// Logical size of the bitmap at true 1:1 device pixels.
  Size? _displaySize(double dpr) {
    final px = _imagePx;
    if (px == null || dpr <= 0) return null;
    return Size(px.width / dpr, px.height / dpr);
  }

  void _tryCenter() {
    final vp = _viewport;
    final dpr = _appliedDpr;
    if (vp == null || dpr == null || _centered) return;
    final disp = _displaySize(dpr);
    if (disp == null) return;
    final dx = (vp.width - disp.width) / 2;
    final dy = (vp.height - disp.height) / 2;
    _controller.value = Matrix4.identity()..translateByDouble(dx, dy, 0, 1);
    _centered = true;
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (_appliedDpr != dpr) {
      _appliedDpr = dpr;
      _centered = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryCenter());
    }

    final disp = _displaySize(dpr);

    return ColoredBox(
      color: widget.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final next = Size(constraints.maxWidth, constraints.maxHeight);
          if (_viewport != next) {
            _viewport = next;
            WidgetsBinding.instance.addPostFrameCallback((_) => _tryCenter());
          }

          return InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            minScale: widget.minScale,
            maxScale: widget.maxScale,
            boundaryMargin: const EdgeInsets.all(4000),
            child: disp == null
                ? Image.memory(
                    widget.bytes,
                    scale: dpr,
                    filterQuality: FilterQuality.none,
                    gaplessPlayback: true,
                  )
                : SizedBox(
                    width: disp.width,
                    height: disp.height,
                    child: Image.memory(
                      widget.bytes,
                      width: disp.width,
                      height: disp.height,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                      gaplessPlayback: true,
                    ),
                  ),
          );
        },
      ),
    );
  }
}
