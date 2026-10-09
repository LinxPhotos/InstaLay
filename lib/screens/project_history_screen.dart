import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/project.dart';
import '../providers/app_providers.dart';
import '../services/project_history.dart';
import '../layout/responsive.dart';

/// Auto-save snapshots for the current project (restore after bad edits).
class ProjectHistoryScreen extends ConsumerStatefulWidget {
  const ProjectHistoryScreen({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<ProjectHistoryScreen> createState() =>
      _ProjectHistoryScreenState();
}

class _ProjectHistoryScreenState extends ConsumerState<ProjectHistoryScreen> {
  List<ProjectHistoryEntry> _entries = const [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final entries = await ProjectHistory.listEntries(widget.project.id);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _restore(ProjectHistoryEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore this save?'),
        content: Text(
          'Replace the current project with the auto-save from '
          '${DateFormat.yMMMd().add_jms().format(entry.savedAt.toLocal())}. '
          'Your current state is snapshotted first if it differs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final store = ref.read(projectStoreProvider);
      final current = widget.project;
      final restored = await ProjectHistory.restoreSnapshot(
        current: current,
        entry: entry,
      );
      final saved = await store.save(restored);
      await ref.read(projectsProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_jms();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Save history'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No auto-save snapshots yet. '
                      'Each time the project changes, the previous state is kept here '
                      '(last ${ProjectHistory.maxSnapshotsPerProject} saves).',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final label = fmt.format(entry.savedAt.toLocal());
                    return ListTile(
                      title: Text(label),
                      subtitle: Text(
                        index == 0
                            ? 'Most recent backup before last save'
                            : 'Auto-save snapshot',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () => _restore(entry),
                        child: const Text('Restore'),
                      ),
                      isThreeLine: isWideLayout(context),
                    );
                  },
                ),
    );
  }
}
