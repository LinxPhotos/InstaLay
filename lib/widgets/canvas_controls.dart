import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/aspect_presets.dart';
import '../models/canvas_config.dart';
import '../models/paper_texture.dart';
import '../models/photo_border_sync.dart';
import '../models/project.dart';
import '../models/resample_algorithm.dart';
import '../theme/app_theme.dart';
import 'color_swatch_picker.dart';
import 'paper_texture_preview.dart';
import 'tapestry_layer_browser.dart';

class CanvasControls extends StatelessWidget {
  const CanvasControls({
    super.key,
    required this.config,
    required this.locked,
    required this.onChanged,
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
    this.onPhotoBordersChanged,
  });

  final CanvasConfig config;
  final bool locked;
  final ValueChanged<CanvasConfig> onChanged;

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
  final void Function(List<PhotoItem> photos, CanvasConfig config)?
      onPhotoBordersChanged;

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
                  'This version is frozen (marked as posted). Unlock or clone it to keep editing.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.9), fontSize: 12),
                ),
              ),
            _section(
              context,
              config.layoutMode == LayoutMode.tapestry
                  ? 'Frame aspect'
                  : 'Aspect ratio',
            ),
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
              const SizedBox(height: 12),
              _section(context, 'Tile aspect'),
              Text(
                'Shape of each photo tile in the strip. Native keeps each '
                'photo’s own ratio.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted(context, 0.55),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Native'),
                    selected: config.tapestryTileAspect == null,
                    onSelected: (_) => onChanged(
                      config.copyWith(clearTapestryTileAspect: true),
                    ),
                  ),
                  for (final preset in AspectPreset.all)
                    ChoiceChip(
                      label: Text(preset.label),
                      selected: config.tapestryTileAspect?.id == preset.id,
                      onSelected: (_) => onChanged(
                        config.copyWith(tapestryTileAspect: preset),
                      ),
                    ),
                ],
              ),
              if (config.tapestryTileAspect != null) ...[
                const SizedBox(height: 8),
                _section(context, 'Tile fit'),
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
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final gapEnabled = layerPhotos.length >= 2 &&
                      layerPhotos.any((p) => p.tapestryUsesFlowGap);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Gap between photos: ${config.tapestryGapPx}px'),
                      if (!gapEnabled)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            layerPhotos.length < 2
                                ? 'Add at least two photos to space them apart.'
                                : 'All photos are manually positioned — gap applies only to flow-layout tiles.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.muted(context, 0.55),
                            ),
                          ),
                        ),
                      Slider(
                        value: config.tapestryGapPx.toDouble(),
                        min: 0,
                        max: 120,
                        divisions: 24,
                        onChanged: gapEnabled
                            ? (v) => onChanged(
                                  config.copyWith(tapestryGapPx: v.round()),
                                )
                            : null,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _section(context, 'Layers'),
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
                _section(context, 'Text'),
                _TextSettingsPanel(
                  text: selectedText!,
                  locked: locked,
                  onChanged: onTextChanged!,
                ),
              ],
              if (selectedPhotoId != null &&
                  onPhotoBordersChanged != null) ...[
                const SizedBox(height: 16),
                _section(context, 'Photo border'),
                _PhotoBorderPanel(
                  config: config,
                  photos: layerPhotos,
                  selectedPhotoId: selectedPhotoId!,
                  locked: locked,
                  onChanged: onPhotoBordersChanged!,
                ),
              ],
            ],
            const SizedBox(height: 16),
            _section(context, 'Frame inset (pixels)'),
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
              _section(context, 'Fit'),
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
            _section(context, 'Background mat'),
            SizedBox(
              height: 280,
              child: ColorSwatchPicker(
                selectedId: config.swatch.id,
                onSelected: (s) => onChanged(config.copyWith(swatch: s)),
              ),
            ),
            const SizedBox(height: 16),
            _section(context, 'Paper texture'),
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
            const SizedBox(height: 8),
            PaperTexturePreview(
              texture: config.texture,
              color: config.swatch.color,
            ),
            const SizedBox(height: 16),
            _section(context, 'Photo drop shadow'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Enable shadow'),
              value: config.photoDropShadowEnabled,
              onChanged: (v) =>
                  onChanged(config.copyWith(photoDropShadowEnabled: v)),
            ),
            if (config.photoDropShadowEnabled) ...[
              Text(
                'Opacity: ${(config.photoDropShadowOpacity * 100).round()}%',
              ),
              Slider(
                value: config.photoDropShadowOpacity.clamp(0.05, 0.6),
                min: 0.05,
                max: 0.6,
                divisions: 11,
                onChanged: (v) =>
                    onChanged(config.copyWith(photoDropShadowOpacity: v)),
              ),
              Text('Blur: ${config.photoDropShadowBlur.toStringAsFixed(1)}'),
              Slider(
                value: config.photoDropShadowBlur.clamp(0, 24),
                min: 0,
                max: 24,
                divisions: 24,
                onChanged: (v) =>
                    onChanged(config.copyWith(photoDropShadowBlur: v)),
              ),
              Text(
                'Offset X: ${config.photoDropShadowOffsetX.toStringAsFixed(1)} · '
                'Y: ${config.photoDropShadowOffsetY.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted(context, 0.55),
                ),
              ),
              Slider(
                value: config.photoDropShadowOffsetX.clamp(-24, 24),
                min: -24,
                max: 24,
                divisions: 48,
                label: 'X',
                onChanged: (v) =>
                    onChanged(config.copyWith(photoDropShadowOffsetX: v)),
              ),
              Slider(
                value: config.photoDropShadowOffsetY.clamp(-24, 24),
                min: -24,
                max: 24,
                divisions: 48,
                label: 'Y',
                onChanged: (v) =>
                    onChanged(config.copyWith(photoDropShadowOffsetY: v)),
              ),
            ],
            const SizedBox(height: 16),
            _section(context, 'Thumbnail resampling'),
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
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
      ),
    );
  }
}

