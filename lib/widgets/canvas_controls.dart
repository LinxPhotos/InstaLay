import 'package:flutter/material.dart';

import '../models/aspect_presets.dart';
import '../models/canvas_config.dart';
import '../models/export_codec.dart';
import '../models/paper_texture.dart';
import '../models/resample_algorithm.dart';
import '../theme/app_theme.dart';
import 'color_swatch_picker.dart';

class CanvasControls extends StatelessWidget {
  const CanvasControls({
    super.key,
    required this.config,
    required this.locked,
    required this.onChanged,
    this.onOpenCodecSettings,
  });

  final CanvasConfig config;
  final bool locked;
  final ValueChanged<CanvasConfig> onChanged;
  final VoidCallback? onOpenCodecSettings;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: locked,
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (locked)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'This version is frozen after posting to Instagram. Clone it to keep editing.',
                  style: TextStyle(color: AppTheme.warn.withValues(alpha: 0.9), fontSize: 12),
                ),
              ),
            _section('Aspect ratio'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final preset in AspectPreset.all)
                  ChoiceChip(
                    label: Text(preset.label),
                    selected: config.aspect.id == preset.id,
                    onSelected: (_) => onChanged(config.copyWith(aspect: preset)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _section('Layout mode'),
            SegmentedButton<LayoutMode>(
              segments: const [
                ButtonSegment(
                  value: LayoutMode.batch,
                  label: Text('Batch'),
                  icon: Icon(Icons.grid_view_outlined, size: 16),
                ),
                ButtonSegment(
                  value: LayoutMode.tapestry,
                  label: Text('Tapestry'),
                  icon: Icon(Icons.view_carousel_outlined, size: 16),
                ),
              ],
              selected: {config.layoutMode},
              onSelectionChanged: (s) =>
                  onChanged(config.copyWith(layoutMode: s.first)),
            ),
            if (config.layoutMode == LayoutMode.tapestry) ...[
              const SizedBox(height: 8),
              Text(
                'SCRL-style panorama: photos stitch left→right, then slice into '
                '${config.aspect.ratioLabel} carousel frames.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.ink.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 8),
              Text('Gap between frames: ${config.tapestryGapPx}px'),
              Slider(
                value: config.tapestryGapPx.toDouble(),
                min: 0,
                max: 120,
                divisions: 24,
                onChanged: (v) =>
                    onChanged(config.copyWith(tapestryGapPx: v.round())),
              ),
            ],
            const SizedBox(height: 16),
            _section('Border (pixels)'),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: config.borderPx.toDouble().clamp(0, 400),
                    min: 0,
                    max: 400,
                    divisions: 80,
                    label: '${config.borderPx}px',
                    onChanged: (v) =>
                        onChanged(config.copyWith(borderPx: v.round())),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text('${config.borderPx}px', textAlign: TextAlign.end),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _section('Fit'),
            Wrap(
              spacing: 6,
              children: [
                for (final mode in FitMode.values)
                  ChoiceChip(
                    label: Text(mode.name),
                    selected: config.fitMode == mode,
                    onSelected: (_) => onChanged(config.copyWith(fitMode: mode)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _section('Background matte'),
            SizedBox(
              height: 220,
              child: ColorSwatchPicker(
                selectedId: config.swatch.id,
                onSelected: (s) => onChanged(config.copyWith(swatch: s)),
              ),
            ),
            const SizedBox(height: 16),
            _section('Paper texture'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in PaperTexture.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: config.texture == t,
                    onSelected: (_) => onChanged(config.copyWith(texture: t)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _section('Thumbnail resampling'),
            DropdownButtonFormField<ResampleAlgorithm>(
              initialValue: config.thumbnailAlgorithm,
              items: [
                for (final a in ResampleAlgorithm.values)
                  DropdownMenuItem(value: a, child: Text(a.label)),
              ],
              onChanged: (a) {
                if (a != null) {
                  onChanged(config.copyWith(thumbnailAlgorithm: a));
                }
              },
            ),
            const SizedBox(height: 12),
            _section('Export resampling'),
            DropdownButtonFormField<ResampleAlgorithm>(
              initialValue: config.exportAlgorithm,
              items: [
                for (final a in ResampleAlgorithm.values)
                  DropdownMenuItem(value: a, child: Text(a.label)),
              ],
              onChanged: (a) {
                if (a != null) {
                  onChanged(config.copyWith(exportAlgorithm: a));
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              config.exportAlgorithm.description,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.ink.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            _section('Export long edge'),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: config.exportLongEdge.toDouble().clamp(720, 2160),
                    min: 720,
                    max: 2160,
                    divisions: 12,
                    label: '${config.exportLongEdge}px',
                    onChanged: (v) =>
                        onChanged(config.copyWith(exportLongEdge: v.round())),
                  ),
                ),
                Text('${config.exportLongEdge}px'),
              ],
            ),
            const SizedBox(height: 16),
            _section('Export codec'),
            Text(
              '${config.codec.format.label}'
              '${config.codec.format == ExportFormat.jpeg ? ' · q${config.codec.jpegQuality}' : ''}'
              '${config.codec.format == ExportFormat.jpegXl ? ' · ${config.codec.jxlMode == JxlMode.lossless ? 'lossless' : 'q${config.codec.jxlQuality}'}' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.ink.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: locked ? null : onOpenCodecSettings,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Codec settings & compare'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
