import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'desktop/desktop_window.dart';
import 'providers/app_providers.dart';
import 'providers/theme_mode_provider.dart';
import 'providers/ui_scale_provider.dart';
import 'screens/home_screen.dart';
import 'services/linx_launch_intent.dart';
import 'theme/app_theme.dart';
import 'widgets/ui_scaled_child.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrapDesktopWindow();

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
        if (pending != null)
          pendingLinxLaunchProvider.overrideWith((ref) => pending),
      ],
      child: const InstaLayApp(),
    ),
  );
}

class _ZoomInIntent extends Intent {
  const _ZoomInIntent();
}

class _ZoomOutIntent extends Intent {
  const _ZoomOutIntent();
}

class _ZoomResetIntent extends Intent {
  const _ZoomResetIntent();
}

/// Ctrl/Cmd + =/+ − / 0 for whole-UI zoom (desktop; harmless elsewhere).
Map<ShortcutActivator, Intent> get _uiScaleShortcuts => {
      // Zoom in: Ctrl/=, Ctrl/Shift/=, Ctrl/+, numpad +
      const SingleActivator(LogicalKeyboardKey.equal, control: true):
          const _ZoomInIntent(),
      const SingleActivator(
        LogicalKeyboardKey.equal,
        control: true,
        shift: true,
      ): const _ZoomInIntent(),
      const SingleActivator(LogicalKeyboardKey.add, control: true):
          const _ZoomInIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true):
          const _ZoomInIntent(),
      const SingleActivator(LogicalKeyboardKey.equal, meta: true):
          const _ZoomInIntent(),
      const SingleActivator(
        LogicalKeyboardKey.equal,
        meta: true,
        shift: true,
      ): const _ZoomInIntent(),
      const SingleActivator(LogicalKeyboardKey.add, meta: true):
          const _ZoomInIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadAdd, meta: true):
          const _ZoomInIntent(),
      // Zoom out
      const SingleActivator(LogicalKeyboardKey.minus, control: true):
          const _ZoomOutIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true):
          const _ZoomOutIntent(),
      const SingleActivator(LogicalKeyboardKey.minus, meta: true):
          const _ZoomOutIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadSubtract, meta: true):
          const _ZoomOutIntent(),
      // Reset 100%
      const SingleActivator(LogicalKeyboardKey.digit0, control: true):
          const _ZoomResetIntent(),
      const SingleActivator(LogicalKeyboardKey.numpad0, control: true):
          const _ZoomResetIntent(),
      const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
          const _ZoomResetIntent(),
      const SingleActivator(LogicalKeyboardKey.numpad0, meta: true):
          const _ZoomResetIntent(),
    };

class InstaLayApp extends ConsumerWidget {
  const InstaLayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final uiScale = ref.watch(uiScaleProvider);

    return DesktopWindowBinder(
      child: MaterialApp(
        title: 'InstaLay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        shortcuts: <ShortcutActivator, Intent>{
          ...WidgetsApp.defaultShortcuts,
          ..._uiScaleShortcuts,
        },
        actions: <Type, Action<Intent>>{
          ...WidgetsApp.defaultActions,
          _ZoomInIntent: CallbackAction<_ZoomInIntent>(
            onInvoke: (_) {
              ref.read(uiScaleProvider.notifier).zoomIn();
              return null;
            },
          ),
          _ZoomOutIntent: CallbackAction<_ZoomOutIntent>(
            onInvoke: (_) {
              ref.read(uiScaleProvider.notifier).zoomOut();
              return null;
            },
          ),
          _ZoomResetIntent: CallbackAction<_ZoomResetIntent>(
            onInvoke: (_) {
              ref.read(uiScaleProvider.notifier).reset();
              return null;
            },
          ),
        },
        builder: (context, child) {
          // textScaler-only zoom — do not pin SizedBox/Transform to a rewritten
          // MediaQuery size (that overflowed right/bottom on un-maximize and
          // desynced hit targets from paint).
          return UiScaledChild(
            scale: uiScale,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const HomeScreen(),
      ),
    );
  }
}
