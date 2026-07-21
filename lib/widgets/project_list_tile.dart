import 'dart:io';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../theme/app_theme.dart';

/// List row identity: thumbnail fills item height and spans the thumb column width.
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
    final frozen = version?.frozen == true;
    final thumbPath = version?.previewThumbPath;
    final photoCount = version?.photos.length ?? 0;
    final ratio = version?.config.aspect.ratioLabel ?? '4:5';

    final scheme = Theme.of(context).colorScheme;
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
              // Thumbnail column — height-locked, width grows to fill leftover
              // visual identity strip (extends to right end of the column).
              SizedBox(
                height: thumbHeight,
                width: thumbHeight * 2.4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: _Thumb(
                    path: thumbPath,
                    height: thumbHeight,
                    matte: version?.config.swatch.color ?? AppTheme.mist,
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
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (version != null) version.label ?? 'v${version.versionNumber}',
                        ratio,
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
    required this.height,
    required this.matte,
  });

  final String? path;
  final double height;
  final Color matte;

  @override
  Widget build(BuildContext context) {
    if (path != null && File(path!).existsSync()) {
      return Image.file(
        File(path!),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.centerLeft,
      );
    }
    return ColoredBox(
      color: matte,
      child: Center(
        child: Icon(
          Icons.photo_library_outlined,
          color: AppTheme.muted(context, 0.25),
        ),
      ),
    );
  }
}
