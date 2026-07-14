import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/paper_texture.dart';

/// Procedural photographic-paper noise baked into the canvas matte.
abstract final class PaperTextureGenerator {
  static void apply(img.Image canvas, PaperTexture texture, {int seed = 42}) {
    if (texture == PaperTexture.none || texture.amplitude <= 0) return;

    final rnd = math.Random(seed);
    final amp = texture.amplitude * 255;
    final scale = texture.scale;

    // Precompute a small noise tile and tile it for speed.
    final tile = math.max(32, (64 * scale).round());
    final noise = List<double>.generate(
      tile * tile,
      (_) => (rnd.nextDouble() * 2 - 1) * amp,
      growable: false,
    );

    for (var y = 0; y < canvas.height; y++) {
      for (var x = 0; x < canvas.width; x++) {
        final n = noise[(y % tile) * tile + (x % tile)];
        // Soft fiber bias: mix in a second octave for matte/cold-press.
        final n2 = texture == PaperTexture.matteFiber ||
                texture == PaperTexture.coldPress
            ? noise[((y ~/ 2) % tile) * tile + ((x ~/ 2) % tile)] * 0.45
            : 0.0;
        final delta = n + n2;
        final p = canvas.getPixel(x, y);
        canvas.setPixelRgba(
          x,
          y,
          (p.r + delta).round().clamp(0, 255),
          (p.g + delta).round().clamp(0, 255),
          (p.b + delta).round().clamp(0, 255),
          p.a.toInt(),
        );
      }
    }
  }
}
