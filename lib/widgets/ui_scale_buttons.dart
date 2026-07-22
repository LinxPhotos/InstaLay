import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ui_scale_provider.dart';
import '../theme/app_theme.dart';

/// Compact AppBar zoom_out / percent / zoom_in for whole-UI scale.
///
/// Calls [UiScaleNotifier] the same way as Ctrl/Cmd +/−/0 shortcuts.
class UiScaleButtons extends ConsumerWidget {
  const UiScaleButtons({super.key});

  static String get _modKey {
    if (kIsWeb) return 'Ctrl';
    return defaultTargetPlatform == TargetPlatform.macOS ? 'Cmd' : 'Ctrl';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(uiScaleProvider);
    final notifier = ref.read(uiScaleProvider.notifier);
    final percent = (scale * 100).round();
    final atMin = scale <= UiScaleNotifier.minScale;
    final atMax = scale >= UiScaleNotifier.maxScale;
    final mod = _modKey;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Zoom out ($percent%) · $mod+-',
          onPressed: atMin ? null : notifier.zoomOut,
          icon: const Icon(Icons.zoom_out),
        ),
        Tooltip(
          message: 'Reset zoom to 100% · $mod+0',
          child: InkWell(
            onTap: scale == UiScaleNotifier.defaultScale ? null : notifier.reset,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Text(
                '$percent%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.muted(context, 0.7),
                    ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Zoom in ($percent%) · $mod+=',
          onPressed: atMax ? null : notifier.zoomIn,
          icon: const Icon(Icons.zoom_in),
        ),
      ],
    );
  }
}
