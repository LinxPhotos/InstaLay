import 'package:flutter/material.dart';

/// Home-screen brand title: single sans-serif **InstaLay**.
class InstaLayWordmark extends StatelessWidget {
  const InstaLayWordmark({
    super.key,
    this.fontSize = 28.16, // 22 × 1.28 — former enlarged "Lay" default
  });

  /// Display size for the full word (was the larger "Lay" span).
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Text(
      'InstaLay',
      style: TextStyle(
        fontFamily: 'Segoe UI',
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1,
        color: scheme.onSurface,
      ),
    );
  }
}
