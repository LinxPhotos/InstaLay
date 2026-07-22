import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/project.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class VersionBrowserScreen extends ConsumerWidget {
  const VersionBrowserScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat.yMMMd().add_jm();
    final versions = [...project.versions]
      ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));

    return Scaffold(
      appBar: AppBar(title: const Text('Versions')),
      body: ListView.separated(
        itemCount: versions.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final v = versions[index];
          final active = v.id == project.activeVersionId;
          return ListTile(
            selected: active,
            title: Text(v.label ?? 'v${v.versionNumber}'),
            subtitle: Text(
              [
                fmt.format(v.createdAt),
                '${v.layouts.length} layout${v.layouts.length == 1 ? '' : 's'}',
                '${v.allPhotos.length} photos',
                v.config.aspect.label,
                if (v.frozen) 'frozen',
                if (v.isPosted) 'posted ${fmt.format(v.postedToInstagramAt!)}',
              ].join(' · '),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                if (!active)
                  TextButton(
                    onPressed: () async {
                      final next = await ref
                          .read(projectStoreProvider)
                          .setActiveVersion(project, v.id);
                      await ref.read(projectsProvider.notifier).refresh();
                      if (context.mounted) Navigator.pop(context, next);
                    },
                    child: const Text('Open'),
                  ),
                TextButton(
                  onPressed: () async {
                    final next = await ref
                        .read(projectStoreProvider)
                        .cloneVersion(project, fromVersionId: v.id);
                    await ref.read(projectsProvider.notifier).refresh();
                    if (context.mounted) Navigator.pop(context, next);
                  },
                  child: const Text('Clone'),
                ),
                if (v.exportPaths.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(instagramShareProvider)
                          .shareExports(v.exportPaths);
                    },
                    child: const Text('Repost'),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Versions marked as posted stay frozen until you Unlock them or '
            'clone a new editable copy. You can also repost previous exports.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.muted(context, 0.55),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
