import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/canvas_config.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';

class ImageThumbnailGrid extends StatelessWidget {
  const ImageThumbnailGrid({
    super.key,
    required this.items,
    required this.config,
    required this.selectedId,
    required this.onSelect,
    required this.onReorder,
    this.onToggleIncluded,
    this.canToggle = true,
  });

  static const double thumbSize = 72;

  final List<ThumbItem> items;
  final CanvasConfig config;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;
  /// When set, each row shows a checkbox to include/exclude from the layout.
  final void Function(String id, bool included)? onToggleIncluded;
  final bool canToggle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Add photos to use in layouts',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.muted(context, 0.45)),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      // Custom leading handle — disable the default trailing one or rows overflow.
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = item.id == selectedId;
        final dimmed = onToggleIncluded != null && !item.included;
        return Padding(
          key: ValueKey(item.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: Opacity(
            opacity: dimmed ? 0.45 : 1,
            child: InkWell(
              onTap: () => onSelect(item.id),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Icon(Icons.drag_handle, size: 18),
                    ),
                  ),
                  if (onToggleIncluded != null)
                    Checkbox(
                      value: item.included,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: !canToggle
                          ? null
                          : (value) {
                              if (value == null) return;
                              onToggleIncluded!(item.id, value);
                            },
                    ),
                  SizedBox(
                    width: thumbSize,
                    height: thumbSize,
                    child: item.image == null
                        ? null
                        : RawImage(
                            image: item.image,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
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
    this.photo,
    this.included = true,
  });

  final String id;
  final String label;
  /// Decoded source bitmap (shared with the live art canvas).
  final ui.Image? image;
  final PhotoItem? photo;
  /// Whether this source is placed on the active layout.
  final bool included;
}
