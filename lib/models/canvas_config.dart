import 'aspect_presets.dart';
import 'color_swatches.dart';
import 'export_codec.dart';
import 'paper_texture.dart';
import 'resample_algorithm.dart';

/// How photos are placed onto the target canvas.
enum FitMode {
  /// Fit entire photo inside canvas (letterbox / pillarbox with border matte).
  contain,
  /// Cover the canvas (may crop).
  cover,
  /// Stretch to fill (distorts).
  fill,
}

/// Layout mode for a project version.
enum LayoutMode {
  /// One canvas per source image (batch frame).
  batch,
  /// SCRL-style horizontal tapestry sliced into carousel frames.
  tapestry,
}

class CanvasConfig {
  const CanvasConfig({
    this.aspect = AspectPreset.portrait45,
    this.borderPx = 40,
    this.swatch = CanvasSwatchCatalog.defaultSwatch,
    this.texture = PaperTexture.none,
    this.fitMode = FitMode.contain,
    this.thumbnailAlgorithm = ResampleAlgorithm.defaultThumbnail,
    this.exportAlgorithm = ResampleAlgorithm.defaultExport,
    this.exportLongEdge = 1440,
    this.layoutMode = LayoutMode.batch,
    this.tapestryGapPx = 0,
    this.codec = const ExportCodecSettings(),
  });

  final AspectPreset aspect;
  final int borderPx;
  final CanvasSwatch swatch;
  final PaperTexture texture;
  final FitMode fitMode;
  final ResampleAlgorithm thumbnailAlgorithm;
  final ResampleAlgorithm exportAlgorithm;
  final int exportLongEdge;
  final LayoutMode layoutMode;
  final int tapestryGapPx;
  final ExportCodecSettings codec;

  CanvasConfig copyWith({
    AspectPreset? aspect,
    int? borderPx,
    CanvasSwatch? swatch,
    PaperTexture? texture,
    FitMode? fitMode,
    ResampleAlgorithm? thumbnailAlgorithm,
    ResampleAlgorithm? exportAlgorithm,
    int? exportLongEdge,
    LayoutMode? layoutMode,
    int? tapestryGapPx,
    ExportCodecSettings? codec,
  }) {
    return CanvasConfig(
      aspect: aspect ?? this.aspect,
      borderPx: borderPx ?? this.borderPx,
      swatch: swatch ?? this.swatch,
      texture: texture ?? this.texture,
      fitMode: fitMode ?? this.fitMode,
      thumbnailAlgorithm: thumbnailAlgorithm ?? this.thumbnailAlgorithm,
      exportAlgorithm: exportAlgorithm ?? this.exportAlgorithm,
      exportLongEdge: exportLongEdge ?? this.exportLongEdge,
      layoutMode: layoutMode ?? this.layoutMode,
      tapestryGapPx: tapestryGapPx ?? this.tapestryGapPx,
      codec: codec ?? this.codec,
    );
  }

  Map<String, dynamic> toJson() => {
        'aspect': aspect.toJson(),
        'borderPx': borderPx,
        'swatch': swatch.toJson(),
        'texture': texture.name,
        'fitMode': fitMode.name,
        'thumbnailAlgorithm': thumbnailAlgorithm.name,
        'exportAlgorithm': exportAlgorithm.name,
        'exportLongEdge': exportLongEdge,
        'layoutMode': layoutMode.name,
        'tapestryGapPx': tapestryGapPx,
        'codec': codec.toJson(),
      };

  factory CanvasConfig.fromJson(Map<String, dynamic> json) {
    return CanvasConfig(
      aspect: AspectPreset.fromJson(
        Map<String, dynamic>.from(json['aspect'] as Map? ?? const {}),
      ),
      borderPx: json['borderPx'] as int? ?? 40,
      swatch: CanvasSwatch.fromJson(
        Map<String, dynamic>.from(json['swatch'] as Map? ?? const {}),
      ),
      texture: PaperTexture.values.firstWhere(
        (t) => t.name == json['texture'],
        orElse: () => PaperTexture.none,
      ),
      fitMode: FitMode.values.firstWhere(
        (f) => f.name == json['fitMode'],
        orElse: () => FitMode.contain,
      ),
      thumbnailAlgorithm: ResampleAlgorithm.values.firstWhere(
        (a) => a.name == json['thumbnailAlgorithm'],
        orElse: () => ResampleAlgorithm.defaultThumbnail,
      ),
      exportAlgorithm: ResampleAlgorithm.values.firstWhere(
        (a) => a.name == json['exportAlgorithm'],
        orElse: () => ResampleAlgorithm.defaultExport,
      ),
      exportLongEdge: json['exportLongEdge'] as int? ?? 1440,
      layoutMode: LayoutMode.values.firstWhere(
        (m) => m.name == json['layoutMode'],
        orElse: () => LayoutMode.batch,
      ),
      tapestryGapPx: json['tapestryGapPx'] as int? ?? 0,
      codec: ExportCodecSettings.fromJson(
        json['codec'] == null
            ? null
            : Map<String, dynamic>.from(json['codec'] as Map),
      ),
    );
  }
}
