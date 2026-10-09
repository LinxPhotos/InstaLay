import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/source_file_bytes.dart';
import '../services/stored_path.dart';
import '../theme/app_theme.dart';

/// Home list row: title + metadata on top, layout preview strip underneath.
class ProjectListTile extends StatelessWidget {
  const ProjectListTile({
    super.key,
    required this.project,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
    this.onRename,
    this.thumbHeight = 72,
    this.thumbRendering = false,
  });

  final Project project;
  final bool thumbRendering;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback? onRename;
  final double thumbHeight;

  static const double _multiLayoutThumbHeight = 56;
  static const double _previewGap = 8;

  @override
  Widget build(BuildContext context) {
    final version = project.activeVersion;
    final frozen = version?.frozen == true;
    final photoCount = version?.allPhotos.length ?? 0;
    final layoutCount = version?.layouts.length ?? 0;
    final identityLayout = version?.identityLayout;
    final sharedThumbPath = version?.previewThumbPath;

    final previewLayouts = version == null
        ? const <LayoutCanvas>[]
        : [
            for (final layout in version.layouts)
              if (layout.photos.isNotEmpty || layout.texts.isNotEmpty) layout,
          ];

    final fallbackLayout =
        identityLayout ??
            version?.activeLayout ??
            (previewLayouts.isEmpty ? null : previewLayouts.first);
    final metaAspect = fallbackLayout?.config.aspect ?? version?.config.aspect;
    final ratio = metaAspect?.ratioLabel ?? '4:5';

    final metaLine = [
      if (version != null) version.label ?? 'v${version.versionNumber}',
      ratio,
      '$layoutCount layout${layoutCount == 1 ? '' : 's'}',
      '$photoCount photo${photoCount == 1 ? '' : 's'}',
      if (frozen) 'posted',
    ].join(' · ');

    final scheme = Theme.of(context).colorScheme;
    final stripHeight = previewLayouts.length > 1
        ? _multiLayoutThumbHeight
        : thumbHeight;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: InkWell(
        onTap: onOpen,
        onLongPress: onRename,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          project.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          metaLine,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppTheme.muted(context, 0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _PreviewStrip(
                      layouts: previewLayouts,
                      fallbackLayout: fallbackLayout,
                      sharedThumbPath: sharedThumbPath,
                      identityLayoutId: identityLayout?.id,
                      stripHeight: stripHeight,
                      thumbRendering: thumbRendering,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onRename != null)
                    IconButton(
                      tooltip: 'Rename',
                      onPressed: onRename,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                  IconButton(
                    tooltip: 'Post to Instagram',
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppTheme.muted(context, 0.45),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewStrip extends StatelessWidget {
  const _PreviewStrip({
    required this.layouts,
    required this.fallbackLayout,
    required this.sharedThumbPath,
    required this.identityLayoutId,
    required this.stripHeight,
    required this.thumbRendering,
  });

  final List<LayoutCanvas> layouts;
  final LayoutCanvas? fallbackLayout;
  final String? sharedThumbPath;
  final String? identityLayoutId;
  final double stripHeight;
  final bool thumbRendering;

  @override
  Widget build(BuildContext context) {
    if (layouts.isEmpty) {
      final aspect = fallbackLayout?.config.aspect.ratio ?? (4 / 5);
      final matte = fallbackLayout?.config.swatch.color ?? AppTheme.mist;
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: stripHeight,
          width: stripHeight * aspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: _Thumb(
              path: sharedThumbPath,
              matte: matte,
              rendering: thumbRendering,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < layouts.length; i++) ...[
            if (i > 0) const SizedBox(width: ProjectListTile._previewGap),
            _layoutPreview(context, layouts[i]),
          ],
        ],
      ),
    );
  }

  Widget _layoutPreview(BuildContext context, LayoutCanvas layout) {
    final aspect = layout.config.aspect.ratio;
    final matte = layout.config.swatch.color;
    final isIdentity = layout.id == identityLayoutId;
    final path = isIdentity ? sharedThumbPath : null;
    final rendering = thumbRendering && isIdentity;
    return SizedBox(
      height: stripHeight,
      width: stripHeight * aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: _Thumb(
          path: path,
          matte: matte,
          rendering: rendering,
        ),
      ),
    );
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({
    required this.path,
    required this.matte,
    required this.rendering,
  });

  final String? path;
  final Color matte;
  final bool rendering;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _Thumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        (oldWidget.rendering && !widget.rendering)) {
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    if (path == null) {
      setState(() => _bytes = null);
      return;
    }
    if (!await storedPathExists(path)) {
      if (mounted) setState(() => _bytes = null);
      return;
    }
    try {
      final bytes = await readSourceFileBytes(path);
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) setState(() => _bytes = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rendering) {
      return _RenderingThumbPlaceholder(matte: widget.matte);
    }
    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(
        _bytes!,
        key: ValueKey(widget.path),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final luminance = widget.matte.computeLuminance();
    final fill = luminance > 0.85
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : widget.matte;
    return ColoredBox(
      color: fill,
      child: Center(
        child: Icon(
          Icons.photo_library_outlined,
          color: AppTheme.muted(context, 0.35),
        ),
      ),
    );
  }
}

/// Matte fill + pulsing shimmer while a background isolate renders the thumb.
class _RenderingThumbPlaceholder extends StatefulWidget {
  const _RenderingThumbPlaceholder({required this.matte});

  final Color matte;

  @override
  State<_RenderingThumbPlaceholder> createState() =>
      _RenderingThumbPlaceholderState();
}

class _RenderingThumbPlaceholderState extends State<_RenderingThumbPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luminance = widget.matte.computeLuminance();
    final base = luminance > 0.85
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : widget.matte;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ColoredBox(
          color: Color.lerp(base, scheme.primary.withValues(alpha: 0.12), t)!,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                  color: scheme.primary.withValues(alpha: 0.45 + t * 0.25),
                ),
              ),
              Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      AppTheme.muted(context, 0.5 + t * 0.2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
