import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 1:1 preview pane for the selected framed export candidate.
class PreviewSidebar extends StatelessWidget {
  const PreviewSidebar({
    super.key,
    required this.title,
    required this.bytes,
    this.loading = false,
    this.width = 320,
  });

  final String title;
  final Uint8List? bytes;
  final bool loading;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.mist)),
        color: Color(0xFFF0EFEC),
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
              '1:1 pixel preview of the framed canvas',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.ink.withValues(alpha: 0.5),
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
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppTheme.mist),
                    ),
                    child: loading
                        ? const Center(child: CircularProgressIndicator.adaptive())
                        : bytes == null
                            ? Center(
                                child: Text(
                                  'Select a photo',
                                  style: TextStyle(
                                    color: AppTheme.ink.withValues(alpha: 0.4),
                                  ),
                                ),
                              )
                            : InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 8,
                                child: Image.memory(
                                  bytes!,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none,
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
