import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/canvas_config.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key, this.pickMode = false});

  final bool pickMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(pickMode ? 'Apply template' : 'Canvas templates'),
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                pickMode
                    ? 'No templates yet. Save one from the editor.'
                    : 'Save canvas configurations from a layout to reuse '
                        'borders, mattes, ratios, and resampling across photo sets.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.55)),
              ),
            );
          }

          final fmt = DateFormat.yMMMd();
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tpl = list[index];
              return ListTile(
                title: Text(tpl.name),
                subtitle: Text(
                  '${tpl.config.aspect.label} · ${tpl.config.swatch.name} · '
                  'border ${tpl.config.borderPx}px · ${tpl.config.texture.label}\n'
                  '${fmt.format(tpl.createdAt)}',
                ),
                isThreeLine: true,
                onTap: pickMode
                    ? () => Navigator.pop<CanvasConfig>(context, tpl.config)
                    : null,
                trailing: pickMode
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            ref.read(templatesProvider.notifier).delete(tpl.id),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
