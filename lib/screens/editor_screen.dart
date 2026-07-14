import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/canvas_config.dart';
import '../models/project.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/canvas_controls.dart';
import '../widgets/image_thumbnail_grid.dart';
import '../widgets/preview_sidebar.dart';
import 'templates_screen.dart';
import 'version_browser_screen.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    required this.projectId,
    this.openShareOnLoad = false,
  });

  final String projectId;
  final bool openShareOnLoad;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  Project? _project;
  String? _selectedPhotoId;
  final Map<String, Uint8List> _thumbBytes = {};
  Uint8List? _previewBytes;
  bool _busy = false;
  bool _previewLoading = false;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _updateConfig(CanvasConfig config) async {
    final version = _version;
    if (version == null || version.frozen) return;
    await _persist((p) {
      final versions = p.versions
          .map((v) => v.id == version.id ? v.copyWith(config: config) : v)
          .toList();
      return p.copyWith(versions: versions);
    });
    await _rebuildThumbs();
    await _rebuildPreview();
  }

  Future<void> _addPhotos() async {
    final version = _version;
    if (version == null || version.frozen) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _busy = true);
    try {
      final media = await ref.read(projectStoreProvider).mediaDir(_project!.id);
      final photos = [...version.photos];
      var order = photos.length;
      for (final file in result.files) {
        final path = file.path;
        if (path == null) continue;
        final destName = '${_uuid.v4()}${p.extension(path)}';
        final dest = p.join(media.path, destName);
        await File(path).copy(dest);
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
      _selectedPhotoId ??= photos.isEmpty ? null : photos.last.id;
      await _rebuildThumbs();
      await _rebuildPreview();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rebuildThumbs() async {
    final version = _version;
    if (version == null) return;
    final export = ref.read(exportServiceProvider);
    final next = <String, Uint8List>{};
    for (final photo in version.photos) {
      try {
        next[photo.id] = await export.previewPhotoBytes(
          sourcePath: photo.sourcePath,
          config: version.config,
          longEdge: 360,
          photo: photo,
          algorithm: version.config.thumbnailAlgorithm,
        );
      } catch (_) {
        // Skip broken files.
      }
    }
    if (!mounted) return;
    setState(() {
      _thumbBytes
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _rebuildPreview() async {
    final version = _version;
    final id = _selectedPhotoId;
    if (version == null || id == null) {
      setState(() => _previewBytes = null);
      return;
    }
    final photo = version.photos.cast<PhotoItem?>().firstWhere(
          (p) => p!.id == id,
          orElse: () => null,
        );
    if (photo == null) return;

    setState(() => _previewLoading = true);
    try {
      final bytes = await ref.read(exportServiceProvider).previewPhotoBytes(
            sourcePath: photo.sourcePath,
            config: version.config,
            longEdge: version.config.exportLongEdge,
            photo: photo,
            algorithm: version.config.exportAlgorithm,
          );
      if (!mounted) return;
      setState(() => _previewBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _previewBytes = null);
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  Future<void> _exportAndShare({bool commit = true}) async {
    final project = _project;
    final version = _version;
    if (project == null || version == null) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(exportServiceProvider).exportVersion(
            project: project,
            version: version,
          );

      await _persist((proj) {
        final versions = proj.versions.map((v) {
          if (v.id != version.id) return v;
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

      if (commit && !(version.frozen)) {
        final frozen = await ref.read(projectStoreProvider).commitToInstagram(_project!);
        await ref.read(projectsProvider.notifier).refresh();
        if (mounted) setState(() => _project = frozen);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Shared. Version frozen. Clone it to keep editing.',
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
          bytes: _thumbBytes[photo.id],
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
                        ],
                      ),
                    ),
                    Expanded(
                      child: ImageThumbnailGrid(
                        items: thumbItems,
                        config: version.config,
                        selectedId: _selectedPhotoId,
                        onSelect: (id) async {
                          setState(() => _selectedPhotoId = id);
                          await _rebuildPreview();
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
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, color: AppTheme.mist),
              Expanded(
                child: CanvasControls(
                  config: version.config,
                  locked: version.frozen,
                  onChanged: _updateConfig,
                ),
              ),
              if (wide)
                PreviewSidebar(
                  title: version.config.layoutMode == LayoutMode.tapestry
                      ? 'Export preview'
                      : '1:1 preview',
                  bytes: _previewBytes,
                  loading: _previewLoading,
                ),
            ],
          ),
        ),
        if (!wide)
          SizedBox(
            height: 280,
            child: PreviewSidebar(
              title: '1:1 preview',
              bytes: _previewBytes,
              loading: _previewLoading,
              width: double.infinity,
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
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
