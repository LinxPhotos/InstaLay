import 'dart:io';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../theme/app_theme.dart';

/// List row identity: framed layout-aspect thumbnail + project metadata.
class ProjectListTile extends StatelessWidget {
  const ProjectListTile({
    super.key,
    required this.project,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
    this.onRename,
    this.thumbHeight = 72,
  });

  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback? onRename;
  final double thumbHeight;

  @override
  Widget build(BuildContext context) {
    final version = project.activeVersion;
    final layout = version?.identityLayout ?? version?.activeLayout;
    final frozen = version?.frozen == true;
    final thumbPath = version?.previewThumbPath;
    final photoCount = version?.allPhotos.length ?? 0;
    final layoutCount = version?.layouts.length ?? 0;
    final aspect = layout?.config.aspect ?? version?.config.aspect;
    final ratio = aspect?.ratioLabel ?? '4:5';
    final aspectRatio = aspect?.ratio ?? (4 / 5);
    // Height-locked; width follows the layout canvas aspect (e.g. 4:5 → ~58×72).
    final thumbWidth = thumbHeight * aspectRatio;

    final scheme = Theme.of(context).colorScheme;
    final matte = layout?.config.swatch.color ??
        version?.config.swatch.color ??
        AppTheme.mist;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: InkWell(
        onTap: onOpen,
        onLongPress: onRename,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: thumbHeight,
                width: thumbWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: _Thumb(
                      path: thumbPath,
                      matte: matte,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (version != null) version.label ?? 'v${version.versionNumber}',
                        ratio,
                        '$layoutCount layout${layoutCount == 1 ? '' : 's'}',
                        '$photoCount photo${photoCount == 1 ? '' : 's'}',
                        if (frozen) 'posted',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted(context, 0.55),
                      ),
                    ),
                  ],
                ),
              ),
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
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.path,
    required this.matte,
  });

  final String? path;
  final Color matte;

  @override
  Widget build(BuildContext context) {
    if (path != null && File(path!).existsSync()) {
      return Image.file(
        File(path!),
        key: ValueKey(path),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    // Prefer a muted fill when the matte is near-white so empty projects
    // don't read as a broken blank tile.
    final luminance = matte.computeLuminance();
    final fill = luminance > 0.85
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : matte;
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
