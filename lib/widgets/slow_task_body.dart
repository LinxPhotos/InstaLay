import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard layout for a region backed by slow async work: linear progress,
/// optional status line, then [child] or a centered spinner until [ready].
class SlowTaskBody extends StatelessWidget {
  const SlowTaskBody({
    super.key,
    required this.loading,
    required this.ready,
    required this.child,
    this.progressMessage,
  });

  final bool loading;
  final bool ready;
  final Widget child;
  final String? progressMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          const LinearProgressIndicator(minHeight: 3),
        if (loading && progressMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
            child: Text(
              progressMessage!,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.muted(context, 0.55),
              ),
            ),
          ),
        Expanded(
          child: ready
              ? child
              : const Center(child: CircularProgressIndicator.adaptive()),
        ),
      ],
    );
  }
}
