import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_mode_provider.dart';

/// Cycles appearance: system (OS) → light → dark.
class ThemeModeButton extends ConsumerWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final (icon, label) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto_outlined, 'System'),
      ThemeMode.light => (Icons.light_mode_outlined, 'Light'),
      ThemeMode.dark => (Icons.dark_mode_outlined, 'Dark'),
    };

    return IconButton(
      tooltip: 'Theme: $label (tap to change)',
      onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
      icon: Icon(icon),
    );
  }
}
