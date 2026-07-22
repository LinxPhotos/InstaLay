import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/aspect_presets.dart';
import '../models/canvas_config.dart';
import '../models/export_codec.dart';
import '../models/paper_texture.dart';
import '../models/project.dart';
import '../models/resample_algorithm.dart';
import '../theme/app_theme.dart';
import 'color_swatch_picker.dart';
import 'tapestry_layer_browser.dart';

class CanvasControls extends StatelessWidget {
  const CanvasControls({
    super.key,
    required this.config,
    required this.locked,
    required this.onChanged,
    this.onOpenCodecSettings,
    this.layerPhotos = const [],
    this.layerTexts = const [],
    this.layerImages = const {},
    this.selectedPhotoId,
    this.selectedTextId,
    this.selectedText,
    this.onSelectPhoto,
    this.onSelectText,
    this.onSelectLayer,
    this.onReorderLayers,
    this.onRaiseLayer,
    this.onLowerLayer,
    this.onBringLayerToFront,
    this.onSendLayerToBack,
    this.onTextChanged,
  });

  final CanvasConfig config;
  final bool locked;
  final ValueChanged<CanvasConfig> onChanged;
  final VoidCallback? onOpenCodecSettings;

  /// Tapestry-only layer browser inputs (ignored for batch).
  final List<PhotoItem> layerPhotos;
  final List<TextItem> layerTexts;
  final Map<String, ui.Image> layerImages;
  final String? selectedPhotoId;
  final String? selectedTextId;
  final TextItem? selectedText;
  final ValueChanged<String>? onSelectPhoto;
  final ValueChanged<String>? onSelectText;
  final ValueChanged<TapestryLayerRef>? onSelectLayer;
  final void Function(int oldIndex, int newIndex)? onReorderLayers;
  final VoidCallback? onRaiseLayer;
  final VoidCallback? onLowerLayer;
  final VoidCallback? onBringLayerToFront;
  final VoidCallback? onSendLayerToBack;
  final ValueChanged<TextItem>? onTextChanged;

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
                  style: TextStyle(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.9), fontSize: 12),
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
            _section('Layout type'),
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
            const SizedBox(height: 6),
            Text(
              'Projects can mix batch and tapestry layouts. '
              'Use Add layout to create another.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.muted(context, 0.55),
              ),
            ),
            if (config.layoutMode == LayoutMode.tapestry) ...[
              const SizedBox(height: 8),
              Text(
                'SCRL-style panorama: photos stitch left→right, then slice into '
                '${config.aspect.ratioLabel} carousel frames.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted(context, 0.55),
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
              const SizedBox(height: 12),
              _section('Layers'),
              Text(
                'Left = back, right = front. Drag to reorder stacking, '
                'or use [ ] / Page Up·Down / Home·End.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted(context, 0.55),
                ),
              ),
              const SizedBox(height: 6),
              TapestryLayerBrowser(
                photos: layerPhotos,
                texts: layerTexts,
                images: layerImages,
                selectedId: selectedPhotoId ?? selectedTextId,
                locked: locked,
                onSelect: (layer) {
                  if (onSelectLayer != null) {
                    onSelectLayer!(layer);
                    return;
                  }
                  if (layer.isPhoto) {
                    onSelectPhoto?.call(layer.id);
                  } else {
                    onSelectText?.call(layer.id);
                  }
                },
                onReorder: onReorderLayers ?? (_, _) {},
                onRaise: onRaiseLayer ?? () {},
                onLower: onLowerLayer ?? () {},
                onBringToFront: onBringLayerToFront ?? () {},
                onSendToBack: onSendLayerToBack ?? () {},
              ),
              if (selectedText != null && onTextChanged != null) ...[
                const SizedBox(height: 16),
                _section('Text'),
                _TextSettingsPanel(
                  text: selectedText!,
                  locked: locked,
                  onChanged: onTextChanged!,
                ),
              ],
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
            if (config.layoutMode == LayoutMode.batch) ...[
              const SizedBox(height: 8),
              _section('Fit'),
              Wrap(
                spacing: 6,
                children: [
                  for (final mode in FitMode.values)
                    ChoiceChip(
                      label: Text(mode.name),
                      selected: config.fitMode == mode,
                      onSelected: (_) =>
                          onChanged(config.copyWith(fitMode: mode)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _section('Background matte'),
            SizedBox(
              height: 280,
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
                color: AppTheme.muted(context, 0.5),
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
                color: AppTheme.muted(context, 0.65),
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

class _TextSettingsPanel extends StatefulWidget {
  const _TextSettingsPanel({
    required this.text,
    required this.locked,
    required this.onChanged,
  });

  final TextItem text;
  final bool locked;
  final ValueChanged<TextItem> onChanged;

  @override
  State<_TextSettingsPanel> createState() => _TextSettingsPanelState();
}

class _TextSettingsPanelState extends State<_TextSettingsPanel> {
  late final TextEditingController _content;
  late final TextEditingController _font;
  late final TextEditingController _size;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.text.text);
    _font = TextEditingController(text: widget.text.fontFamily);
    _size = TextEditingController(
      text: widget.text.fontSize.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(covariant _TextSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text.id != widget.text.id ||
        oldWidget.text.text != widget.text.text) {
      _content.text = widget.text.text;
    }
    if (oldWidget.text.fontFamily != widget.text.fontFamily) {
      _font.text = widget.text.fontFamily;
    }
    if (oldWidget.text.fontSize != widget.text.fontSize) {
      _size.text = widget.text.fontSize.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _content.dispose();
    _font.dispose();
    _size.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _content,
          enabled: !widget.locked,
          decoration: const InputDecoration(
            labelText: 'Content',
            isDense: true,
          ),
          maxLines: 3,
          onChanged: (v) => widget.onChanged(t.copyWith(text: v)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _font,
          enabled: !widget.locked,
          decoration: const InputDecoration(
            labelText: 'Font family',
            isDense: true,
          ),
          onChanged: (v) => widget.onChanged(t.copyWith(fontFamily: v)),
        ),
        const SizedBox(height: 8),
        Text('Size: ${t.fontSize.round()}px'),
        Slider(
          value: t.fontSize.clamp(8, 240),
          min: 8,
          max: 240,
          divisions: 58,
          onChanged: widget.locked
              ? null
              : (v) => widget.onChanged(t.copyWith(fontSize: v)),
        ),
        Text('Weight: ${t.fontWeight}'),
        Slider(
          value: t.fontWeight.toDouble().clamp(100, 900),
          min: 100,
          max: 900,
          divisions: 8,
          onChanged: widget.locked
              ? null
              : (v) => widget.onChanged(
                    t.copyWith(fontWeight: (v / 100).round() * 100),
                  ),
        ),
        Row(
          children: [
            const Text('Color'),
            const SizedBox(width: 12),
            for (final c in const [
              0xFF000000,
              0xFFFFFFFF,
              0xFF2F6FED,
              0xFFE74C3C,
              0xFF27AE60,
            ])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: widget.locked
                      ? null
                      : () => widget.onChanged(t.copyWith(colorArgb: c)),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Color(c),
                      border: Border.all(
                        color: t.colorArgb == c
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black26,
                        width: t.colorArgb == c ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
