import 'canvas_config.dart';
import 'project.dart';

/// Result of a photo-border edit (photos + layout config last/sync state).
class PhotoBorderEditResult {
  const PhotoBorderEditResult({
    required this.photos,
    required this.config,
  });

  final List<PhotoItem> photos;
  final CanvasConfig config;
}

/// Keeps per-photo tapestry borders in sync using last-edited values.
abstract final class PhotoBorderSync {
  static const maxBorderPx = 200.0;

  /// Apply a border size and/or color edit to [photoId], optionally fanning
  /// out to every photo when the matching sync flag is on.
  ///
  /// Always updates [CanvasConfig.lastPhotoBorderPx] /
  /// [CanvasConfig.lastPhotoBorderColorArgb] for the fields that changed.
  /// Turning a sync flag **on** immediately fans out from the selected photo
  /// (or the new edit value).
  static PhotoBorderEditResult apply({
    required CanvasConfig config,
    required List<PhotoItem> photos,
    required String photoId,
    double? borderPx,
    int? borderColorArgb,
    bool? syncPhotoBorderPx,
    bool? syncPhotoBorderColor,
  }) {
    PhotoItem? selected;
    for (final p in photos) {
      if (p.id == photoId) {
        selected = p;
        break;
      }
    }
    selected ??= photos.isEmpty ? null : photos.first;

    var nextConfig = config;
    if (syncPhotoBorderPx != null) {
      nextConfig = nextConfig.copyWith(syncPhotoBorderPx: syncPhotoBorderPx);
    }
    if (syncPhotoBorderColor != null) {
      nextConfig =
          nextConfig.copyWith(syncPhotoBorderColor: syncPhotoBorderColor);
    }

    double? nextPx = borderPx;
    if (nextPx != null) {
      nextPx = nextPx.clamp(0.0, maxBorderPx);
      nextConfig = nextConfig.copyWith(lastPhotoBorderPx: nextPx);
    }
    if (borderColorArgb != null) {
      nextConfig =
          nextConfig.copyWith(lastPhotoBorderColorArgb: borderColorArgb);
    }

    final enablePxSync =
        syncPhotoBorderPx == true && !config.syncPhotoBorderPx;
    final enableColorSync =
        syncPhotoBorderColor == true && !config.syncPhotoBorderColor;

    // When enabling sync without a fresh edit, adopt the selected photo's value.
    if (enablePxSync && nextPx == null && selected != null) {
      nextPx = selected.borderPx.clamp(0.0, maxBorderPx);
      nextConfig = nextConfig.copyWith(lastPhotoBorderPx: nextPx);
    }
    if (enableColorSync && borderColorArgb == null && selected != null) {
      borderColorArgb = selected.borderColorArgb;
      nextConfig =
          nextConfig.copyWith(lastPhotoBorderColorArgb: borderColorArgb);
    }

    final applyPxToAll = nextConfig.syncPhotoBorderPx &&
        (nextPx != null || enablePxSync);
    final applyColorToAll = nextConfig.syncPhotoBorderColor &&
        (borderColorArgb != null || enableColorSync);

    final pxValue = nextPx ?? nextConfig.lastPhotoBorderPx;
    final colorValue =
        borderColorArgb ?? nextConfig.lastPhotoBorderColorArgb;

    final out = <PhotoItem>[
      for (final p in photos)
        p.copyWith(
          borderPx: (p.id == photoId && nextPx != null) || applyPxToAll
              ? pxValue
              : null,
          borderColorArgb:
              (p.id == photoId && borderColorArgb != null) || applyColorToAll
                  ? colorValue
                  : null,
        ),
    ];

    return PhotoBorderEditResult(photos: out, config: nextConfig);
  }

  /// Seed a newly placed photo from the layout's last-edited border settings.
  static PhotoItem seed(PhotoItem photo, CanvasConfig config) {
    return photo.copyWith(
      borderPx: config.lastPhotoBorderPx,
      borderColorArgb: config.lastPhotoBorderColorArgb,
    );
  }
}
