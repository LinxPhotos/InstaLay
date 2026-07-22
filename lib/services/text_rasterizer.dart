import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/project.dart';

/// Layout / paint helpers for tapestry [TextItem]s on a Skia canvas,
/// plus CPU export rasterization via [PictureRecorder].
class TextRasterizer {
  const TextRasterizer._();

  static TextStyle styleFor(TextItem text, {double pixelRatio = 1}) {
    return TextStyle(
      fontFamily: text.fontFamily,
      fontSize: text.effectiveFontSize * pixelRatio,
      fontWeight: text.flutterFontWeight,
      color: text.color,
      height: 1.15,
    );
  }

  static TextPainter painterFor(TextItem text, {double pixelRatio = 1}) {
    final content = text.text.isEmpty ? ' ' : text.text;
    return TextPainter(
      text: TextSpan(text: content, style: styleFor(text, pixelRatio: pixelRatio)),
      textDirection: TextDirection.ltr,
      maxLines: 20,
    )..layout();
  }

  static Size measure(TextItem text) {
    final tp = painterFor(text);
    return Size(tp.width, tp.height);
  }

  static void paint(Canvas canvas, TextItem text) {
    final tp = painterFor(text);
    canvas.save();
    final cx = text.offsetX + tp.width / 2;
    final cy = text.offsetY + tp.height / 2;
    canvas.translate(cx, cy);
    canvas.rotate(text.rotationDeg * math.pi / 180);
    canvas.translate(-cx, -cy);
    tp.paint(canvas, Offset(text.offsetX, text.offsetY));
    canvas.restore();
  }

  /// Bake text into an unrotated RGBA [img.Image] for CPU export compositing.
  static Future<img.Image> toImage(TextItem item, {double pixelRatio = 1}) async {
    final painter = painterFor(item, pixelRatio: pixelRatio);
    final w = painter.width.ceil().clamp(1, 8000);
    final h = painter.height.ceil().clamp(1, 8000);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(w, h);
    final bd = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();
    picture.dispose();
    if (bd == null) {
      return img.Image(width: 1, height: 1);
    }
    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes).buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }
}
