import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/project.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/instalay_wordmark.dart';
import '../widgets/license_dialog.dart';
import '../widgets/project_list_tile.dart';
import '../widgets/theme_mode_button.dart';
import '../widgets/ui_scale_buttons.dart';
import 'editor_screen.dart';
import 'templates_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeLinxLaunch());
  }

  Future<void> _consumeLinxLaunch() async {
    final intent = ref.read(pendingLinxLaunchProvider);
    if (intent == null || !intent.hasWork) return;
    ref.read(pendingLinxLaunchProvider.notifier).state = null;

    final project = await ref.read(projectsProvider.notifier).create(
          name: intent.albumId != null ? 'Linx import' : 'Linx photos',
        );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          projectId: project.id,
          initialLinxAlbumId: intent.albumId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final licenseAsync = ref.watch(licenseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/branding/instalay_logo.svg',
              height: 28,
              width: 28,
            ),
            const SizedBox(width: 10),
            const InstaLayWordmark(fontSize: 25.6), // 20 × 1.28
          ],
        ),
        actions: [
          const UiScaleButtons(),
          const ThemeModeButton(),
          IconButton(
            tooltip: 'License',
            onPressed: () async {
              final license = await ref.read(licenseProvider.future);
              if (!context.mounted) return;
              await showLicenseDialog(context, license);
              ref.invalidate(licenseProvider);
            },
            icon: Icon(
              licenseAsync.value?.isLicensed == true
                  ? Icons.verified_outlined
                  : Icons.key_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Canvas templates',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TemplatesScreen()),
              );
            },
            icon: const Icon(Icons.bookmark_border),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(projectsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load projects.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/branding/instalay_logo.svg',
                      height: 72,
                      width: 72,
                    ),
                    const SizedBox(height: 16),
                    const InstaLayWordmark(fontSize: 35.84), // 28 × 1.28
                    const SizedBox(height: 8),
                    Text(
                      'Batch-frame photos for Instagram without awkward crops. '
                      'Pick a ratio, matte, border, and export — or stitch a tapestry '
                      'carousel the way SCRL does.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted(context, 0.6)),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _newProject(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('New project'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: AppTheme.chrome(context)),
            itemBuilder: (context, index) {
              final project = list[index];
              return ProjectListTile(
                project: project,
                onOpen: () => _open(context, project.id),
                onShare: () => _open(context, project.id, share: true),
                onRename: () => _renameProject(context, ref, project),
                onDelete: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete project?'),
                      content: Text('Remove “${project.name}” from this device?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(projectsProvider.notifier).delete(project.id);
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newProject(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
    );
  }

  Future<void> _newProject(BuildContext context, WidgetRef ref) async {
    final project = await ref.read(projectsProvider.notifier).create();
    if (!context.mounted) return;
    await _open(context, project.id);
  }

  Future<void> _renameProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename project'),
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
    await ref.read(projectStoreProvider).save(project.copyWith(name: name));
    await ref.read(projectsProvider.notifier).refresh();
  }

  Future<void> _open(
    BuildContext context,
    String projectId, {
    bool share = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(projectId: projectId, openShareOnLoad: share),
      ),
    );
  }
}
