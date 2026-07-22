import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/paper_texture.dart';
import '../services/paper_texture_generator.dart';
import '../theme/app_theme.dart';

/// Fixed square showing the selected paper grain at **100% zoom**
/// (one texture pixel ≈ one device pixel), using the current matte color.
///
/// Live canvas previews skip grain (export-only); this sample is how you
/// judge texture amplitude before exporting.
class PaperTexturePreview extends StatefulWidget {
  const PaperTexturePreview({
    super.key,
    required this.texture,
    required this.color,
    this.logicalSide = 120,
  });

  final PaperTexture texture;
  final Color color;

  /// Logical width/height of the preview square.
  final double logicalSide;

  @override
  State<PaperTexturePreview> createState() => _PaperTexturePreviewState();
}

class _PaperTexturePreviewState extends State<PaperTexturePreview> {
  ui.Image? _image;
  int _gen = 0;
  double? _builtDpr;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuild());
  }

  @override
  void didUpdateWidget(covariant PaperTexturePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.texture != widget.texture ||
        oldWidget.color != widget.color ||
        oldWidget.logicalSide != widget.logicalSide) {
      _rebuild();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _rebuild() async {
    if (!mounted) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final side = (widget.logicalSide * dpr).round().clamp(32, 512);
    final gen = ++_gen;
    _builtDpr = dpr;

    final c = widget.color;
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);

    final sample = img.Image(width: side, height: side, numChannels: 4);
    img.fill(sample, color: img.ColorRgba8(r, g, b, 255));
    PaperTextureGenerator.apply(sample, widget.texture);

    final rgba = Uint8List.fromList(
      sample.getBytes(order: img.ChannelOrder.rgba),
    );
    final decoded = await _decodeRgba(rgba, side, side);
    if (!mounted || gen != _gen) {
      decoded.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = decoded;
    });
  }

  static Future<ui.Image> _decodeRgba(Uint8List rgba, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      w,
      h,
      ui.PixelFormat.rgba8888,
      c.complete,
    );
    return c.future;
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (_builtDpr != null && (_builtDpr! - dpr).abs() > 0.01) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuild());
    }

    final side = widget.logicalSide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.texture == PaperTexture.none
              ? 'Flat matte (no grain)'
              : '100% zoom · ${widget.texture.description}',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.muted(context, 0.55),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.chrome(context)),
            borderRadius: BorderRadius.circular(4),
          ),
          clipBehavior: Clip.antiAlias,
          child: _image == null
              ? ColoredBox(color: widget.color)
              : RawImage(
                  image: _image,
                  width: side,
                  height: side,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
        ),
      ],
    );
  }
}
