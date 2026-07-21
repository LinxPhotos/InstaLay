import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_providers.dart';
import 'providers/theme_mode_provider.dart';
import 'screens/home_screen.dart';
import 'services/linx_launch_intent.dart';
import 'theme/app_theme.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();

  LinxLaunchIntent? pending;
  for (final arg in args) {
    pending = LinxLaunchIntent.tryParse(Uri.tryParse(arg));
    if (pending != null) break;
  }
  // Flutter web / rare hosts may pass query on the page URL.
  pending ??= LinxLaunchIntent.tryParse(Uri.base);

  runApp(
    ProviderScope(
      overrides: [
        if (pending != null) pendingLinxLaunchProvider.overrideWith((ref) => pending),
      ],
      child: const InstaLayApp(),
    ),
  );
}

class InstaLayApp extends ConsumerWidget {
  const InstaLayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'InstaLay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
