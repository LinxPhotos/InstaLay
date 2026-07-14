import 'package:image/image.dart' as img;

/// Output / accepted input image codecs.
enum ExportFormat {
  jpeg('JPEG', 'jpg', 'image/jpeg'),
  jpegXl('JPEG XL', 'jxl', 'image/jxl'),
  png('PNG', 'png', 'image/png'),
  webp('WebP', 'webp', 'image/webp'),
  avif('AVIF', 'avif', 'image/avif');

  const ExportFormat(this.label, this.extension, this.mimeType);

  final String label;
  final String extension;
  final String mimeType;

  static const List<String> pickerExtensions = [
    'jpg',
    'jpeg',
    'jxl',
    'png',
    'webp',
    'avif',
  ];
}

/// JPEG XL encode mode.
enum JxlMode {
  lossy('Lossy (VarDCT)'),
  lossless('Lossless');

  const JxlMode(this.label);
  final String label;
}

/// Tunable export codec settings (persisted on [CanvasConfig]).
class ExportCodecSettings {
  const ExportCodecSettings({
    this.format = ExportFormat.jpeg,
    this.jpegQuality = 92,
    this.jpegChroma = img.JpegChroma.yuv420,
    this.jxlMode = JxlMode.lossy,
    this.jxlQuality = 90,
    this.jxlDistance,
    this.pngLevel = 6,
    this.webpLossless = true,
    this.avifQuality = 80,
    this.avifSpeed = 8,
  });

  final ExportFormat format;

  /// JPEG quality 1–100.
  final int jpegQuality;
  final img.JpegChroma jpegChroma;

  final JxlMode jxlMode;

  /// Convenience 1–100 scale mapped to butteraugli distance when [jxlDistance]
  /// is null. 100 → lossless distance 0.
  final int jxlQuality;

  /// Explicit cjxl-style distance; overrides [jxlQuality] when set.
  /// 0 = lossless visually for lossy path; use [jxlMode.lossless] for bit-exact.
  final double? jxlDistance;

  /// PNG zlib level 0–9.
  final int pngLevel;

  /// Dart `image` WebP encoder is lossless-only; kept for UI clarity.
  final bool webpLossless;

  /// AVIF quality 1–100 (mapped to quantizer range).
  final int avifQuality;

  /// AVIF encode speed 1–10 (higher = faster / larger).
  final int avifSpeed;

  /// Butteraugli distance used for lossy JXL (0 = near-lossless).
  double get effectiveJxlDistance {
    if (jxlMode == JxlMode.lossless) return 0;
    if (jxlDistance != null) return jxlDistance!.clamp(0.0, 15.0);
    final q = jxlQuality.clamp(1, 100);
    if (q >= 100) return 0;
    // Map quality→distance ≈ cjxl: q100→0, q90→1, q70→3, q50→6
    return ((100 - q) / 10.0).clamp(0.0, 15.0);
  }

  ExportCodecSettings copyWith({
    ExportFormat? format,
    int? jpegQuality,
    img.JpegChroma? jpegChroma,
    JxlMode? jxlMode,
    int? jxlQuality,
    double? jxlDistance,
    bool clearJxlDistance = false,
    int? pngLevel,
    bool? webpLossless,
    int? avifQuality,
    int? avifSpeed,
  }) {
    return ExportCodecSettings(
      format: format ?? this.format,
      jpegQuality: jpegQuality ?? this.jpegQuality,
      jpegChroma: jpegChroma ?? this.jpegChroma,
      jxlMode: jxlMode ?? this.jxlMode,
      jxlQuality: jxlQuality ?? this.jxlQuality,
      jxlDistance: clearJxlDistance ? null : (jxlDistance ?? this.jxlDistance),
      pngLevel: pngLevel ?? this.pngLevel,
      webpLossless: webpLossless ?? this.webpLossless,
      avifQuality: avifQuality ?? this.avifQuality,
      avifSpeed: avifSpeed ?? this.avifSpeed,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format.name,
        'jpegQuality': jpegQuality,
        'jpegChroma': jpegChroma.name,
        'jxlMode': jxlMode.name,
        'jxlQuality': jxlQuality,
        'jxlDistance': jxlDistance,
        'pngLevel': pngLevel,
        'webpLossless': webpLossless,
        'avifQuality': avifQuality,
        'avifSpeed': avifSpeed,
      };

  factory ExportCodecSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ExportCodecSettings();
    return ExportCodecSettings(
      format: ExportFormat.values.firstWhere(
        (f) => f.name == json['format'],
        orElse: () => ExportFormat.jpeg,
      ),
      jpegQuality: json['jpegQuality'] as int? ?? 92,
      jpegChroma: img.JpegChroma.values.firstWhere(
        (c) => c.name == json['jpegChroma'],
        orElse: () => img.JpegChroma.yuv420,
      ),
      jxlMode: JxlMode.values.firstWhere(
        (m) => m.name == json['jxlMode'],
        orElse: () => JxlMode.lossy,
      ),
      jxlQuality: json['jxlQuality'] as int? ?? 90,
      jxlDistance: (json['jxlDistance'] as num?)?.toDouble(),
      pngLevel: json['pngLevel'] as int? ?? 6,
      webpLossless: json['webpLossless'] as bool? ?? true,
      avifQuality: json['avifQuality'] as int? ?? 80,
      avifSpeed: json['avifSpeed'] as int? ?? 8,
    );
  }
}
