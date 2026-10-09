import 'package:flutter/material.dart';

import '../models/instagram_limits.dart';
import '../theme/app_theme.dart';

/// Warning glyph for a carousel frame / item past Instagram's limit.
class InstagramCarouselWarningBadge extends StatelessWidget {
  const InstagramCarouselWarningBadge({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    final warn = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.warnOnDark
        : AppTheme.warn;
    return Tooltip(
      message: InstagramLimits.excessCarouselFrameTooltip,
      child: Icon(
        Icons.warning_amber_rounded,
        size: size,
        color: warn,
      ),
    );
  }
}
