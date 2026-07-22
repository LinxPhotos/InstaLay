import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../theme/app_theme.dart';

/// Horizontal LTR layer strip for tapestry stacking (left = back, right = front).
/// Includes photos and text objects mixed by [zIndex].
class TapestryLayerBrowser extends StatelessWidget {
  const TapestryLayerBrowser({
    super.key,
    required this.photos,
    required this.texts,
    required this.images,
    required this.selectedId,
    required this.locked,
    required this.onSelect,
    required this.onReorder,
    required this.onRaise,
    required this.onLower,
    required this.onBringToFront,
    required this.onSendToBack,
  });

  static const double thumbSize = 56;

  final List<PhotoItem> photos;
  final List<TextItem> texts;
  final Map<String, ui.Image> images;
  final String? selectedId;
  final bool locked;
  final ValueChanged<TapestryLayerRef> onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onRaise;
  final VoidCallback onLower;
  final VoidCallback onBringToFront;
  final VoidCallback onSendToBack;

  @override
  Widget build(BuildContext context) {
    final layers = TapestryLayerOrder.sorted(photos, texts);
    if (layers.isEmpty) {
      return Text(
        'Add photos or text to manage layer order.',
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.muted(context, 0.5),
        ),
      );
    }

    final selectedIdx =
        selectedId == null ? -1 : layers.indexWhere((l) => l.id == selectedId);
    final canLower = !locked && selectedIdx > 0;
    final canRaise =
        !locked && selectedIdx >= 0 && selectedIdx < layers.length - 1;

    final photoById = {for (final p in photos) p.id: p};
    final textById = {for (final t in texts) t.id: t};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Send to back (End)',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: canLower ? onSendToBack : null,
              icon: const Icon(Icons.flip_to_back),
            ),
            IconButton(
              tooltip: 'Lower [ / Page Down',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: canLower ? onLower : null,
              icon: const Icon(Icons.keyboard_arrow_left),
            ),
            IconButton(
              tooltip: 'Raise ] / Page Up',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: canRaise ? onRaise : null,
              icon: const Icon(Icons.keyboard_arrow_right),
            ),
            IconButton(
              tooltip: 'Bring to front (Home)',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: canRaise ? onBringToFront : null,
              icon: const Icon(Icons.flip_to_front),
            ),
            const Spacer(),
            Text(
              'Back → Front',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.muted(context, 0.45),
              ),
            ),
          ],
        ),
        SizedBox(
          height: thumbSize + 28,
          child: AbsorbPointer(
            absorbing: locked,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: layers.length,
              onReorderItem: locked ? (_, _) {} : onReorder,
              itemBuilder: (context, index) {
                final layer = layers[index];
                final selected = layer.id == selectedId;
                final accent = Theme.of(context).colorScheme.primary;
                final label = layer.isPhoto
                    ? (photoById[layer.id]?.fileName ?? 'Photo')
                    : (textById[layer.id]?.text ?? 'Text');
                final image = layer.isPhoto ? images[layer.id] : null;
                return Padding(
                  key: ValueKey('${layer.kind.name}-${layer.id}'),
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onSelect(layer),
                    borderRadius: BorderRadius.circular(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          enabled: !locked,
                          child: Container(
                            width: thumbSize,
                            height: thumbSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: selected
                                    ? accent
                                    : AppTheme.chrome(context),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: layer.isText
                                ? ColoredBox(
                                    color: AppTheme.muted(context, 0.08),
                                    child: Center(
                                      child: Text(
                                        'T',
                                        style: TextStyle(
                                          fontFamily: 'Georgia',
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          color: textById[layer.id]?.color ??
                                              AppTheme.muted(context, 0.55),
                                        ),
                                      ),
                                    ),
                                  )
                                : image == null
                                    ? ColoredBox(
                                        color: AppTheme.muted(context, 0.08),
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 20,
                                          color: AppTheme.muted(context, 0.35),
                                        ),
                                      )
                                    : RawImage(
                                        image: image,
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.medium,
                                      ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: thumbSize,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: selected
                                  ? accent
                                  : AppTheme.muted(context, 0.65),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
