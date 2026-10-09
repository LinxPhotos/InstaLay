import 'package:flutter/material.dart';

import '../models/instagram_limits.dart';
import '../theme/app_theme.dart';

/// Warning glyph for a carousel frame / item past Instagram's limit.
class InstagramCarouselWarningBadge extends StatelessWidget {
  const InstagramCarouselWarningBadge({
    super.key,
    this.size = 18,
    this.showTooltip = true,
  });

  final double size;

  /// Tooltips churn the Windows accessibility tree when many badges repaint.
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    final warn = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.warnOnDark
        : AppTheme.warn;
    final icon = Icon(
      Icons.warning_amber_rounded,
      size: size,
      color: warn,
    );
    if (!showTooltip) {
      return ExcludeSemantics(child: icon);
    }
    return Tooltip(
      message: InstagramLimits.excessCarouselFrameTooltip,
      child: icon,
    );
  }
}
