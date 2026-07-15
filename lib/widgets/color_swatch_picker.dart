import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/color_swatches.dart';
import '../models/matte_palette.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class ColorSwatchPicker extends ConsumerWidget {
  const ColorSwatchPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final ValueChanged<CanvasSwatch> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mattePaletteProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(
        child: Text(
          'Could not load mattes\n$e',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.muted(context, 0.55),
          ),
        ),
      ),
      data: (palette) => _MatteBrowser(
        palette: palette,
        selectedId: selectedId,
        onSelected: onSelected,
      ),
    );
  }
}

class _MatteBrowser extends ConsumerWidget {
  const _MatteBrowser({
    required this.palette,
    required this.selectedId,
    required this.onSelected,
  });

  final MattePalette palette;
  final String selectedId;
  final ValueChanged<CanvasSwatch> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = AppTheme.chrome(context);
    final pan = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.mistDark
        : const Color(0xFFE3E1DB);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pan,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chrome),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              children: [
                for (final collection in palette.collections) ...[
                  _CollectionCard(
                    collection: collection,
                    selectedId: selectedId,
                    onSelected: onSelected,
                    onAddSwatch: (group) =>
                        _promptAddSwatch(context, ref, group),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final group in palette.standaloneGroups) ...[
                  _GroupBlock(
                    group: group,
                    selectedId: selectedId,
                    onSelected: onSelected,
                    onAddSwatch: () => _promptAddSwatch(context, ref, group),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: chrome),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _promptAddCollection(context, ref),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                  label: const Text('New collection'),
                ),
                TextButton.icon(
                  onPressed: () => _promptAddGroup(context, ref, palette),
                  icon: const Icon(Icons.folder_outlined, size: 16),
                  label: const Text('New group'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptAddCollection(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(
      context,
      title: 'New collection',
      hint: 'e.g. Film stocks',
      helper:
          'A collection is a bordered folder of groups — like Zone system.',
    );
    if (name == null || name.isEmpty) return;
    await ref.read(mattePaletteProvider.notifier).addCollection(name: name);
  }

  Future<void> _promptAddGroup(
    BuildContext context,
    WidgetRef ref,
    MattePalette palette,
  ) async {
    final collectionIds = <String?>[null, ...palette.collections.map((c) => c.id)];
    final labels = <String>[
      'Standalone (no collection)',
      ...palette.collections.map((c) => c.name),
    ];
    var chosen = collectionIds.first;
    final nameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A group holds related matte chips (e.g. Zone VIII or Taupes).',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.muted(context, 0.6),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'e.g. Warm papers',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: chosen,
                decoration: const InputDecoration(labelText: 'Place in'),
                items: [
                  for (var i = 0; i < collectionIds.length; i++)
                    DropdownMenuItem(
                      value: collectionIds[i],
                      child: Text(labels[i]),
                    ),
                ],
                onChanged: (v) => setLocal(() => chosen = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (ok != true || name.isEmpty) return;
    await ref.read(mattePaletteProvider.notifier).addGroup(
          name: name,
          collectionId: chosen,
        );
  }

  Future<void> _promptAddSwatch(
    BuildContext context,
    WidgetRef ref,
    SwatchGroup group,
  ) async {
    final nameCtrl = TextEditingController();
    final hexCtrl = TextEditingController(text: 'F2F2F0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add matte to ${group.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hexCtrl,
              decoration: const InputDecoration(
                labelText: 'Hex color',
                prefixText: '#',
                hintText: 'RRGGBB',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final hex = hexCtrl.text.trim().replaceFirst('#', '');
    nameCtrl.dispose();
    hexCtrl.dispose();
    if (ok != true || name.isEmpty) return;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null || (hex.length != 6 && hex.length != 8)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a 6-digit hex color (RRGGBB).')),
        );
      }
      return;
    }
    final color = Color(hex.length == 6 ? (0xFF000000 | parsed) : parsed);
    await ref.read(mattePaletteProvider.notifier).addSwatch(
          groupId: group.id,
          name: name,
          color: color,
        );
  }
}

Future<String?> _promptName(
  BuildContext context, {
  required String title,
  required String hint,
  String? helper,
}) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (helper != null) ...[
            Text(
              helper,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.muted(context, 0.6),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: ctrl,
            decoration: InputDecoration(hintText: hint),
            autofocus: true,
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  final text = ctrl.text.trim();
  ctrl.dispose();
  if (ok != true || text.isEmpty) return null;
  return text;
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.selectedId,
    required this.onSelected,
    required this.onAddSwatch,
  });

  final SwatchCollection collection;
  final String selectedId;
  final ValueChanged<CanvasSwatch> onSelected;
  final ValueChanged<SwatchGroup> onAddSwatch;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppTheme.elevatedDark : const Color(0xFFF7F6F3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: dark ? AppTheme.mistDark : const Color(0xFFC9C5BC),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              collection.name,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (collection.description != null) ...[
              const SizedBox(height: 2),
              Text(
                collection.description!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted(context, 0.5),
                ),
              ),
            ],
            const SizedBox(height: 8),
            for (final group in collection.groups) ...[
              _GroupBlock(
                group: group,
                selectedId: selectedId,
                onSelected: onSelected,
                onAddSwatch: () => onAddSwatch(group),
                compact: true,
              ),
              const SizedBox(height: 10),
            ],
            if (collection.groups.isEmpty)
              Text(
                'No groups yet — use New group to add one here.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted(context, 0.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.group,
    required this.selectedId,
    required this.onSelected,
    required this.onAddSwatch,
    this.compact = false,
  });

  final SwatchGroup group;
  final String selectedId;
  final ValueChanged<CanvasSwatch> onSelected;
  final VoidCallback onAddSwatch;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                  if (group.description != null)
                    Text(
                      group.description!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.muted(context, 0.5),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Add matte color',
              onPressed: onAddSwatch,
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final swatch in group.swatches)
              _SwatchChip(
                swatch: swatch,
                selected: swatch.id == selectedId,
                onTap: () => onSelected(swatch),
              ),
            if (group.swatches.isEmpty)
              Text(
                'Empty group',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted(context, 0.4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SwatchChip extends StatelessWidget {
  const _SwatchChip({
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  final CanvasSwatch swatch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = swatch.color.computeLuminance() < 0.35;
    return Tooltip(
      message: swatch.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: swatch.color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? AppTheme.accent : AppTheme.chrome(context),
              width: selected ? 2.5 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  size: 16,
                  color: isDark ? Colors.white : AppTheme.ink,
                )
              : null,
        ),
      ),
    );
  }
}
