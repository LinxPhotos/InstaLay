import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fitted overview of the framed export (contain-in-box), not pixel zoom.
class PreviewSidebar extends StatelessWidget {
  const PreviewSidebar({
    super.key,
    required this.title,
    required this.bytes,
    this.loading = false,
    this.width = 320,
    this.aspectRatio = 1,
  });

  final String title;
  final Uint8List? bytes;
  final bool loading;
  final double width;
  /// Box shape for the fitted preview (defaults to square).
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final chrome = AppTheme.chrome(context);
    final panel = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.elevatedDark
        : const Color(0xFFF0EFEC);
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: chrome)),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Framed canvas, fitted to the box',
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
              child: Align(
                alignment: Alignment.topCenter,
                child: AspectRatio(
                  aspectRatio: aspectRatio <= 0 ? 1 : aspectRatio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: chrome),
                    ),
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : bytes == null
                            ? Center(
                                child: Text(
                                  'Select a photo',
                                  style: TextStyle(
                                    color: AppTheme.muted(context, 0.4),
                                  ),
                                ),
                              )
                            : InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 8,
                                child: Image.memory(
                                  bytes!,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true,
                                ),
                              ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
