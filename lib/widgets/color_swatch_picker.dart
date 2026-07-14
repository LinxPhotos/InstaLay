import 'package:flutter/material.dart';

import '../models/color_swatches.dart';
import '../theme/app_theme.dart';

class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final ValueChanged<CanvasSwatch> onSelected;

  @override
  Widget build(BuildContext context) {
    final grouped = CanvasSwatchCatalog.byZone;
    final zones = PhotoZone.values.where((z) => grouped.containsKey(z)).toList();

    return ListView(
      children: [
        for (final zone in zones) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.label,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  zone.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final swatch in grouped[zone]!)
                _SwatchChip(
                  swatch: swatch,
                  selected: swatch.id == selectedId,
                  onTap: () => onSelected(swatch),
                ),
            ],
          ),
        ],
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
              color: selected ? AppTheme.accent : AppTheme.mist,
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
