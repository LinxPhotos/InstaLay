import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pixel_zoom_viewer.dart';

/// Side-by-side before/after with linked pan; opens at 1:1 pixel zoom, centered.
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

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Pane(
            label: widget.beforeLabel,
            child: PixelZoomViewer(
              bytes: widget.beforeBytes,
              controller: _controller,
              imageWidth: widget.imageWidth,
              imageHeight: widget.imageHeight,
            ),
          ),
        ),
        VerticalDivider(width: 1, color: AppTheme.chrome(context)),
        Expanded(
          child: _Pane(
            label: widget.afterLabel,
            child: PixelZoomViewer(
              bytes: widget.afterBytes,
              controller: _controller,
              imageWidth: widget.imageWidth,
              imageHeight: widget.imageHeight,
            ),
          ),
        ),
      ],
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
        Expanded(child: child),
      ],
    );
  }
}
