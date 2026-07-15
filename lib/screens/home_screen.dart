import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/license_dialog.dart';
import '../widgets/project_list_tile.dart';
import 'editor_screen.dart';
import 'templates_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final licenseAsync = ref.watch(licenseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('InstaLay'),
        actions: [
          IconButton(
            tooltip: 'License',
            onPressed: () async {
              final license = await ref.read(licenseProvider.future);
              if (!context.mounted) return;
              await showLicenseDialog(context, license);
              ref.invalidate(licenseProvider);
            },
            icon: Icon(
              licenseAsync.valueOrNull?.isLicensed == true
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
                    Text(
                      'InstaLay',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Batch-frame photos for Instagram without awkward crops. '
                      'Pick a ratio, matte, border, and export — or stitch a tapestry '
                      'carousel the way SCRL does.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _newProject(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('New layout'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.mist),
            itemBuilder: (context, index) {
              final project = list[index];
              return ProjectListTile(
                project: project,
                onOpen: () => _open(context, project.id),
                onShare: () => _open(context, project.id, share: true),
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
        label: const Text('New layout'),
      ),
    );
  }

  Future<void> _newProject(BuildContext context, WidgetRef ref) async {
    final project = await ref.read(projectsProvider.notifier).create();
    if (!context.mounted) return;
    await _open(context, project.id);
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
