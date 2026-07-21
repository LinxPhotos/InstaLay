import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:insta_lay/models/canvas_config.dart';
import 'package:insta_lay/models/resample_algorithm.dart';
import 'package:insta_lay/services/image_pipeline.dart';

void main() {
  test('frameRgbaToRgba returns framed pixels without JPEG header', () {
    final source = img.Image(width: 80, height: 60);
    img.fill(source, color: img.ColorRgba8(180, 120, 90, 255));
    final rgba = Uint8List.fromList(source.getBytes(order: img.ChannelOrder.rgba));
    const config = CanvasConfig();

    final framed = ImagePipeline.frameRgbaToRgba(
      FrameJob(
        rgba: rgba,
        width: source.width,
        height: source.height,
        configJson: config.toJson(),
        longEdge: 200,
        algorithmName: ResampleAlgorithm.linear.name,
      ),
    );

    expect(framed.width / framed.height, closeTo(4 / 5, 0.02));
    expect(framed.rgba.length, framed.width * framed.height * 4);
    // Not a JPEG SOI marker.
    expect(framed.rgba[0] == 0xFF && framed.rgba[1] == 0xD8, isFalse);
  });
}
