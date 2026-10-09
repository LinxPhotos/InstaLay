import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../layout/responsive.dart';
import '../theme/app_theme.dart';
import 'pixel_zoom_viewer.dart';
import 'slow_task_body.dart';

/// Side-by-side Original / Preview with linked pan; opens at 1:1 pixel zoom.
class CodecComparisonView extends StatefulWidget {
  const CodecComparisonView({
    super.key,
    this.beforeBytes,
    this.afterBytes,
    this.beforeLoading = false,
    this.afterLoading = false,
    this.beforeLoadingMessage,
    this.afterLoadingMessage,
    this.beforeLabel = 'Original',
    this.afterLabel = 'Preview',
    this.imageWidth,
    this.imageHeight,
  });

  final Uint8List? beforeBytes;
  final Uint8List? afterBytes;
  final bool beforeLoading;
  final bool afterLoading;
  final String? beforeLoadingMessage;
  final String? afterLoadingMessage;
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
    final before = _Pane(
      label: widget.beforeLabel,
      loading: widget.beforeLoading,
      ready: widget.beforeBytes != null,
      progressMessage: widget.beforeLoadingMessage,
      child: widget.beforeBytes == null
          ? const SizedBox.shrink()
          : PixelZoomViewer(
              bytes: widget.beforeBytes!,
              controller: _controller,
              imageWidth: widget.imageWidth,
              imageHeight: widget.imageHeight,
            ),
    );
    final after = _Pane(
      label: widget.afterLabel,
      loading: widget.afterLoading,
      ready: widget.afterBytes != null,
      progressMessage: widget.afterLoadingMessage,
      child: widget.afterBytes == null
          ? const SizedBox.shrink()
          : PixelZoomViewer(
              bytes: widget.afterBytes!,
              controller: _controller,
              imageWidth: widget.imageWidth,
              imageHeight: widget.imageHeight,
            ),
    );
    if (!isWideLayout(context)) {
      return Column(
        children: [
          Expanded(child: before),
          Divider(height: 1, color: AppTheme.chrome(context)),
          Expanded(child: after),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: before),
        VerticalDivider(width: 1, color: AppTheme.chrome(context)),
        Expanded(child: after),
      ],
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({
    required this.label,
    required this.loading,
    required this.ready,
    required this.child,
    this.progressMessage,
  });

  final String label;
  final bool loading;
  final bool ready;
  final Widget child;
  final String? progressMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
          ),
        ),
        Expanded(
          child: SlowTaskBody(
            loading: loading,
            ready: ready,
            progressMessage: progressMessage,
            child: child,
          ),
        ),
      ],
    );
  }
}
