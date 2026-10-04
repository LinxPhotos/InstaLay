import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/android_share_bridge.dart';
import 'editor_screen.dart';

/// Creates a project and opens the editor with shared Android media.
Future<void> openAndroidShareImport(
  BuildContext context,
  WidgetRef ref,
  List<AndroidSharedMediaItem> items,
) async {
  if (items.isEmpty) return;
  final project = await ref.read(projectsProvider.notifier).create(
        name: 'Shared import',
      );
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EditorScreen(
        projectId: project.id,
        initialAndroidShares: items,
      ),
    ),
  );
}
