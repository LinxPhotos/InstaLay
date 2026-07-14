/// Pixel resampling algorithms available for thumbnails and exports.
enum ResampleAlgorithm {
  lanczos3('Lanczos-3', 'High-quality kernel; best for photo downsampling.'),
  lanczos2('Lanczos-2', 'Slightly sharper / faster than Lanczos-3.'),
  cubic('Cubic', 'Smooth bicubic; good general-purpose fallback.'),
  linear('Linear', 'Fast bilinear; softer results.'),
  nearest('Nearest', 'Blocky; useful for pixel-art debugging.');

  const ResampleAlgorithm(this.label, this.description);

  final String label;
  final String description;

  static const ResampleAlgorithm defaultThumbnail = ResampleAlgorithm.lanczos3;
  static const ResampleAlgorithm defaultExport = ResampleAlgorithm.lanczos3;
}
