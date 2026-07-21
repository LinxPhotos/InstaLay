import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/canvas_config.dart';
import '../theme/app_theme.dart';

class ImageThumbnailGrid extends StatelessWidget {
  const ImageThumbnailGrid({
    super.key,
    required this.items,
    required this.config,
    required this.selectedId,
    required this.onSelect,
    required this.onReorder,
  });

  final List<ThumbItem> items;
  final CanvasConfig config;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Add photos to preview the canvas on each thumbnail',
          style: TextStyle(color: AppTheme.muted(context, 0.45)),
        ),
      );
    }

    final chrome = AppTheme.chrome(context);
    final tileBg = Theme.of(context).colorScheme.surface.withValues(alpha: 0.7);
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = item.id == selectedId;
        return Padding(
          key: ValueKey(item.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => onSelect(item.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? AppTheme.accent : chrome,
                  width: selected ? 2 : 1,
                ),
                color: tileBg,
              ),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle, size: 18),
                    ),
                  ),
                  SizedBox(
                    height: 96,
                    child: AspectRatio(
                      aspectRatio: config.aspect.ratio,
                      child: item.image == null
                          ? ColoredBox(color: config.swatch.color)
                          : RawImage(
                              image: item.image,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ThumbItem {
  const ThumbItem({
    required this.id,
    required this.label,
    this.image,
  });

  final String id;
  final String label;
  final ui.Image? image;
}
