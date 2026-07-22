import 'package:flutter/painting.dart' show Color, FontWeight;

import 'canvas_config.dart';
import 'instagram_limits.dart';

class PhotoItem {
  const PhotoItem({
    required this.id,
    required this.sourcePath,
    this.fileName,
    this.order = 0,
    this.zIndex = 0,
    this.offsetX = 0,
    this.offsetY = 0,
    this.scale = 1,
    this.rotationDeg = 0,
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 0,
    this.cropBottom = 0,
  });

  final String id;
  final String sourcePath;
  final String? fileName;
  /// Left-to-right layout sequence (auto-layout / sources rail).
  final int order;
  /// Paint / hit-test stacking (higher draws on top). Independent of [order].
  final int zIndex;
  /// Batch: pan from centered fit. Tapestry: top-left of photo on the strip (export px).
  final double offsetX;
  final double offsetY;
  final double scale;
  /// Clockwise rotation in degrees (tapestry / free transform).
  final double rotationDeg;

  /// Normalized source crop insets (0 = full image). Visible span stays ≥ 5%.
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;

  bool get hasCrop =>
      cropLeft > 0.0005 ||
      cropTop > 0.0005 ||
      cropRight > 0.0005 ||
      cropBottom > 0.0005;

  bool get hasCustomTransform =>
      offsetX != 0 ||
      offsetY != 0 ||
      scale != 1 ||
      rotationDeg != 0 ||
      hasCrop;

  double get cropWidthFrac =>
      (1.0 - cropLeft - cropRight).clamp(0.05, 1.0);

  double get cropHeightFrac =>
      (1.0 - cropTop - cropBottom).clamp(0.05, 1.0);

  /// Source pixel rect for the visible crop.
  ({int left, int top, int width, int height}) sourceCropPixels({
    required int sourceWidth,
    required int sourceHeight,
  }) {
    final w = sourceWidth.clamp(1, 1 << 30);
    final h = sourceHeight.clamp(1, 1 << 30);
    final left = (cropLeft * w).round().clamp(0, w - 1);
    final top = (cropTop * h).round().clamp(0, h - 1);
    final right = (w * (1.0 - cropRight)).round().clamp(left + 1, w);
    final bottom = (h * (1.0 - cropBottom)).round().clamp(top + 1, h);
    return (
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
    );
  }

  PhotoItem copyWith({
    String? sourcePath,
    String? fileName,
    int? order,
    int? zIndex,
    double? offsetX,
    double? offsetY,
    double? scale,
    double? rotationDeg,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
  }) {
    return PhotoItem(
      id: id,
      sourcePath: sourcePath ?? this.sourcePath,
      fileName: fileName ?? this.fileName,
      order: order ?? this.order,
      zIndex: zIndex ?? this.zIndex,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      cropLeft: cropLeft ?? this.cropLeft,
      cropTop: cropTop ?? this.cropTop,
      cropRight: cropRight ?? this.cropRight,
      cropBottom: cropBottom ?? this.cropBottom,
    );
  }

  /// Returns a copy with crop insets clamped to a valid visible region.
  PhotoItem withClampedCrop({
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
  }) {
    var l = (cropLeft ?? this.cropLeft).clamp(0.0, 0.95);
    var t = (cropTop ?? this.cropTop).clamp(0.0, 0.95);
    var r = (cropRight ?? this.cropRight).clamp(0.0, 0.95);
    var b = (cropBottom ?? this.cropBottom).clamp(0.0, 0.95);
    if (1.0 - l - r < 0.05) {
      final mid = (l + (1.0 - r)) / 2;
      l = (mid - 0.025).clamp(0.0, 0.95);
      r = (1.0 - (mid + 0.025)).clamp(0.0, 0.95);
    }
    if (1.0 - t - b < 0.05) {
      final mid = (t + (1.0 - b)) / 2;
      t = (mid - 0.025).clamp(0.0, 0.95);
      b = (1.0 - (mid + 0.025)).clamp(0.0, 0.95);
    }
    return copyWith(cropLeft: l, cropTop: t, cropRight: r, cropBottom: b);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourcePath': sourcePath,
        'fileName': fileName,
        'order': order,
        'zIndex': zIndex,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'scale': scale,
        'rotationDeg': rotationDeg,
        'cropLeft': cropLeft,
        'cropTop': cropTop,
        'cropRight': cropRight,
        'cropBottom': cropBottom,
      };

  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as int? ?? 0;
    return PhotoItem(
      id: json['id'] as String,
      sourcePath: json['sourcePath'] as String,
      fileName: json['fileName'] as String?,
      order: order,
      // Legacy projects had no zIndex; preserve prior paint order (== [order]).
      zIndex: json['zIndex'] as int? ?? order,
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
      cropLeft: (json['cropLeft'] as num?)?.toDouble() ?? 0,
      cropTop: (json['cropTop'] as num?)?.toDouble() ?? 0,
      cropRight: (json['cropRight'] as num?)?.toDouble() ?? 0,
      cropBottom: (json['cropBottom'] as num?)?.toDouble() ?? 0,
    ).withClampedCrop();
  }
}

