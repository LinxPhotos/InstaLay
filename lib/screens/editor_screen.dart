import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/canvas_config.dart';
import '../models/export_codec.dart';
import '../models/instagram_limits.dart';
import '../models/project.dart';
import '../providers/app_providers.dart';
import '../services/export_service.dart';
import '../services/image_codec_service.dart';
import '../services/linx_client.dart';
import '../theme/app_theme.dart';
import '../widgets/canvas_controls.dart';
import '../widgets/canvas_workspace.dart';
import '../widgets/export_destination_dialog.dart';
import '../widgets/export_settings_dialog.dart';
import '../widgets/image_thumbnail_grid.dart';
import '../widgets/interactive_tapestry_canvas.dart';
import '../widgets/linx_photo_picker_dialog.dart';
import '../widgets/live_canvas.dart';
import '../widgets/theme_mode_button.dart';
import '../widgets/ui_scale_buttons.dart';
import 'templates_screen.dart';
import 'version_browser_screen.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    required this.projectId,
    this.openShareOnLoad = false,
    this.initialLinxAlbumId,
  });

  final String projectId;
  final bool openShareOnLoad;
  /// When set (deep link), open the Linx picker scoped to this album after load.
  final String? initialLinxAlbumId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  Project? _project;
  String? _selectedPhotoId;
  String? _selectedTextId;
  /// Decoded source bitmaps for the live Skia art canvas (not framed exports).
  final Map<String, ui.Image> _sourceImages = {};
  final Map<String, TapestryCanvasController> _tapestryControllers = {};
  bool _sourcesLoading = false;
  bool _busy = false;
  int _sourceGeneration = 0;
  Timer? _configDebounce;
  Timer? _thumbDebounce;
  final _uuid = const Uuid();

  static const double _photosRailWidth = 280;
  static const double _settingsRailWidth = 300;
  static const double _minCenterWidth = 240;

  /// Shrink side rails when the window is narrower than rails + center
  /// (common after restore-from-maximized) so the main Row does not overflow.
  static ({double photos, double settings}) _railWidthsFor(double maxWidth) {
    var photos = _photosRailWidth;
    var settings = _settingsRailWidth;
    final dividers = 2.0;
    final budget = maxWidth - _minCenterWidth - dividers;
    if (budget < photos + settings && budget > 0) {
      final factor = budget / (photos + settings);
      photos = (photos * factor).clamp(140.0, _photosRailWidth);
      settings = (settings * factor).clamp(160.0, _settingsRailWidth);
    }
    return (photos: photos, settings: settings);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _configDebounce?.cancel();
    _thumbDebounce?.cancel();
    _disposeAllImages();
    super.dispose();
  }

  void _disposeAllImages() {
    for (final image in _sourceImages.values) {
      image.dispose();
    }
    _sourceImages.clear();
  }

  Future<void> _load() async {
    final all = await ref.read(projectStoreProvider).loadAll();
    Project? project;
    for (final item in all) {
      if (item.id == widget.projectId) {
        project = item;
        break;
      }
    }
    if (!mounted) return;
    setState(() => _project = project);
    if (project == null) return;
    final photos = project.activeVersion?.photos ?? const [];
    if (photos.isNotEmpty) {
      _selectedPhotoId = photos.first.id;
    }
    await _loadSourceImages();
    if (widget.openShareOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _exportAndShare());
    }
    if (widget.initialLinxAlbumId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addFromLinx(albumId: widget.initialLinxAlbumId);
      });
    }
  }

  ProjectVersion? get _version => _project?.activeVersion;
  LayoutCanvas? get _layout => _version?.activeLayout;

  Future<void> _persist(Project Function(Project p) mutate) async {
    final current = _project;
    if (current == null) return;
    try {
      final saved = await ref.read(projectStoreProvider).save(mutate(current));
      await ref.read(projectsProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _project = saved);
    } catch (e, st) {
      debugPrint('Editor persist failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save project: $e')),
      );
    }
  }

  Future<void> _renameProject() async {
    final project = _project;
    if (project == null) return;
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename project'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
          style: Theme.of(ctx).textTheme.bodyMedium,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == project.name) return;
    await _persist((p) => p.copyWith(name: name));
  }

  Future<void> _updateLayout(LayoutCanvas layout) async {
    final version = _version;
    if (version == null || version.frozen) return;
    setState(() {
      final versions = _project!.versions
          .map(
            (v) => v.id == version.id
                ? v.copyWith(
                    layouts: [
                      for (final l in v.layouts) l.id == layout.id ? layout : l,
                    ],
                  )
                : v,
          )
          .toList();
      _project = _project!.copyWith(versions: versions);
    });
    _configDebounce?.cancel();
    _configDebounce = Timer(const Duration(milliseconds: 180), () async {
      await _persist((p) {
        final versions = p.versions
            .map(
              (v) => v.id == version.id
                  ? v.copyWith(
                      layouts: [
                        for (final l in v.layouts)
                          l.id == layout.id ? layout : l,
                      ],
                    )
                  : v,
            )
            .toList();
        return p.copyWith(versions: versions);
      });
      _scheduleHomeThumbRefresh();
    });
  }

  Future<void> _updateConfig(CanvasConfig config) async {
    final layout = _layout;
    if (layout == null) return;
    await _updateLayout(layout.copyWith(config: config));
  }

  Future<void> _applyZOrder(
    TapestryLayers Function(
      List<PhotoItem> photos,
      List<TextItem> texts,
      String id,
    ) transform,
  ) async {
    final layout = _layout;
    final id = _selectedPhotoId ?? _selectedTextId;
    if (layout == null || id == null || _version?.frozen == true) return;
    final next = transform(layout.photos, layout.texts, id);
    if (identical(next.photos, layout.photos) &&
        identical(next.texts, layout.texts)) {
      return;
    }
    await _updateLayout(
      layout.copyWith(photos: next.photos, texts: next.texts),
    );
  }

  Future<void> _reorderLayers(int oldIndex, int newIndex) async {
    final layout = _layout;
    if (layout == null || _version?.frozen == true) return;
    final next = TapestryLayerOrder.reorder(
      layout.photos,
      layout.texts,
      oldIndex,
      newIndex,
    );
    if (identical(next.photos, layout.photos) &&
        identical(next.texts, layout.texts)) {
      return;
    }
    await _updateLayout(
      layout.copyWith(photos: next.photos, texts: next.texts),
    );
  }

  Future<void> _updateSelectedText(TextItem text) async {
    final layout = _layout;
    if (layout == null || _version?.frozen == true) return;
    await _updateLayout(
      layout.copyWith(
        texts: [
          for (final t in layout.texts) t.id == text.id ? text : t,
        ],
      ),
    );
  }

  void _selectPhoto(String? id) {
    setState(() {
      _selectedPhotoId = id;
      if (id != null) _selectedTextId = null;
    });
  }

  void _selectText(String? id) {
    setState(() {
      _selectedTextId = id;
      if (id != null) _selectedPhotoId = null;
    });
  }

  void _selectLayer(TapestryLayerRef layer) {
    if (layer.isPhoto) {
      _selectPhoto(layer.id);
    } else {
      _selectText(layer.id);
    }
  }

  Future<void> _selectLayout(String layoutId) async {
    final version = _version;
    if (version == null) return;
    setState(() {
      final versions = _project!.versions
          .map(
            (v) => v.id == version.id
                ? v.copyWith(activeLayoutId: layoutId)
                : v,
          )
          .toList();
      _project = _project!.copyWith(versions: versions);
    });
    await _persist((p) {
      final versions = p.versions
          .map(
            (v) =>
                v.id == version.id ? v.copyWith(activeLayoutId: layoutId) : v,
          )
          .toList();
      return p.copyWith(versions: versions);
    });
  }

  Future<void> _addLayout() async {
    final version = _version;
    if (version == null || version.frozen) return;

    final mode = await showDialog<LayoutMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add layout'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, LayoutMode.batch),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.grid_view_outlined),
              title: Text('Batch'),
              subtitle: Text('One framed canvas per photo'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, LayoutMode.tapestry),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.view_carousel_outlined),
              title: Text('Tapestry'),
              subtitle: Text('Stitch photos into carousel slides'),
            ),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;

    final id = _uuid.v4();
    final batchN =
        version.layouts.where((l) => !l.isTapestry).length + 1;
    final tapestryN =
        version.layouts.where((l) => l.isTapestry).length + 1;
    final base = version.activeLayout?.config ?? const CanvasConfig();
    final layout = LayoutCanvas(
      id: id,
      name: mode == LayoutMode.tapestry ? 'Tapestry $tapestryN' : 'Batch $batchN',
      config: base.copyWith(layoutMode: mode),
      photos: const [],
      tapestrySlideCount: 1,
    );
    final next = version.copyWith(
      layouts: [...version.layouts, layout],
      activeLayoutId: id,
    );
    await _persist((p) {
      final versions =
          p.versions.map((v) => v.id == next.id ? next : v).toList();
      return p.copyWith(versions: versions);
    });
  }

  Future<void> _deleteLayout(String layoutId) async {
    final version = _version;
    if (version == null || version.frozen || version.layouts.length <= 1) {
      return;
    }
    final remaining =
        version.layouts.where((l) => l.id != layoutId).toList();
    final activeId = version.activeLayoutId == layoutId
        ? remaining.first.id
        : version.activeLayoutId;
    await _persist((p) {
      final versions = p.versions
          .map(
            (v) => v.id == version.id
                ? v.copyWith(layouts: remaining, activeLayoutId: activeId)
                : v,
          )
          .toList();
      return p.copyWith(versions: versions);
    });
    _tapestryControllers.remove(layoutId);
  }

  Future<void> _addPhotos() async {
    final version = _version;
    final layout = _layout;
    if (version == null || layout == null || version.frozen) return;

    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ExportFormat.pickerExtensions,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _busy = true);
    try {
      final media = await ref.read(projectStoreProvider).mediaDir(_project!.id);
      final photos = [...layout.photos];
      final addedPaths = <String>[];
      var order = photos.length;
      final room = layout.isTapestry
          ? InstagramLimits.maxCarouselSlides - photos.length
          : 1 << 20;
      if (layout.isTapestry && room <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Instagram allows at most '
                '${InstagramLimits.maxCarouselSlides} photos per tapestry.',
              ),
            ),
          );
        }
        return;
      }
      var added = 0;
      for (final file in result.files) {
        if (added >= room) break;
        final path = file.path;
        if (path == null) continue;
        final destName = '${_uuid.v4()}${p.extension(path)}';
        final dest = p.join(media.path, destName);
        await File(path).copy(dest);
        addedPaths.add(dest);
        photos.add(
          PhotoItem(
            id: _uuid.v4(),
            sourcePath: dest,
            fileName: file.name,
            order: order,
            zIndex: TapestryLayerOrder.nextZIndex(photos, layout.texts),
          ),
        );
        order++;
        added++;
      }
      var slideCount = layout.tapestrySlideCount;
      if (layout.isTapestry) {
        slideCount = _contentSlideCount(photos, layout.config, slideCount);
      }
      await _updateLayout(
        layout.copyWith(photos: photos, tapestrySlideCount: slideCount),
      );
      _warmSourceBitmaps(addedPaths);
      _selectedPhotoId ??= photos.isEmpty ? null : photos.last.id;
      await _loadSourceImages();
      if (layout.isTapestry) await _ensureContentSlideCount();
      if (layout.isTapestry &&
          result.files.length > added &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added $added photo${added == 1 ? '' : 's'} '
              '(Instagram max ${InstagramLimits.maxCarouselSlides}).',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFromLinx({String? albumId}) async {
    final version = _version;
    final layout = _layout;
    if (version == null || layout == null || version.frozen) return;

    final auth = await ref.read(linxAuthProvider.future);
    if (!mounted) return;
    final picked = await showLinxPhotoPickerDialog(
      context,
      auth: auth,
      initialAlbumId: albumId ?? widget.initialLinxAlbumId,
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final client = LinxClient(auth);
      final media = await ref.read(projectStoreProvider).mediaDir(_project!.id);
      final photos = [...layout.photos];
      final addedPaths = <String>[];
      var order = photos.length;
      final room = layout.isTapestry
          ? InstagramLimits.maxCarouselSlides - photos.length
          : 1 << 20;
      if (layout.isTapestry && room <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Instagram allows at most '
                '${InstagramLimits.maxCarouselSlides} photos per tapestry.',
              ),
            ),
          );
        }
        return;
      }
      var added = 0;
      for (final variant in picked) {
        if (added >= room) break;
        final bytes = await client.downloadVariant(variant);
        final ext = p.extension(variant.fileNameHint);
        final destName = '${_uuid.v4()}${ext.isEmpty ? '.jpg' : ext}';
        final dest = p.join(media.path, destName);
        await File(dest).writeAsBytes(bytes, flush: true);
        addedPaths.add(dest);
        photos.add(
          PhotoItem(
            id: _uuid.v4(),
            sourcePath: dest,
            fileName: variant.fileNameHint,
            order: order,
            zIndex: TapestryLayerOrder.nextZIndex(photos, layout.texts),
          ),
        );
        order++;
        added++;
      }
      var slideCount = layout.tapestrySlideCount;
      if (layout.isTapestry) {
        slideCount = _contentSlideCount(photos, layout.config, slideCount);
      }
      await _updateLayout(
        layout.copyWith(photos: photos, tapestrySlideCount: slideCount),
      );
      _warmSourceBitmaps(addedPaths);
      _selectedPhotoId ??= photos.isEmpty ? null : photos.last.id;
      await _loadSourceImages();
      if (layout.isTapestry) await _ensureContentSlideCount();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Linx import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _warmSourceBitmaps(List<String> paths) {
    if (paths.isEmpty) return;
    final export = ref.read(exportServiceProvider);
    for (final path in paths) {
      unawaited(export.warmSourceBitmap(path));
    }
  }

  /// Decode each photo once into a [ui.Image] for the live art canvas.
  Future<void> _loadSourceImages() async {
    final version = _version;
    final generation = ++_sourceGeneration;
    if (version == null) {
      setState(_disposeAllImages);
      return;
    }

    setState(() => _sourcesLoading = true);
    final export = ref.read(exportServiceProvider);
    final allPhotos = version.allPhotos;
    final keepIds = allPhotos.map((p) => p.id).toSet();

    // Drop sources for removed photos immediately.
    final removed = _sourceImages.keys
        .where((id) => !keepIds.contains(id))
        .toList(growable: false);
    for (final id in removed) {
      _sourceImages.remove(id)?.dispose();
    }

    final entries = await Future.wait(
      allPhotos.map((photo) async {
        if (_sourceImages.containsKey(photo.id)) {
          return null; // already loaded
        }
        try {
          final rgba = await export.previewSourceRgba(
            sourcePath: photo.sourcePath,
            longEdge: ExportService.interactiveSourceLongEdge,
          );
          final image = await rgbaToUiImage(rgba);
          return MapEntry(photo.id, image);
        } catch (_) {
          return null;
        }
      }),
    );

    if (!mounted || generation != _sourceGeneration) {
      for (final entry in entries) {
        entry?.value.dispose();
      }
      return;
    }

    setState(() {
      for (final entry in entries) {
        if (entry == null) continue;
        _sourceImages[entry.key]?.dispose();
        _sourceImages[entry.key] = entry.value;
      }
      _sourcesLoading = false;
    });
    await _ensureContentSlideCount();
    _scheduleHomeThumbRefresh();
  }

  void _scheduleHomeThumbRefresh() {
    _thumbDebounce?.cancel();
    _thumbDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_refreshHomeThumb());
    });
  }

  Future<void> _refreshHomeThumb() async {
    final project = _project;
    final version = _version;
    if (project == null || version == null) return;
    try {
      final path = await ref.read(exportServiceProvider).refreshIdentityThumb(
            project: project,
            version: version,
          );
      if (path == null || !mounted) return;
      if (version.previewThumbPath == path) {
        // Same stable path — still nudge home list to reload the file.
        await ref.read(projectsProvider.notifier).refresh();
        return;
      }
      await _persist((p) {
        final versions = p.versions
            .map(
              (v) => v.id == version.id
                  ? v.copyWith(previewThumbPath: path)
                  : v,
            )
            .toList();
        return p.copyWith(versions: versions);
      });
    } catch (_) {
      // Preview thumb is best-effort.
    }
  }

  /// Slide count from side-by-side content width when source sizes are known;
  /// otherwise keep at least [fallback] (or photo count).
  int _contentSlideCount(
    List<PhotoItem> photos,
    CanvasConfig config,
    int fallback,
  ) {
    final sizes = <Size>[];
    for (final photo in photos) {
      final image = _sourceImages[photo.id];
      if (image != null) {
        sizes.add(Size(image.width.toDouble(), image.height.toDouble()));
      }
    }
    if (sizes.length == photos.length && sizes.isNotEmpty) {
      return CanvasLayout.slidesNeededForSources(
        sourceSizes: sizes,
        config: config,
      );
    }
    return InstagramLimits.clampSlideCount(
      math.max(fallback, photos.isEmpty ? 1 : photos.length),
    );
  }

  Future<void> _ensureContentSlideCount() async {
    final layout = _layout;
    if (layout == null || !layout.isTapestry || layout.photos.isEmpty) return;
    final sizes = <Size>[];
    for (final photo in layout.photos) {
      final image = _sourceImages[photo.id];
      if (image == null) return; // wait until all decoded
      sizes.add(Size(image.width.toDouble(), image.height.toDouble()));
    }
    final needed = CanvasLayout.slidesNeededForSources(
      sourceSizes: sizes,
      config: layout.config,
    );
    // Grow to fit content by default; never shrink a user-expanded canvas.
    if (needed > layout.slideCount) {
      await _updateLayout(layout.copyWith(tapestrySlideCount: needed));
    }
  }

  Future<void> _openCodecSettings() async {
    final version = _version;
    if (version == null || version.frozen) return;
    final sample =
        await ref.read(exportServiceProvider).renderFirstFrame(version);
    if (sample == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add a photo before opening codec settings.'),
          ),
        );
      }
      return;
    }

    final beforeEncoded = await ImageCodecService.encode(
      sample,
      const ExportCodecSettings(format: ExportFormat.png, pngLevel: 1),
    );
    final beforeBytes = beforeEncoded.bytes;

    if (!mounted) return;
    final next = await Navigator.of(context).push<ExportCodecSettings>(
      MaterialPageRoute(
        builder: (_) => ExportCodecSettingsPage(
          initial: version.config.codec,
          sampleImage: sample,
          uncodedPreviewBytes: beforeBytes,
        ),
      ),
    );
    if (next != null) {
      await _updateConfig(version.config.copyWith(codec: next));
    }
  }

  Future<void> _exportAndShare() async {
    final project = _project;
    final version = _version;
    final layout = _layout;
    if (project == null || version == null || layout == null) return;

    // Open settings immediately; size estimate sample loads in the background
    // at estimate resolution (not full export decode/render on the UI wait).
    const estimateEdge = 720;
    final sampleFuture = ref.read(exportServiceProvider).renderFirstFrame(
          version,
          longEdge: estimateEdge,
        );
    if (!mounted) return;

    final chosen = await showExportSettingsDialog(
      context: context,
      initial: layout.config.codec,
      sampleFuture: sampleFuture,
      frameCount: layout.isTapestry
          ? layout.slideCount
          : (layout.photos.isEmpty ? 1 : layout.photos.length),
    );
    if (chosen == null) return;

    await _updateConfig(layout.config.copyWith(codec: chosen));
    final latest = _version;
    if (latest == null) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(exportServiceProvider).exportVersion(
            project: project,
            version: latest,
            codecOverride: chosen,
          );

      await _persist((proj) {
        final versions = proj.versions.map((v) {
          if (v.id != latest.id) return v;
          return v.copyWith(
            exportPaths: result.paths,
            previewThumbPath: result.identityThumbPath ?? v.previewThumbPath,
          );
        }).toList();
        return proj.copyWith(versions: versions);
      });

      if (result.paths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nothing to export — add photos first.')),
          );
        }
        return;
      }

      if (mounted) setState(() => _busy = false);
      if (!mounted) return;
      final destination = await showExportDestinationDialog(
        context: context,
        fileCount: result.paths.length,
        sizeLabel: formatBytes(result.totalBytes),
      );
      if (destination == null) return;

      final String deliveryLabel;
      if (destination == ExportDestination.save) {
        final saved = await ref.read(exportSaveProvider).saveExports(
              sourcePaths: result.paths,
              suggestedBaseName: project.name,
            );
        if (saved == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Save canceled.')),
            );
          }
          return;
        }
        deliveryLabel = saved.fileCount > 1
            ? 'Saved ${saved.fileCount} files to ${saved.destinationLabel}'
            : 'Saved to ${saved.destinationLabel}';
      } else {
        await ref.read(instagramShareProvider).shareExports(result.paths);
        deliveryLabel = 'Shared (${formatBytes(result.totalBytes)})';
      }

      // Export never freezes. Offer an explicit Mark as posted choice
      // (default Keep editing) only when this version is still editable.
      if (!mounted) return;
      final alreadyFrozen = _version?.frozen == true;
      if (!alreadyFrozen) {
        final markPosted = await showMarkAsPostedDialog(
          context: context,
          deliveryLabel: deliveryLabel,
        );
        if (markPosted) {
          await _markAsPosted();
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(deliveryLabel)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markAsPosted() async {
    final project = _project;
    final version = _version;
    if (project == null || version == null || version.frozen) return;
    final frozen = await ref.read(projectStoreProvider).markAsPosted(project);
    await ref.read(projectsProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _project = frozen);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Marked as posted — version frozen. Unlock or clone to edit again.',
        ),
      ),
    );
  }

  Future<void> _unfreezeVersion() async {
    final project = _project;
    final version = _version;
    if (project == null || version == null || !version.frozen) return;
    final confirmed = await showUnfreezeConfirmDialog(context: context);
    if (!confirmed || !mounted) return;
    final thawed =
        await ref.read(projectStoreProvider).unfreezeActiveVersion(project);
    await ref.read(projectsProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _project = thawed);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unlocked — you can keep editing.')),
    );
  }

  Future<void> _cloneVersion() async {
    final project = _project;
    if (project == null) return;
    final cloned = await ref.read(projectStoreProvider).cloneVersion(project);
    await ref.read(projectsProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _project = cloned);
    await _loadSourceImages();
  }

  Future<void> _saveTemplate() async {
    final version = _version;
    if (version == null) return;
    final controller = TextEditingController(
      text: '${version.config.aspect.label} · ${version.config.swatch.name}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save canvas template'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Template name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(templatesProvider.notifier).saveAs(
          name: name,
          config: version.config,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved template “$name”')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final version = _version;
    final layout = _layout;

    if (project == null || version == null || layout == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project')),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final isTapestry = layout.isTapestry;

    final thumbItems = [
      for (final photo in layout.photos)
        ThumbItem(
          id: photo.id,
          label: photo.fileName ?? p.basename(photo.sourcePath),
          image: _sourceImages[photo.id],
          photo: photo,
        ),
    ];

    final photosColumn = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isTapestry ? 'Sources' : 'Photos',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Add photos',
                visualDensity: VisualDensity.compact,
                onPressed: version.frozen ? null : _addPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'From Linx',
                visualDensity: VisualDensity.compact,
                onPressed: version.frozen ? null : () => _addFromLinx(),
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: ImageThumbnailGrid(
            items: thumbItems,
            config: layout.config,
            selectedId: _selectedPhotoId,
            onSelect: (id) {
              _selectPhoto(id);
            },
            onReorder: (oldIndex, newIndex) async {
              if (version.frozen) return;
              final photos = [...layout.photos]
                ..sort((a, b) => a.order.compareTo(b.order));
              final item = photos.removeAt(oldIndex);
              photos.insert(newIndex, item);
              final reindexed = [
                for (var i = 0; i < photos.length; i++)
                  photos[i].copyWith(order: i),
              ];
              await _updateLayout(layout.copyWith(photos: reindexed));
            },
          ),
        ),
      ],
    );

    final settingsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Text(
            'Settings',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted(context, 0.85),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            layout.name,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.muted(context, 0.5),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: CanvasControls(
            config: layout.config,
            locked: version.frozen,
            onChanged: _updateConfig,
            onOpenCodecSettings: _openCodecSettings,
            layerPhotos: layout.photos,
            layerTexts: layout.texts,
            layerImages: _sourceImages,
            selectedPhotoId: _selectedPhotoId,
            selectedTextId: _selectedTextId,
            selectedText: () {
              final id = _selectedTextId;
              if (id == null) return null;
              for (final t in layout.texts) {
                if (t.id == id) return t;
              }
              return null;
            }(),
            onSelectPhoto: _selectPhoto,
            onSelectText: _selectText,
            onSelectLayer: _selectLayer,
            onReorderLayers: _reorderLayers,
            onRaiseLayer: () => _applyZOrder(TapestryLayerOrder.raise),
            onLowerLayer: () => _applyZOrder(TapestryLayerOrder.lower),
            onBringLayerToFront: () =>
                _applyZOrder(TapestryLayerOrder.bringToFront),
            onSendLayerToBack: () =>
                _applyZOrder(TapestryLayerOrder.sendToBack),
            onTextChanged: _updateSelectedText,
          ),
        ),
      ],
    );

    final workspace = CanvasWorkspace(
      layouts: version.layouts,
      activeLayoutId: version.activeLayoutId ?? layout.id,
      sourceImages: _sourceImages,
      selectedPhotoId: _selectedPhotoId,
      selectedTextId: _selectedTextId,
      loading: _sourcesLoading && _sourceImages.isEmpty,
      locked: version.frozen,
      tapestryControllers: _tapestryControllers,
      onSelectLayout: _selectLayout,
      onSelectPhoto: _selectPhoto,
      onSelectText: _selectText,
      onUpdateLayout: _updateLayout,
      onAddLayout: _addLayout,
      onDeleteLayout: _deleteLayout,
    );

    final mainPane = Column(
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        if (version.frozen)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This version is frozen (marked as posted) — editing is disabled.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _unfreezeVersion,
                    child: const Text('Unlock'),
                  ),
                  TextButton(
                    onPressed: _cloneVersion,
                    child: const Text('Clone to keep editing'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rails = _railWidthsFor(constraints.maxWidth);
              return Row(
                children: [
                  SizedBox(width: rails.photos, child: photosColumn),
                  VerticalDivider(width: 1, color: AppTheme.chrome(context)),
                  Expanded(child: workspace),
                  VerticalDivider(width: 1, color: AppTheme.chrome(context)),
                  SizedBox(width: rails.settings, child: settingsColumn),
                ],
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Tooltip(
          message: 'Rename project',
          child: InkWell(
            onTap: _renameProject,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      project.name,
                      overflow: TextOverflow.ellipsis,
                      // Sans — AppBar titleTextStyle is Georgia for brand.
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppTheme.muted(context, 0.55),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          const UiScaleButtons(),
          const ThemeModeButton(),
          TextButton(
            onPressed: () async {
              final applied = await Navigator.of(context).push<CanvasConfig>(
                MaterialPageRoute(
                  builder: (_) => const TemplatesScreen(pickMode: true),
                ),
              );
              if (applied != null) await _updateConfig(applied);
            },
            child: const Text('Templates'),
          ),
          TextButton(
            onPressed: () async {
              final refreshed = await Navigator.of(context).push<Project>(
                MaterialPageRoute(
                  builder: (_) => VersionBrowserScreen(project: project),
                ),
              );
              if (refreshed != null) {
                setState(() => _project = refreshed);
                await _loadSourceImages();
              }
            },
            child: Text(version.label ?? 'v${version.versionNumber}'),
          ),
          IconButton(
            tooltip: 'Save as template',
            onPressed: _saveTemplate,
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
          if (version.frozen) ...[
            IconButton(
              tooltip: 'Unlock / unmark posted',
              onPressed: _unfreezeVersion,
              icon: const Icon(Icons.lock_open_outlined),
            ),
            IconButton(
              tooltip: 'Clone to new version',
              onPressed: _cloneVersion,
              icon: const Icon(Icons.copy_all_outlined),
            ),
          ] else
            IconButton(
              tooltip: 'Mark as posted (lock editing)',
              onPressed: _busy ? null : _markAsPosted,
              icon: const Icon(Icons.lock_outline),
            ),
          IconButton(
            tooltip: exportPrefersSaveFirst
                ? 'Export (save or share)'
                : 'Export & share',
            onPressed: _busy ? null : _exportAndShare,
            icon: Icon(
              exportPrefersSaveFirst
                  ? Icons.save_alt_outlined
                  : Icons.ios_share_outlined,
            ),
          ),
        ],
      ),
      body: mainPane,
    );
  }
}