class _PhotoBorderPanel extends StatelessWidget {
  const _PhotoBorderPanel({
    required this.config,
    required this.photos,
    required this.selectedPhotoId,
    required this.locked,
    required this.onChanged,
  });

  final CanvasConfig config;
  final List<PhotoItem> photos;
  final String selectedPhotoId;
  final bool locked;
  final void Function(List<PhotoItem> photos, CanvasConfig config) onChanged;

  static const _colors = <int>[
    0xFFFFFFFF,
    0xFF000000,
    0xFFF2F2F0,
    0xFFE8E2DA,
    0xFF2F6FED,
    0xFFE74C3C,
  ];

  PhotoItem? get _selected {
    for (final p in photos) {
      if (p.id == selectedPhotoId) return p;
    }
    return null;
  }

  void _edit({
    double? borderPx,
    int? borderColorArgb,
    bool? syncPhotoBorderPx,
    bool? syncPhotoBorderColor,
  }) {
    final photo = _selected;
    if (photo == null) return;
    final result = PhotoBorderSync.apply(
      config: config,
      photos: photos,
      photoId: photo.id,
      borderPx: borderPx,
      borderColorArgb: borderColorArgb,
      syncPhotoBorderPx: syncPhotoBorderPx,
      syncPhotoBorderColor: syncPhotoBorderColor,
    );
    onChanged(result.photos, result.config);
  }

  @override
  Widget build(BuildContext context) {
    final photo = _selected;
    if (photo == null) {
      return Text(
        'Select a photo to edit its border.',
        style: TextStyle(fontSize: 11, color: AppTheme.muted(context, 0.55)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Per-photo outset mat on this canvas. Sync applies size or color '
          'to every photo here; turn sync off in Photo properties for one-off borders.',
          style: TextStyle(fontSize: 11, color: AppTheme.muted(context, 0.55)),
        ),
        const SizedBox(height: 8),
        Text('Size: ${photo.borderPx.round()}px'),
        Slider(
          value: photo.borderPx.clamp(0, PhotoBorderSync.maxBorderPx),
          min: 0,
          max: PhotoBorderSync.maxBorderPx,
          divisions: 40,
          onChanged: locked ? null : (v) => _edit(borderPx: v),
        ),
        Row(
          children: [
            const Text('Color'),
            const SizedBox(width: 12),
            for (final c in _colors)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: locked ? null : () => _edit(borderColorArgb: c),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Color(c),
                      border: Border.all(
                        color: photo.borderColorArgb == c
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black26,
                        width: photo.borderColorArgb == c ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Sync size'),
          subtitle: Text(
            config.syncPhotoBorderPx
                ? 'All photos on this canvas share border size'
                : 'Border size is per photo',
            style: TextStyle(fontSize: 11, color: AppTheme.muted(context, 0.55)),
          ),
          value: config.syncPhotoBorderPx,
          onChanged: locked ? null : (v) => _edit(syncPhotoBorderPx: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Sync color'),
          subtitle: Text(
            config.syncPhotoBorderColor
                ? 'All photos on this canvas share border color'
                : 'Border color is per photo',
            style: TextStyle(fontSize: 11, color: AppTheme.muted(context, 0.55)),
          ),
          value: config.syncPhotoBorderColor,
          onChanged: locked ? null : (v) => _edit(syncPhotoBorderColor: v),
        ),
      ],
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
