import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Side-by-side before/after with linked pan; starts at 1:1 centered.
class CodecComparisonView extends StatefulWidget {
  const CodecComparisonView({
    super.key,
    required this.beforeBytes,
    required this.afterBytes,
    this.beforeLabel = 'Before',
    this.afterLabel = 'After',
    this.imageWidth,
    this.imageHeight,
  });

  final Uint8List beforeBytes;
  final Uint8List afterBytes;
  final String beforeLabel;
  final String afterLabel;
  final int? imageWidth;
  final int? imageHeight;

  @override
  State<CodecComparisonView> createState() => _CodecComparisonViewState();
}

class _CodecComparisonViewState extends State<CodecComparisonView> {
  late final TransformationController _controller;
  Size? _viewport;
  Size? _imageSize;
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _probeImageSize();
  }

  @override
  void didUpdateWidget(covariant CodecComparisonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beforeBytes != widget.beforeBytes ||
        oldWidget.imageWidth != widget.imageWidth ||
        oldWidget.imageHeight != widget.imageHeight) {
      _centered = false;
      _probeImageSize();
    }
  }

  Future<void> _probeImageSize() async {
    if (widget.imageWidth != null && widget.imageHeight != null) {
      _imageSize = Size(
        widget.imageWidth!.toDouble(),
        widget.imageHeight!.toDouble(),
      );
      _tryCenter();
      return;
    }
    final img = await decodeImageFromList(widget.beforeBytes);
    if (!mounted) return;
    setState(() {
      _imageSize = Size(img.width.toDouble(), img.height.toDouble());
    });
    _tryCenter();
  }

  void _tryCenter() {
    final vp = _viewport;
    final img = _imageSize;
    if (vp == null || img == null || _centered) return;
    final dx = (vp.width - img.width) / 2;
    final dy = (vp.height - img.height) / 2;
    _controller.value = Matrix4.identity()..translateByDouble(dx, dy, 0, 1);
    _centered = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final next = Size(constraints.maxWidth, constraints.maxHeight);
        if (_viewport != next) {
          _viewport = next;
          WidgetsBinding.instance.addPostFrameCallback((_) => _tryCenter());
        }

        return Row(
          children: [
            Expanded(
              child: _Pane(
                label: widget.beforeLabel,
                child: _ZoomPane(
                  controller: _controller,
                  bytes: widget.beforeBytes,
                  imageSize: _imageSize,
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: AppTheme.mist),
            Expanded(
              child: _Pane(
                label: widget.afterLabel,
                child: _ZoomPane(
                  controller: _controller,
                  bytes: widget.afterBytes,
                  imageSize: _imageSize,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: const Color(0xFF2A2A28),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _ZoomPane extends StatelessWidget {
  const _ZoomPane({
    required this.controller,
    required this.bytes,
    required this.imageSize,
  });

  final TransformationController controller;
  final Uint8List bytes;
  final Size? imageSize;

  @override
  Widget build(BuildContext context) {
    final size = imageSize;
    return InteractiveViewer(
      transformationController: controller,
      constrained: false,
      minScale: 0.05,
      maxScale: 16,
      boundaryMargin: const EdgeInsets.all(4000),
      child: size == null
          ? Image.memory(bytes, filterQuality: FilterQuality.none)
          : SizedBox(
              width: size.width,
              height: size.height,
              child: Image.memory(
                bytes,
                width: size.width,
                height: size.height,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                gaplessPlayback: true,
              ),
            ),
    );
  }
}
