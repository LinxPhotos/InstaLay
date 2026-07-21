import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/canvas_config.dart';
import '../models/export_codec.dart';
import '../models/project.dart';
import '../models/resample_algorithm.dart';
import '../providers/app_providers.dart';
import '../services/export_service.dart';
import '../services/image_codec_service.dart';
import '../theme/app_theme.dart';
import '../widgets/canvas_controls.dart';
import '../widgets/export_settings_dialog.dart';
import '../widgets/image_thumbnail_grid.dart';
import '../widgets/linx_photo_picker_dialog.dart';
import '../widgets/preview_sidebar.dart';
import '../widgets/theme_mode_button.dart';
import '../services/linx_client.dart';
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
  final Map<String, ui.Image> _thumbImages = {};
  ui.Image? _previewImage;
  List<ui.Image> _previewSlices = const [];
  bool _previewLoading = false;
  bool _busy = false;
  int _previewGeneration = 0;
  double _previewPanelWidth = 320;
  Timer? _configDebounce;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _configDebounce?.cancel();
    _disposeAllImages();
    super.dispose();
  }

  bool _imageInUse(ui.Image image) {
    if (identical(_previewImage, image)) return true;
    for (final slice in _previewSlices) {
      if (identical(slice, image)) return true;
    }
    for (final thumb in _thumbImages.values) {
      if (identical(thumb, image)) return true;
    }
    return false;
  }

  void _disposeIfUnused(ui.Image? image) {
    if (image != null && !_imageInUse(image)) {
      image.dispose();
    }
  }

  void _disposeAllImages() {
    final seen = <ui.Image>{};
    void track(ui.Image? image) {
      if (image != null) seen.add(image);
    }

    track(_previewImage);
    for (final slice in _previewSlices) {
      track(slice);
    }
    for (final thumb in _thumbImages.values) {
      track(thumb);
    }
    for (final image in seen) {
      image.dispose();
    }
    _previewImage = null;
    _previewSlices = const [];
    _thumbImages.clear();
  }

  void _setPreviewImage(ui.Image? next) {
    final old = _previewImage;
    _previewImage = next;
    _disposeIfUnused(old);
  }

  void _setPreviewSlices(List<ui.Image> next) {
    final old = _previewSlices;
    _previewSlices = next;
    for (final image in old) {
      _disposeIfUnused(image);
    }
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
    await _rebuildThumbs();
    final photos = project.activeVersion?.photos ?? const [];
    if (photos.isNotEmpty) {
      _selectedPhotoId = photos.first.id;
      await _rebuildPreview();
    }
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

  Future<void> _persist(Project Function(Project p) mutate) async {
    final current = _project;
    if (current == null) return;
    final saved = await ref.read(projectStoreProvider).save(mutate(current));
    await ref.read(projectsProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _project = saved);
  }

  Future<void> _renameLayout() async {
    final project = _project;
    if (project == null) return;
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename layout'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
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

  Future<void> _updateConfig(CanvasConfig config) async {
    final version = _version;
    if (version == null || version.frozen) return;
    // Immediate control feedback; debounce expensive preview/thumb rebuilds.
    setState(() {
      final versions = _project!.versions
          .map((v) => v.id == version.id ? v.copyWith(config: config) : v)
          .toList();
      _project = _project!.copyWith(versions: versions);
    });
    _configDebounce?.cancel();
    _configDebounce = Timer(const Duration(milliseconds: 180), () async {
      await _persist((p) {
        final versions = p.versions
            .map((v) => v.id == version.id ? v.copyWith(config: config) : v)
            .toList();
        return p.copyWith(versions: versions);
      });
      await _rebuildThumbs();
      await _rebuildPreview();
    });
  }

  Future<void> _addPhotos() async {
    final version = _version;
    if (version == null || version.frozen) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ExportFormat.pickerExtensions,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _busy = true);
    try {
      final media = await ref.read(projectStoreProvider).mediaDir(_project!.id);
      final photos = [...version.photos];
      final addedPaths = <String>[];
      var order = photos.length;
      for (final file in result.files) {
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
            order: order++,
          ),
        );
      }
      await _persist((proj) {
        final versions = proj.versions
            .map((v) => v.id == version.id ? v.copyWith(photos: photos) : v)
            .toList();
        return proj.copyWith(versions: versions);
      });
      _warmSourceBitmaps(addedPaths);
      _selectedPhotoId ??= photos.isEmpty ? null : photos.last.id;
      await _rebuildThumbs();
      await _rebuildPreview();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFromLinx({String? albumId}) async {
    final version = _version;
    if (version == null || version.frozen) return;

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
      final photos = [...version.photos];
      final addedPaths = <String>[];
      var order = photos.length;
      for (final variant in picked) {
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
            order: order++,
          ),
        );
      }
      await _persist((proj) {
        final versions = proj.versions
            .map((v) => v.id == version.id ? v.copyWith(photos: photos) : v)
            .toList();
        return proj.copyWith(versions: versions);
      });
      _warmSourceBitmaps(addedPaths);
      _selectedPhotoId ??= photos.isEmpty ? null : photos.last.id;
      await _rebuildThumbs();
      await _rebuildPreview();
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

  Future<void> _rebuildThumbs() async {
    final version = _version;
    if (version == null) return;
    final export = ref.read(exportServiceProvider);
    final entries = await Future.wait(
      version.photos.map((photo) async {
        try {
          final rgba = await export.previewPhotoRgba(
            sourcePath: photo.sourcePath,
            config: version.config,
            longEdge: 360,
            photo: photo,
            algorithm: ResampleAlgorithm.linear,
          );
          final image = await rgbaToUiImage(rgba);
          return MapEntry(photo.id, image);
        } catch (_) {
          return null;
        }
      }),
    );
    if (!mounted) {
      for (final entry in entries) {
        entry?.value.dispose();
      }
      return;
    }
    final next = <String, ui.Image>{
      for (final entry in entries)
        if (entry != null) entry.key: entry.value,
    };
    setState(() {
      final old = Map<String, ui.Image>.from(_thumbImages);
      _thumbImages
        ..clear()
        ..addAll(next);
      for (final image in old.values) {
        _disposeIfUnused(image);
      }
    });
  }

  Future<void> _rebuildPreview() async {
    final version = _version;
    final generation = ++_previewGeneration;
    if (version == null) {
      setState(() {
        _setPreviewImage(null);
        _setPreviewSlices(const []);
      });
      return;
    }

    setState(() => _previewLoading = true);
    try {
      if (version.config.layoutMode == LayoutMode.tapestry) {
        final slices =
            await ref.read(exportServiceProvider).previewTapestryRgba(
                  photos: version.photos,
                  config: version.config,
                  longEdge: ExportService.interactivePreviewLongEdge,
                  algorithm: ResampleAlgorithm.linear,
                );
        final images = <ui.Image>[];
        for (final slice in slices) {
          images.add(await rgbaToUiImage(slice));
        }
        if (!mounted || generation != _previewGeneration) {
          for (final image in images) {
            image.dispose();
          }
          return;
        }
        setState(() {
          _setPreviewSlices(images);
          _setPreviewImage(null);
        });
        return;
      }

      final id = _selectedPhotoId;
      if (id == null) {
        if (!mounted || generation != _previewGeneration) return;
        setState(() {
          _setPreviewImage(null);
          _setPreviewSlices(const []);
        });
        return;
      }
      final photo = version.photos.cast<PhotoItem?>().firstWhere(
            (p) => p!.id == id,
            orElse: () => null,
          );
      if (photo == null) return;

      final rgba = await ref.read(exportServiceProvider).previewPhotoRgba(
            sourcePath: photo.sourcePath,
            config: version.config,
            longEdge: ExportService.interactivePreviewLongEdge,
            photo: photo,
            algorithm: ResampleAlgorithm.linear,
          );
      final image = await rgbaToUiImage(rgba);
      if (!mounted || generation != _previewGeneration) {
        image.dispose();
        return;
      }
      setState(() {
        _setPreviewImage(image);
        _setPreviewSlices(const []);
      });
    } catch (_) {
      if (!mounted || generation != _previewGeneration) return;
      setState(() {
        _setPreviewImage(null);
        _setPreviewSlices(const []);
      });
    } finally {
      if (mounted && generation == _previewGeneration) {
        setState(() => _previewLoading = false);
      }
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

  Future<void> _exportAndShare({bool commit = true}) async {
    final project = _project;
    final version = _version;
    if (project == null || version == null) return;

    final sample =
        await ref.read(exportServiceProvider).renderFirstFrame(version);
    if (!mounted) return;

    final chosen = await showExportSettingsDialog(
      context: context,
      initial: version.config.codec,
      sampleImage: sample,
      frameCount: version.photos.isEmpty ? 1 : version.photos.length,
    );
    if (chosen == null) return;

    await _updateConfig(version.config.copyWith(codec: chosen));
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

      await ref.read(instagramShareProvider).shareExports(result.paths);

      if (commit && !(latest.frozen)) {
        final frozen =
            await ref.read(projectStoreProvider).commitToInstagram(_project!);
        await ref.read(projectsProvider.notifier).refresh();
        if (mounted) setState(() => _project = frozen);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Shared (${formatBytes(result.totalBytes)}). '
                'Version frozen. Clone it to keep editing.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cloneVersion() async {
    final project = _project;
    if (project == null) return;
    final cloned = await ref.read(projectStoreProvider).cloneVersion(project);
    await ref.read(projectsProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _project = cloned);
    await _rebuildThumbs();
    await _rebuildPreview();
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

    if (project == null || version == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Layout')),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final thumbItems = [
      for (final photo in version.photos)
        ThumbItem(
          id: photo.id,
          label: photo.fileName ?? p.basename(photo.sourcePath),
          image: _thumbImages[photo.id],
        ),
    ];

    final mainPane = Column(
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Row(
                        children: [
                          const Text(
                            'Photos',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: version.frozen ? null : _addPhotos,
                            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                            label: const Text('Add'),
                          ),
                          TextButton.icon(
                            onPressed: version.frozen ? null : () => _addFromLinx(),
                            icon: const Icon(Icons.cloud_download_outlined, size: 18),
                            label: const Text('From Linx'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ImageThumbnailGrid(
                        items: thumbItems,
                        config: version.config,
                        selectedId: _selectedPhotoId,
                        onSelect: (id) async {
                          final isTapestry =
                              version.config.layoutMode == LayoutMode.tapestry;
                          setState(() {
                            _selectedPhotoId = id;
                            // Instant feedback from grid thumb while framing.
                            if (!isTapestry) {
                              final thumb = _thumbImages[id];
                              if (thumb != null) {
                                _setPreviewImage(thumb);
                                _setPreviewSlices(const []);
                              }
                            }
                          });
                          // Tapestry preview is version-wide; selection only highlights.
                          if (!isTapestry) await _rebuildPreview();
                        },
                        onReorder: (oldIndex, newIndex) async {
                          if (version.frozen) return;
                          final photos = [...version.photos]
                            ..sort((a, b) => a.order.compareTo(b.order));
                          final item = photos.removeAt(oldIndex);
                          photos.insert(newIndex, item);
                          final reindexed = [
                            for (var i = 0; i < photos.length; i++)
                              photos[i].copyWith(order: i),
                          ];
                          await _persist((proj) {
                            final versions = proj.versions
                                .map(
                                  (v) => v.id == version.id
                                      ? v.copyWith(photos: reindexed)
                                      : v,
                                )
                                .toList();
                            return proj.copyWith(versions: versions);
                          });
                          if (version.config.layoutMode == LayoutMode.tapestry) {
                            await _rebuildPreview();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: AppTheme.chrome(context)),
              Expanded(
                child: CanvasControls(
                  config: version.config,
                  locked: version.frozen,
                  onChanged: _updateConfig,
                  onOpenCodecSettings: _openCodecSettings,
                ),
              ),
              if (wide) ...[
                _ResizeHandle(
                  onDrag: (dx) {
                    setState(() {
                      _previewPanelWidth =
                          (_previewPanelWidth - dx).clamp(240.0, 560.0);
                    });
                  },
                ),
                PreviewSidebar(
                  title: 'Preview',
                  image: _previewImage,
                  slices: _previewSlices,
                  loading: _previewLoading,
                  width: _previewPanelWidth,
                  aspectRatio: version.config.aspect.ratio,
                ),
              ],
            ],
          ),
        ),
        if (!wide)
          SizedBox(
            height: 280,
            child: PreviewSidebar(
              title: 'Preview',
              image: _previewImage,
              slices: _previewSlices,
              loading: _previewLoading,
              width: double.infinity,
              aspectRatio: version.config.aspect.ratio,
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Tooltip(
          message: 'Rename layout',
          child: InkWell(
            onTap: _renameLayout,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      overflow: TextOverflow.ellipsis,
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
                await _rebuildThumbs();
                await _rebuildPreview();
              }
            },
            child: Text(version.label ?? 'v${version.versionNumber}'),
          ),
          IconButton(
            tooltip: 'Save as template',
            onPressed: _saveTemplate,
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
          if (version.frozen)
            IconButton(
              tooltip: 'Clone to new version',
              onPressed: _cloneVersion,
              icon: const Icon(Icons.copy_all_outlined),
            ),
          IconButton(
            tooltip: 'Export & post to Instagram',
            onPressed: _busy ? null : () => _exportAndShare(commit: true),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: mainPane,
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(
          width: 6,
          child: ColoredBox(
            color: AppTheme.chrome(context),
            child: Center(
              child: SizedBox(
                width: 2,
                height: 28,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: const BorderRadius.all(Radius.circular(1)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
