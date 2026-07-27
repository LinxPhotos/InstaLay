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
    this.tapestryTileAspect,
    this.tapestryExportWholeStrip = false,
    this.syncPhotoBorderPx = true,
    this.syncPhotoBorderColor = true,
    this.lastPhotoBorderPx = 0,
    this.lastPhotoBorderColorArgb = 0xFFFFFFFF,
    this.codec = const ExportCodecSettings(),
  });

  final AspectPreset aspect;
  final int borderPx;
  final CanvasSwatch swatch;
  final PaperTexture texture;
  final FitMode fitMode;
  final ResampleAlgorithm thumbnailAlgorithm;
  final ResampleAlgorithm exportAlgorithm;
  /// Export canvas height in pixels (JSON key kept as `exportLongEdge`).
  final int exportLongEdge;
  final LayoutMode layoutMode;
  final int tapestryGapPx;
  /// When set, each tapestry photo tile uses this aspect (height-fit).
  /// Null = native photo aspect (SCRL default).
  final AspectPreset? tapestryTileAspect;
  /// When true, export the full panorama as one image instead of carousel slices.
  final bool tapestryExportWholeStrip;
  /// Fan out photo border size edits to every photo in the layout.
  final bool syncPhotoBorderPx;
  /// Fan out photo border color edits to every photo in the layout.
  final bool syncPhotoBorderColor;
  /// Last edited photo border size (seeds new photos; used when enabling sync).
  final double lastPhotoBorderPx;
  final int lastPhotoBorderColorArgb;
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
    AspectPreset? tapestryTileAspect,
    bool clearTapestryTileAspect = false,
    bool? tapestryExportWholeStrip,
    bool? syncPhotoBorderPx,
    bool? syncPhotoBorderColor,
    double? lastPhotoBorderPx,
    int? lastPhotoBorderColorArgb,
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
      tapestryTileAspect: clearTapestryTileAspect
          ? null
          : (tapestryTileAspect ?? this.tapestryTileAspect),
      tapestryExportWholeStrip:
          tapestryExportWholeStrip ?? this.tapestryExportWholeStrip,
      syncPhotoBorderPx: syncPhotoBorderPx ?? this.syncPhotoBorderPx,
      syncPhotoBorderColor: syncPhotoBorderColor ?? this.syncPhotoBorderColor,
      lastPhotoBorderPx: lastPhotoBorderPx ?? this.lastPhotoBorderPx,
      lastPhotoBorderColorArgb:
          lastPhotoBorderColorArgb ?? this.lastPhotoBorderColorArgb,
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
        if (tapestryTileAspect != null)
          'tapestryTileAspect': tapestryTileAspect!.toJson(),
        'tapestryExportWholeStrip': tapestryExportWholeStrip,
        'syncPhotoBorderPx': syncPhotoBorderPx,
        'syncPhotoBorderColor': syncPhotoBorderColor,
        'lastPhotoBorderPx': lastPhotoBorderPx,
        'lastPhotoBorderColorArgb': lastPhotoBorderColorArgb,
        'codec': codec.toJson(),
      };

  factory CanvasConfig.fromJson(Map<String, dynamic> json) {
    AspectPreset? tileAspect;
    final rawTile = json['tapestryTileAspect'];
    if (rawTile is Map) {
      tileAspect = AspectPreset.fromJson(Map<String, dynamic>.from(rawTile));
    }
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
      tapestryTileAspect: tileAspect,
      tapestryExportWholeStrip:
          json['tapestryExportWholeStrip'] as bool? ?? false,
      syncPhotoBorderPx: json['syncPhotoBorderPx'] as bool? ?? true,
      syncPhotoBorderColor: json['syncPhotoBorderColor'] as bool? ?? true,
      lastPhotoBorderPx:
          (json['lastPhotoBorderPx'] as num?)?.toDouble() ?? 0,
      lastPhotoBorderColorArgb:
          json['lastPhotoBorderColorArgb'] as int? ?? 0xFFFFFFFF,
      codec: ExportCodecSettings.fromJson(
        json['codec'] == null
            ? null
            : Map<String, dynamic>.from(json['codec'] as Map),
      ),
    );
  }
}
