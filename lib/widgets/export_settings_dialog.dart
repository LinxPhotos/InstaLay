import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/export_codec.dart';
import '../services/image_codec_service.dart';
import '../theme/app_theme.dart';
import 'codec_comparison_view.dart';

/// Full-screen codec settings with size estimates and before/after compare.
class ExportCodecSettingsPage extends StatefulWidget {
  const ExportCodecSettingsPage({
    super.key,
    required this.initial,
    required this.sampleImage,
    this.uncodedPreviewBytes,
  });

  final ExportCodecSettings initial;
  final img.Image sampleImage;

  /// PNG/JPEG bytes of the uncompressed (or lightly compressed) canvas for
  /// the left “before” pane. When null, a PNG of [sampleImage] is used.
  final Uint8List? uncodedPreviewBytes;

  @override
  State<ExportCodecSettingsPage> createState() =>
      _ExportCodecSettingsPageState();
}

class _ExportCodecSettingsPageState extends State<ExportCodecSettingsPage> {
  late ExportCodecSettings _settings;
  Uint8List? _beforeBytes;
  Uint8List? _afterBytes;
  SizeEstimate? _estimate;
  bool _encoding = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _settings = widget.initial;
    _beforeBytes = widget.uncodedPreviewBytes;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _beforeBytes ??= Uint8List.fromList(img.encodePng(widget.sampleImage));
    await _reencode();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleEncode(ExportCodecSettings next) {
    setState(() => _settings = next);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _reencode);
  }

  Future<void> _reencode() async {
    setState(() => _encoding = true);
    try {
      final estimate = await ImageCodecService.estimateSize(
        widget.sampleImage,
        _settings,
        maxEstimateEdge: 900,
      );
      final encoded = await ImageCodecService.encode(
        widget.sampleImage,
        _settings,
      );
      // Decode encoded → PNG for preview pane (raster display).
      final decoded = await ImageCodecService.decodeAsync(encoded.bytes);
      Uint8List afterPreview;
      if (decoded != null) {
        afterPreview = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
      } else {
        afterPreview = encoded.bytes;
      }
      if (!mounted) return;
      setState(() {
        _estimate = SizeEstimate(
          bytes: encoded.byteLength,
          exact: true,
          format: _settings.format,
          width: encoded.width,
          height: encoded.height,
        );
        _afterBytes = afterPreview;
        // Keep estimate label from exact encode when ready
        if (!estimate.exact) {
          // already exact from full encode
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Encode failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _encoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export codec settings'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _settings),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_encoding) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  _estimate == null
                      ? 'Calculating size…'
                      : 'Output ${_estimate!.label}'
                          '${_estimate!.exact ? '' : ' (est.)'} · '
                          '${_settings.format.label}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${widget.sampleImage.width}×${widget.sampleImage.height}',
                  style: TextStyle(
                    color: AppTheme.muted(context, 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: _beforeBytes == null || _afterBytes == null
                ? const Center(child: CircularProgressIndicator.adaptive())
                : CodecComparisonView(
                    beforeBytes: _beforeBytes!,
                    afterBytes: _afterBytes!,
                    beforeLabel: 'Before (source canvas)',
                    afterLabel:
                        'After (${_settings.format.label} · ${_estimate?.humanSize ?? '…'})',
                    imageWidth: widget.sampleImage.width,
                    imageHeight: widget.sampleImage.height,
                  ),
          ),
          Expanded(
            flex: 2,
            child: ExportCodecControls(
              settings: _settings,
              estimate: _estimate,
              onChanged: _scheduleEncode,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared controls used by the settings page and the export modal.
class ExportCodecControls extends StatelessWidget {
  const ExportCodecControls({
    super.key,
    required this.settings,
    required this.onChanged,
    this.estimate,
    this.dense = false,
  });

  final ExportCodecSettings settings;
  final ValueChanged<ExportCodecSettings> onChanged;
  final SizeEstimate? estimate;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(dense ? 12 : 16),
      children: [
        if (estimate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Estimated file size: ${estimate!.label}',
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const Text(
          'Format',
          style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in ExportFormat.values)
              ChoiceChip(
                label: Text(f.label),
                selected: settings.format == f,
                onSelected: (_) => onChanged(settings.copyWith(format: f)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (settings.format == ExportFormat.jpeg) ..._jpegControls(),
        if (settings.format == ExportFormat.jpegXl) ..._jxlControls(),
        if (settings.format == ExportFormat.png) ..._pngControls(),
        if (settings.format == ExportFormat.webp) ..._webpControls(context),
        if (settings.format == ExportFormat.avif) ..._avifControls(),
      ],
    );
  }

  List<Widget> _jpegControls() {
    return [
      Text('JPEG quality: ${settings.jpegQuality}'),
      Slider(
        value: settings.jpegQuality.toDouble(),
        min: 1,
        max: 100,
        divisions: 99,
        label: '${settings.jpegQuality}',
        onChanged: (v) =>
            onChanged(settings.copyWith(jpegQuality: v.round())),
      ),
      const Text('Chroma subsampling'),
      Wrap(
        spacing: 6,
        children: [
          for (final c in img.JpegChroma.values)
            ChoiceChip(
              label: Text(c.name),
              selected: settings.jpegChroma == c,
              onSelected: (_) => onChanged(settings.copyWith(jpegChroma: c)),
            ),
        ],
      ),
    ];
  }

  List<Widget> _jxlControls() {
    return [
      const Text('JPEG XL mode'),
      SegmentedButton<JxlMode>(
        segments: [
          for (final m in JxlMode.values)
            ButtonSegment(value: m, label: Text(m.label)),
        ],
        selected: {settings.jxlMode},
        onSelectionChanged: (s) =>
            onChanged(settings.copyWith(jxlMode: s.first)),
      ),
      if (settings.jxlMode == JxlMode.lossy) ...[
        const SizedBox(height: 12),
        Text(
          'Quality: ${settings.jxlQuality}  (distance ${settings.effectiveJxlDistance.toStringAsFixed(2)})',
        ),
        Slider(
          value: settings.jxlQuality.toDouble(),
          min: 1,
          max: 100,
          divisions: 99,
          label: '${settings.jxlQuality}',
          onChanged: (v) => onChanged(
            settings.copyWith(jxlQuality: v.round(), clearJxlDistance: true),
          ),
        ),
        Text(
          'Distance: ${settings.effectiveJxlDistance.toStringAsFixed(2)} (0 ≈ lossless)',
        ),
        Slider(
          value: settings.effectiveJxlDistance.clamp(0, 8),
          min: 0,
          max: 8,
          divisions: 80,
          label: settings.effectiveJxlDistance.toStringAsFixed(2),
          onChanged: (v) => onChanged(settings.copyWith(jxlDistance: v)),
        ),
      ],
    ];
  }

  List<Widget> _pngControls() {
    return [
      Text('PNG compression level: ${settings.pngLevel}'),
      Slider(
        value: settings.pngLevel.toDouble(),
        min: 0,
        max: 9,
        divisions: 9,
        label: '${settings.pngLevel}',
        onChanged: (v) => onChanged(settings.copyWith(pngLevel: v.round())),
      ),
    ];
  }

  List<Widget> _webpControls(BuildContext context) {
    return [
      Text(
        'WebP is encoded lossless with the bundled encoder '
        '(size does not use a quality slider).',
        style: TextStyle(color: AppTheme.muted(context, 0.55), fontSize: 12),
      ),
    ];
  }

  List<Widget> _avifControls() {
    return [
      Text('AVIF quality: ${settings.avifQuality}'),
      Slider(
        value: settings.avifQuality.toDouble(),
        min: 1,
        max: 100,
        divisions: 99,
        onChanged: (v) =>
            onChanged(settings.copyWith(avifQuality: v.round())),
      ),
      Text('Speed: ${settings.avifSpeed} (higher = faster)'),
      Slider(
        value: settings.avifSpeed.toDouble(),
        min: 1,
        max: 10,
        divisions: 9,
        onChanged: (v) =>
            onChanged(settings.copyWith(avifSpeed: v.round())),
      ),
    ];
  }
}

/// Modal used right before export/share.
///
/// Opens immediately. Pass [sampleFuture] so size estimates load after the
/// first frame — do not await a full render before calling this.
Future<ExportCodecSettings?> showExportSettingsDialog({
  required BuildContext context,
  required ExportCodecSettings initial,
  required int frameCount,
  img.Image? sampleImage,
  Future<img.Image?>? sampleFuture,
}) {
  return showDialog<ExportCodecSettings>(
    context: context,
    builder: (ctx) => _ExportSettingsDialog(
      initial: initial,
      sampleImage: sampleImage,
      sampleFuture: sampleFuture,
      frameCount: frameCount,
    ),
  );
}

class _ExportSettingsDialog extends StatefulWidget {
  const _ExportSettingsDialog({
    required this.initial,
    required this.frameCount,
    this.sampleImage,
    this.sampleFuture,
  });

  final ExportCodecSettings initial;
  final img.Image? sampleImage;
  final Future<img.Image?>? sampleFuture;
  final int frameCount;

  @override
  State<_ExportSettingsDialog> createState() => _ExportSettingsDialogState();
}

class _ExportSettingsDialogState extends State<_ExportSettingsDialog> {
  late ExportCodecSettings _settings;
  img.Image? _sample;
  SizeEstimate? _perFrame;
  bool _busy = false;
  bool _awaitingSample = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _settings = widget.initial;
    _sample = widget.sampleImage;
    if (_sample != null) {
      _refreshEstimate();
    } else if (widget.sampleFuture != null) {
      _awaitingSample = true;
      _busy = true;
      unawaited(_resolveSample());
    }
  }

  Future<void> _resolveSample() async {
    try {
      final sample = await widget.sampleFuture;
      if (!mounted) return;
      setState(() {
        _sample = sample;
        _awaitingSample = false;
      });
      if (sample != null) {
        await _refreshEstimate();
      } else if (mounted) {
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _awaitingSample = false;
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(ExportCodecSettings s) {
    setState(() => _settings = s);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _refreshEstimate);
  }

  Future<void> _refreshEstimate() async {
    final sample = _sample;
    if (sample == null) return;
    setState(() => _busy = true);
    try {
      final est = await ImageCodecService.estimateSize(sample, _settings);
      if (!mounted) return;
      setState(() => _perFrame = est);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final per = _perFrame;
    final total = per == null
        ? null
        : SizeEstimate(
            bytes: per.bytes * widget.frameCount,
            exact: per.exact,
            format: per.format,
            width: per.width,
            height: per.height,
          );

    return AlertDialog(
      title: const Text('Export settings'),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            if (per != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Per frame: ${per.label}'
                  '${widget.frameCount > 1 ? '  ·  Batch ($widget.frameCount): ${total!.label}' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              )
            else if (_awaitingSample)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Calculating size…',
                  style: TextStyle(
                    color: AppTheme.muted(context, 0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Expanded(
              child: ExportCodecControls(
                settings: _settings,
                estimate: per,
                onChanged: _onChanged,
                dense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _settings),
          child: const Text('Export'),
        ),
      ],
    );
  }
}