/// Text object on a tapestry strip (parallel to [PhotoItem]).
class TextItem {
  const TextItem({
    required this.id,
    this.text = 'Text',
    this.offsetX = 0,
    this.offsetY = 0,
    this.scale = 1,
    this.rotationDeg = 0,
    this.zIndex = 0,
    this.fontFamily = 'Georgia',
    this.fontSize = 64,
    this.colorArgb = 0xFF000000,
    this.fontWeight = 400,
  });

  final String id;
  final String text;
  /// Top-left of the text box on the strip (export / logical px).
  final double offsetX;
  final double offsetY;
  final double scale;
  final double rotationDeg;
  final int zIndex;
  final String fontFamily;
  /// Base font size before [scale].
  final double fontSize;
  final int colorArgb;
  /// CSS-style weight 100…900 (mapped to [FontWeight]).
  final int fontWeight;

  Color get color => Color(colorArgb);

  FontWeight get flutterFontWeight {
    return switch ((fontWeight / 100).round().clamp(1, 9)) {
      1 => FontWeight.w100,
      2 => FontWeight.w200,
      3 => FontWeight.w300,
      4 => FontWeight.w400,
      5 => FontWeight.w500,
      6 => FontWeight.w600,
      7 => FontWeight.w700,
      8 => FontWeight.w800,
      _ => FontWeight.w900,
    };
  }

  double get effectiveFontSize =>
      (fontSize * scale).clamp(4.0, 2000.0);

  TextItem copyWith({
    String? text,
    double? offsetX,
    double? offsetY,
    double? scale,
    double? rotationDeg,
    int? zIndex,
    String? fontFamily,
    double? fontSize,
    int? colorArgb,
    int? fontWeight,
  }) {
    return TextItem(
      id: id,
      text: text ?? this.text,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      zIndex: zIndex ?? this.zIndex,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      colorArgb: colorArgb ?? this.colorArgb,
      fontWeight: fontWeight ?? this.fontWeight,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'scale': scale,
        'rotationDeg': rotationDeg,
        'zIndex': zIndex,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'colorArgb': colorArgb,
        'fontWeight': fontWeight,
      };

  factory TextItem.fromJson(Map<String, dynamic> json) {
    return TextItem(
      id: json['id'] as String,
      text: json['text'] as String? ?? 'Text',
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
      zIndex: json['zIndex'] as int? ?? 0,
      fontFamily: json['fontFamily'] as String? ?? 'Georgia',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 64,
      colorArgb: json['colorArgb'] as int? ?? 0xFF000000,
      fontWeight: json['fontWeight'] as int? ?? 400,
    );
  }
}

enum TapestryLayerKind { photo, text }

/// One entry in the unified photo+text stacking list.
class TapestryLayerRef {
  const TapestryLayerRef({
    required this.kind,
    required this.id,
    required this.zIndex,
  });

  final TapestryLayerKind kind;
  final String id;
  final int zIndex;

  bool get isPhoto => kind == TapestryLayerKind.photo;
  bool get isText => kind == TapestryLayerKind.text;
}

/// Result of a unified z-order mutation.
class TapestryLayers {
  const TapestryLayers({required this.photos, required this.texts});

