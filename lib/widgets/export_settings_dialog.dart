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
  late final bool _hasTransparentPixels;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _settings = widget.initial;
    _beforeBytes = widget.uncodedPreviewBytes;
    _hasTransparentPixels =
        ImageCodecService.hasTransparentPixels(widget.sampleImage);
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
              hasTransparentPixels: _hasTransparentPixels,
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
    this.hasTransparentPixels = false,
  });

  final ExportCodecSettings settings;
  final ValueChanged<ExportCodecSettings> onChanged;
  final SizeEstimate? estimate;
  final bool dense;

  /// When true and the chosen format lacks alpha, show a flatten notice.
  final bool hasTransparentPixels;

  @override
  Widget build(BuildContext context) {
    final alphaUnsupported =
        hasTransparentPixels && !settings.format.supportsAlpha;
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
        if (alphaUnsupported) ...[
          const SizedBox(height: 10),
          Text(
            '${settings.format.label} has no alpha channel — transparent '
            'matte areas will flatten to white. Use PNG, WebP, AVIF, or '
            'JPEG XL to keep transparency.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.9),
            ),
          ),
        ],
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

/// Result of the pre-export settings dialog.
class ExportSettingsChoice {
  const ExportSettingsChoice({
    required this.codec,
    this.tapestryExportWholeStrip = false,
  });

  final ExportCodecSettings codec;

  /// When the dialog offered the tapestry strip toggle, the chosen value.
  final bool tapestryExportWholeStrip;
}

/// Modal used right before export/share.
///
/// Opens immediately. Pass [sampleFuture] so size estimates load after the
/// first frame — do not await a full render before calling this.
///
/// [slicedFileCount] is the file count when tapestries are chopped into
/// carousel frames. [wholeStripFileCount] is used when
/// [showTapestryStripOption] is on and the user chooses a full strip
/// (typically fewer files).
Future<ExportSettingsChoice?> showExportSettingsDialog({
  required BuildContext context,
  required ExportCodecSettings initial,
  required int slicedFileCount,
  int? wholeStripFileCount,
  bool showTapestryStripOption = false,
  bool initialTapestryExportWholeStrip = false,
  img.Image? sampleImage,
  Future<img.Image?>? sampleFuture,
}) {
  return showDialog<ExportSettingsChoice>(
    context: context,
    builder: (ctx) => _ExportSettingsDialog(
      initial: initial,
      sampleImage: sampleImage,
      sampleFuture: sampleFuture,
      slicedFileCount: slicedFileCount,
      wholeStripFileCount: wholeStripFileCount ?? slicedFileCount,
      showTapestryStripOption: showTapestryStripOption,
      initialTapestryExportWholeStrip: initialTapestryExportWholeStrip,
    ),
  );
}

class _ExportSettingsDialog extends StatefulWidget {
  const _ExportSettingsDialog({
    required this.initial,
    required this.slicedFileCount,
    required this.wholeStripFileCount,
    required this.showTapestryStripOption,
    required this.initialTapestryExportWholeStrip,
    this.sampleImage,
    this.sampleFuture,
  });

  final ExportCodecSettings initial;
  final img.Image? sampleImage;
  final Future<img.Image?>? sampleFuture;
  final int slicedFileCount;
  final int wholeStripFileCount;
  final bool showTapestryStripOption;
  final bool initialTapestryExportWholeStrip;

  @override
  State<_ExportSettingsDialog> createState() => _ExportSettingsDialogState();
}

class _ExportSettingsDialogState extends State<_ExportSettingsDialog> {
  late ExportCodecSettings _settings;
  img.Image? _sample;
  SizeEstimate? _perFrame;
  bool _busy = false;
  bool _awaitingSample = false;
  bool _hasTransparentPixels = false;
  late bool _tapestryExportWholeStrip;
  Timer? _debounce;

  int get _fileCount => widget.showTapestryStripOption &&
          _tapestryExportWholeStrip
      ? widget.wholeStripFileCount
      : widget.slicedFileCount;

  @override
  void initState() {
    super.initState();
    _settings = widget.initial;
    _tapestryExportWholeStrip = widget.initialTapestryExportWholeStrip;
    _sample = widget.sampleImage;
    if (_sample != null) {
      _hasTransparentPixels =
          ImageCodecService.hasTransparentPixels(_sample!);
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
        _hasTransparentPixels = sample != null &&
            ImageCodecService.hasTransparentPixels(sample);
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
    final fileCount = _fileCount.clamp(1, 100000);
    // Total pixels ≈ same whether sliced or one strip; scale from slide sample.
    final total = per == null
        ? null
        : SizeEstimate(
            bytes: per.bytes * widget.slicedFileCount.clamp(1, 100000),
            exact: per.exact,
            format: per.format,
            width: per.width,
            height: per.height,
          );
    final perFile = per == null || total == null
        ? null
        : SizeEstimate(
            bytes: (() {
              final n = (total.bytes / fileCount).round();
              return n < 1 ? 1 : n;
            })(),
            exact: false,
            format: per.format,
            width: per.width,
            height: per.height,
          );
    final stripMode =
        widget.showTapestryStripOption && _tapestryExportWholeStrip;

    return AlertDialog(
      title: const Text('Export settings'),
      content: SizedBox(
        width: 480,
        height: widget.showTapestryStripOption ? 520 : 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            if (per != null && perFile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  stripMode
                      ? (fileCount > 1
                          ? 'Full strip: ${perFile.label}  ·  '
                              'Batch ($fileCount): ${total!.label}'
                          : 'Full strip: ${total!.label}')
                      : 'Per frame: ${per.label}'
                          '${fileCount > 1 ? '  ·  Batch ($fileCount): ${total!.label}' : ''}',
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
            if (widget.showTapestryStripOption)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Export full strip'),
                subtitle: Text(
                  _tapestryExportWholeStrip
                      ? 'One continuous panorama (no carousel chops).'
                      : 'Slice tapestry into carousel frames.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted(context, 0.55),
                  ),
                ),
                value: _tapestryExportWholeStrip,
                onChanged: (v) => setState(() => _tapestryExportWholeStrip = v),
              ),
            Expanded(
              child: ExportCodecControls(
                settings: _settings,
                estimate: per,
                onChanged: _onChanged,
                dense: true,
                hasTransparentPixels: _hasTransparentPixels,
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
          onPressed: () => Navigator.pop(
            context,
            ExportSettingsChoice(
              codec: _settings,
              tapestryExportWholeStrip: widget.showTapestryStripOption &&
                  _tapestryExportWholeStrip,
            ),
          ),
          child: const Text('Export'),
        ),
      ],
    );
  }
}
