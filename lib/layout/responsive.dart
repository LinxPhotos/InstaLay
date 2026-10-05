/// Shared layout breakpoints for phone vs wide chrome.
library;

import 'package:flutter/widgets.dart';

/// Width at which app bars and the three-pane editor fit in one row.
///
/// Matches the home screen collapse used in [HomeScreen] (logo + More menu).
const double kWideLayoutMinWidth = 720;

bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideLayoutMinWidth;

bool isWideWidth(double width) => width >= kWideLayoutMinWidth;

/// Dialog content width that stays inside the screen with side padding.
double dialogContentWidth(
  BuildContext context, {
  double preferred = 480,
  double horizontalInset = 48,
}) {
  final max = MediaQuery.sizeOf(context).width - horizontalInset;
  if (max <= 0) return preferred;
  return preferred < max ? preferred : max;
}