  final List<PhotoItem> photos;
  final List<TextItem> texts;
}

/// Paint / hit-test stacking helpers. Layer browser is LTR: left = back, right = front.
class PhotoZOrder {
  const PhotoZOrder._();

  static int compare(PhotoItem a, PhotoItem b) {
    final c = a.zIndex.compareTo(b.zIndex);
    return c != 0 ? c : a.order.compareTo(b.order);
  }

  static List<PhotoItem> sorted(List<PhotoItem> photos) =>
      [...photos]..sort(compare);

  static List<PhotoItem> withDenseIndices(List<PhotoItem> zSorted) => [
        for (var i = 0; i < zSorted.length; i++)
          zSorted[i].copyWith(zIndex: i),
      ];

  /// Move [id] one step toward the front (higher z).
  static List<PhotoItem> raise(List<PhotoItem> photos, String id) {
    final sorted = PhotoZOrder.sorted(photos);
    final i = sorted.indexWhere((p) => p.id == id);
    if (i < 0 || i >= sorted.length - 1) return photos;
    final item = sorted.removeAt(i);
    sorted.insert(i + 1, item);
    return withDenseIndices(sorted);
  }

  /// Move [id] one step toward the back (lower z).
  static List<PhotoItem> lower(List<PhotoItem> photos, String id) {
    final sorted = PhotoZOrder.sorted(photos);
    final i = sorted.indexWhere((p) => p.id == id);
    if (i <= 0) return photos;
    final item = sorted.removeAt(i);
    sorted.insert(i - 1, item);
    return withDenseIndices(sorted);
  }

  static List<PhotoItem> bringToFront(List<PhotoItem> photos, String id) {
    final sorted = PhotoZOrder.sorted(photos);
    final i = sorted.indexWhere((p) => p.id == id);
    if (i < 0 || i == sorted.length - 1) return photos;
    final item = sorted.removeAt(i);
    sorted.add(item);
    return withDenseIndices(sorted);
  }

  static List<PhotoItem> sendToBack(List<PhotoItem> photos, String id) {
    final sorted = PhotoZOrder.sorted(photos);
    final i = sorted.indexWhere((p) => p.id == id);
    if (i <= 0) return photos;
    final item = sorted.removeAt(i);
    sorted.insert(0, item);
    return withDenseIndices(sorted);
  }

  /// Reorder within a z-sorted list (layer browser drag).
  static List<PhotoItem> reorder(
    List<PhotoItem> photos,
    int oldIndex,
    int newIndex,
  ) {
    final sorted = PhotoZOrder.sorted(photos);
    if (oldIndex < 0 || oldIndex >= sorted.length) return photos;
    var dest = newIndex;
    if (dest > oldIndex) dest -= 1;
    if (dest < 0 || dest >= sorted.length) return photos;
    final item = sorted.removeAt(oldIndex);
    sorted.insert(dest, item);
    return withDenseIndices(sorted);
  }
}

/// Unified photo + text stacking (shared zIndex space).
class TapestryLayerOrder {
  const TapestryLayerOrder._();

  static int nextZIndex(List<PhotoItem> photos, List<TextItem> texts) {
    var max = -1;
    for (final p in photos) {
      if (p.zIndex > max) max = p.zIndex;
    }
    for (final t in texts) {
      if (t.zIndex > max) max = t.zIndex;
    }
    return max + 1;
  }

  static List<TapestryLayerRef> sorted(
    List<PhotoItem> photos,
    List<TextItem> texts,
  ) {
    final layers = <TapestryLayerRef>[
      for (final p in photos)
        TapestryLayerRef(
          kind: TapestryLayerKind.photo,
          id: p.id,
          zIndex: p.zIndex,
        ),
      for (final t in texts)
        TapestryLayerRef(
          kind: TapestryLayerKind.text,
          id: t.id,
          zIndex: t.zIndex,
        ),
    ]..sort((a, b) {
        final c = a.zIndex.compareTo(b.zIndex);
        if (c != 0) return c;
        // Stable tie-break: photos before texts at equal z, then id.
        if (a.kind != b.kind) {
          return a.kind == TapestryLayerKind.photo ? -1 : 1;
        }
        return a.id.compareTo(b.id);
      });
    return layers;
  }

