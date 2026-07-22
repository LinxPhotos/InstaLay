import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Where the preview panel sits relative to the editor chrome.
enum PreviewPlacement {
  /// Right of settings (batch desktop).
  side,
  /// Below settings (tapestry / narrow).
  bottom,
}

/// Host for the live art canvas (Skia composite). Does not bake bitmaps.
class PreviewSidebar extends StatelessWidget {
  const PreviewSidebar({
    super.key,
    required this.title,
    required this.canvas,
    this.loading = false,
    this.width = 320,
    this.subtitle,
    this.placement = PreviewPlacement.side,
  });

  final String title;
  /// Live [LiveFramedCanvas] / [LiveTapestryCanvas] (or placeholder).
  final Widget canvas;
  final bool loading;
  final double width;
  final String? subtitle;
  final PreviewPlacement placement;

  @override
  Widget build(BuildContext context) {
    final chrome = AppTheme.chrome(context);
    final panel = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.elevatedDark
        : const Color(0xFFF0EFEC);

    final border = placement == PreviewPlacement.bottom
        ? Border(top: BorderSide(color: chrome))
        : Border(left: BorderSide(color: chrome));

    return Container(
      width: width,
      decoration: BoxDecoration(
        border: border,
        color: panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted(context, 0.5),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  canvas,
                  if (loading)
                    ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.35),
                      child: const Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
