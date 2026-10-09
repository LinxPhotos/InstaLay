import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tapestry export: carousel slices vs one continuous panorama.
class TapestryExportModeSelector extends StatelessWidget {
  const TapestryExportModeSelector({
    super.key,
    required this.sliceCount,
    required this.wholeStrip,
    required this.onWholeStripChanged,
    this.contentPadding = EdgeInsets.zero,
    this.enabled = true,
  });

  final int sliceCount;
  final bool wholeStrip;
  final ValueChanged<bool> onWholeStripChanged;
  final EdgeInsetsGeometry contentPadding;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final n = sliceCount.clamp(1, 999);
    final muted = TextStyle(
      fontSize: 11,
      color: AppTheme.muted(context, 0.55),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: contentPadding,
          child: Text(
            'Export as',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted(context, 0.75),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: contentPadding,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: false,
                label: Text('$n ${n == 1 ? 'slice' : 'slices'}'),
              ),
              const ButtonSegment<bool>(
                value: true,
                label: Text('Single image'),
              ),
            ],
            selected: {wholeStrip},
            onSelectionChanged: enabled
                ? (selected) {
                    if (selected.isEmpty) return;
                    onWholeStripChanged(selected.first);
                  }
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: contentPadding,
          child: Text(
            wholeStrip
                ? 'One continuous panorama (no carousel chops).'
                : 'One file per carousel frame on export.',
            style: muted,
          ),
        ),
      ],
    );
  }
}