  static TapestryLayers withDenseIndices(
    List<PhotoItem> photos,
    List<TextItem> texts,
    List<TapestryLayerRef> zSorted,
  ) {
    final photoById = {for (final p in photos) p.id: p};
    final textById = {for (final t in texts) t.id: t};
    final nextPhotos = <PhotoItem>[];
    final nextTexts = <TextItem>[];
    for (var i = 0; i < zSorted.length; i++) {
      final layer = zSorted[i];
      if (layer.isPhoto) {
        final p = photoById[layer.id];
        if (p != null) nextPhotos.add(p.copyWith(zIndex: i));
      } else {
        final t = textById[layer.id];
        if (t != null) nextTexts.add(t.copyWith(zIndex: i));
      }
    }
    // Preserve any orphans (should not happen).
    for (final p in photos) {
      if (!nextPhotos.any((x) => x.id == p.id)) nextPhotos.add(p);
    }
    for (final t in texts) {
      if (!nextTexts.any((x) => x.id == t.id)) nextTexts.add(t);
    }
    return TapestryLayers(photos: nextPhotos, texts: nextTexts);
  }

  static TapestryLayers raise(
    List<PhotoItem> photos,
    List<TextItem> texts,
    String id,
  ) {
    final sorted = TapestryLayerOrder.sorted(photos, texts);
    final i = sorted.indexWhere((l) => l.id == id);
    if (i < 0 || i >= sorted.length - 1) {
      return TapestryLayers(photos: photos, texts: texts);
    }
    final item = sorted.removeAt(i);
    sorted.insert(i + 1, item);
    return withDenseIndices(photos, texts, sorted);
  }

  static TapestryLayers lower(
    List<PhotoItem> photos,
    List<TextItem> texts,
    String id,
  ) {
    final sorted = TapestryLayerOrder.sorted(photos, texts);
    final i = sorted.indexWhere((l) => l.id == id);
    if (i <= 0) return TapestryLayers(photos: photos, texts: texts);
    final item = sorted.removeAt(i);
    sorted.insert(i - 1, item);
    return withDenseIndices(photos, texts, sorted);
  }

  static TapestryLayers bringToFront(
    List<PhotoItem> photos,
    List<TextItem> texts,
    String id,
  ) {
    final sorted = TapestryLayerOrder.sorted(photos, texts);
    final i = sorted.indexWhere((l) => l.id == id);
    if (i < 0 || i == sorted.length - 1) {
      return TapestryLayers(photos: photos, texts: texts);
    }
    final item = sorted.removeAt(i);
    sorted.add(item);
    return withDenseIndices(photos, texts, sorted);
  }

  static TapestryLayers sendToBack(
    List<PhotoItem> photos,
    List<TextItem> texts,
    String id,
  ) {
    final sorted = TapestryLayerOrder.sorted(photos, texts);
    final i = sorted.indexWhere((l) => l.id == id);
    if (i <= 0) return TapestryLayers(photos: photos, texts: texts);
    final item = sorted.removeAt(i);
    sorted.insert(0, item);
    return withDenseIndices(photos, texts, sorted);
  }

  static TapestryLayers reorder(
    List<PhotoItem> photos,
    List<TextItem> texts,
    int oldIndex,
    int newIndex,
  ) {
    final sorted = TapestryLayerOrder.sorted(photos, texts);
    if (oldIndex < 0 || oldIndex >= sorted.length) {
      return TapestryLayers(photos: photos, texts: texts);
    }
    // [newIndex] is already adjusted for the removed item (onReorderItem).
    if (newIndex < 0 || newIndex >= sorted.length) {
      return TapestryLayers(photos: photos, texts: texts);
    }
    final item = sorted.removeAt(oldIndex);
    sorted.insert(newIndex, item);
    return withDenseIndices(photos, texts, sorted);
  }
}

/// One canvas layout inside a project version (batch or tapestry).
class LayoutCanvas {
  const LayoutCanvas({
    required this.id,
    required this.name,
    required this.config,
    required this.photos,
    this.texts = const [],
    this.previewHeight = 280,
    this.tapestrySlideCount = 1,
  });

