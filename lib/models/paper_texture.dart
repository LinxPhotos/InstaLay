/// Fine photographic-paper style noise overlays for canvas mattes.
enum PaperTexture {
  none('None', 'Flat color only'),
  fineGrain('Fine Grain', 'Very subtle silver-halide grain'),
  matteFiber('Matte Fiber', 'Soft fiber tooth like matte RC paper'),
  coldPress('Cold Press', 'Slightly coarser art-paper texture'),
  baryta('Baryta', 'Fine gloss-fibre baryta look');

  const PaperTexture(this.label, this.description);

  final String label;
  final String description;

  /// Amplitude of luminance noise (0–1 scale of 255).
  double get amplitude => switch (this) {
        PaperTexture.none => 0,
        PaperTexture.fineGrain => 0.012,
        PaperTexture.matteFiber => 0.018,
        PaperTexture.coldPress => 0.028,
        PaperTexture.baryta => 0.015,
      };

  /// Spatial scale hint (smaller = finer).
  double get scale => switch (this) {
        PaperTexture.none => 1,
        PaperTexture.fineGrain => 1.0,
        PaperTexture.matteFiber => 1.6,
        PaperTexture.coldPress => 2.4,
        PaperTexture.baryta => 1.2,
      };
}