  final String id;
  final String name;
  final CanvasConfig config;
  final List<PhotoItem> photos;
  /// Tapestry text objects (ignored for batch layouts).
  final List<TextItem> texts;
  /// Vertical size of this layout's preview cell in the workspace.
  final double previewHeight;
  /// Explicit carousel frame count for tapestry (1…[InstagramLimits.maxCarouselSlides]).
  final int tapestrySlideCount;

  int get slideCount => InstagramLimits.clampSlideCount(tapestrySlideCount);

  bool get isTapestry => config.layoutMode == LayoutMode.tapestry;

  LayoutCanvas copyWith({
    String? name,
    CanvasConfig? config,
    List<PhotoItem>? photos,
    List<TextItem>? texts,
    double? previewHeight,
    int? tapestrySlideCount,
  }) {
    return LayoutCanvas(
      id: id,
      name: name ?? this.name,
      config: config ?? this.config,
      photos: photos ?? this.photos,
      texts: texts ?? this.texts,
      previewHeight: previewHeight ?? this.previewHeight,
      tapestrySlideCount: tapestrySlideCount ?? this.tapestrySlideCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'config': config.toJson(),
        'photos': photos.map((p) => p.toJson()).toList(),
        'texts': texts.map((t) => t.toJson()).toList(),
        'previewHeight': previewHeight,
        'tapestrySlideCount': tapestrySlideCount,
      };

  factory LayoutCanvas.fromJson(Map<String, dynamic> json) {
    return LayoutCanvas(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Layout',
      config: CanvasConfig.fromJson(
        Map<String, dynamic>.from(json['config'] as Map? ?? const {}),
      ),
      photos: (json['photos'] as List? ?? const [])
          .map((e) => PhotoItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      // Legacy projects had no texts list.
      texts: (json['texts'] as List? ?? const [])
          .map((e) => TextItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      previewHeight: (json['previewHeight'] as num?)?.toDouble() ?? 280,
      tapestrySlideCount: InstagramLimits.clampSlideCount(
        json['tapestrySlideCount'] as int? ?? 1,
      ),
    );
  }

  /// Migrate a pre-layouts version payload into a single canvas.
  factory LayoutCanvas.fromLegacy({
    required String id,
    required CanvasConfig config,
    required List<PhotoItem> photos,
  }) {
    final slides = config.layoutMode == LayoutMode.tapestry
        ? InstagramLimits.clampSlideCount(
            photos.isEmpty ? 1 : photos.length,
          )
        : 1;
    return LayoutCanvas(
      id: id,
      name: config.layoutMode == LayoutMode.tapestry ? 'Tapestry' : 'Batch',
      config: config,
      photos: photos,
      tapestrySlideCount: slides,
    );
  }
}

/// A frozen or editable snapshot of a project (may contain multiple layouts).
class ProjectVersion {
  const ProjectVersion({
    required this.id,
    required this.versionNumber,
    required this.layouts,
    required this.createdAt,
    this.activeLayoutId,
    this.label,
    this.frozen = false,
    this.postedToInstagramAt,
    this.previewThumbPath,
    this.exportPaths = const [],
  });

  final String id;
  final int versionNumber;
  final String? label;
  final List<LayoutCanvas> layouts;
  final String? activeLayoutId;
  final DateTime createdAt;
  final bool frozen;
  final DateTime? postedToInstagramAt;
  final String? previewThumbPath;
  final List<String> exportPaths;

  bool get isPosted => postedToInstagramAt != null;

  LayoutCanvas? get activeLayout {
    if (layouts.isEmpty) return null;
    if (activeLayoutId != null) {
      for (final layout in layouts) {
        if (layout.id == activeLayoutId) return layout;
      }
    }
    return layouts.first;
  }

  /// Layout used for home-list identity thumbs: active if it has photos,
  /// otherwise the first layout that has photos (else active/first).
  LayoutCanvas? get identityLayout {
    final active = activeLayout;
    if (active != null && active.photos.isNotEmpty) return active;
    for (final layout in layouts) {
      if (layout.photos.isNotEmpty) return layout;
    }
    return active;
  }

  /// Convenience: active layout config (empty default if none).
  CanvasConfig get config => activeLayout?.config ?? const CanvasConfig();

  /// Convenience: active layout photos.
  List<PhotoItem> get photos => activeLayout?.photos ?? const [];

  /// All source photos across every layout (deduped by id).
  List<PhotoItem> get allPhotos {
    final seen = <String>{};
    final out = <PhotoItem>[];
    for (final layout in layouts) {
      for (final photo in layout.photos) {
        if (seen.add(photo.id)) out.add(photo);
      }
    }
    return out;
  }

  ProjectVersion copyWith({
    String? label,
    List<LayoutCanvas>? layouts,
    String? activeLayoutId,
    bool? frozen,
    DateTime? postedToInstagramAt,
    String? previewThumbPath,
    List<String>? exportPaths,
  }) {
    return ProjectVersion(
      id: id,
      versionNumber: versionNumber,
      label: label ?? this.label,
      layouts: layouts ?? this.layouts,
      activeLayoutId: activeLayoutId ?? this.activeLayoutId,
      createdAt: createdAt,
      frozen: frozen ?? this.frozen,
      postedToInstagramAt: postedToInstagramAt ?? this.postedToInstagramAt,
      previewThumbPath: previewThumbPath ?? this.previewThumbPath,
      exportPaths: exportPaths ?? this.exportPaths,
    );
  }

  /// Replace the active layout (or no-op if missing).
  ProjectVersion mapActiveLayout(LayoutCanvas Function(LayoutCanvas) mutate) {
    final active = activeLayout;
    if (active == null) return this;
    final next = mutate(active);
    return copyWith(
      layouts: [
        for (final layout in layouts) layout.id == next.id ? next : layout,
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'versionNumber': versionNumber,
        'label': label,
        'layouts': layouts.map((e) => e.toJson()).toList(),
        'activeLayoutId': activeLayoutId,
        'createdAt': createdAt.toIso8601String(),
        'frozen': frozen,
        'postedToInstagramAt': postedToInstagramAt?.toIso8601String(),
        'previewThumbPath': previewThumbPath,
        'exportPaths': exportPaths,
      };

  factory ProjectVersion.fromJson(Map<String, dynamic> json) {
    final rawLayouts = json['layouts'] as List?;
    final List<LayoutCanvas> layouts;
    String? activeLayoutId = json['activeLayoutId'] as String?;

    if (rawLayouts != null && rawLayouts.isNotEmpty) {
      layouts = rawLayouts
          .map(
            (e) => LayoutCanvas.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } else {
      // Legacy: single config + photos on the version.
      final legacyId = '${json['id'] as String? ?? 'legacy'}-layout';
      layouts = [
        LayoutCanvas.fromLegacy(
          id: legacyId,
          config: CanvasConfig.fromJson(
            Map<String, dynamic>.from(json['config'] as Map? ?? const {}),
          ),
          photos: (json['photos'] as List? ?? const [])
              .map(
                (e) => PhotoItem.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
        ),
      ];
      activeLayoutId = legacyId;
    }

    return ProjectVersion(
      id: json['id'] as String,
      versionNumber: json['versionNumber'] as int? ?? 1,
      label: json['label'] as String?,
      layouts: layouts,
      activeLayoutId: activeLayoutId,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      frozen: json['frozen'] as bool? ?? false,
      postedToInstagramAt: json['postedToInstagramAt'] != null
          ? DateTime.tryParse(json['postedToInstagramAt'] as String)
          : null,
      previewThumbPath: json['previewThumbPath'] as String?,
      exportPaths: (json['exportPaths'] as List? ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.versions,
    this.activeVersionId,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProjectVersion> versions;
  final String? activeVersionId;

  ProjectVersion? get activeVersion {
    if (versions.isEmpty) return null;
    if (activeVersionId != null) {
      for (final v in versions) {
        if (v.id == activeVersionId) return v;
      }
    }
    return versions.last;
  }

  Project copyWith({
    String? name,
    DateTime? updatedAt,
    List<ProjectVersion>? versions,
    String? activeVersionId,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      versions: versions ?? this.versions,
      activeVersionId: activeVersionId ?? this.activeVersionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'versions': versions.map((v) => v.toJson()).toList(),
        'activeVersionId': activeVersionId,
      };

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      versions: (json['versions'] as List? ?? const [])
          .map(
            (e) => ProjectVersion.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      activeVersionId: json['activeVersionId'] as String?,
    );
  }
}
