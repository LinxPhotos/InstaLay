import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insta_lay/models/canvas_config.dart';
import 'package:insta_lay/models/project.dart';
import 'package:insta_lay/widgets/canvas_controls.dart';
import 'package:insta_lay/widgets/canvas_workspace.dart';
import 'package:insta_lay/widgets/export_destination_dialog.dart';
import 'package:insta_lay/widgets/interactive_tapestry_canvas.dart';

LayoutCanvas _layout() => const LayoutCanvas(
      id: 'layout-1',
      name: 'Batch',
      config: CanvasConfig(),
      photos: [],
    );

Widget _workspace({
  required bool locked,
  required VoidCallback onAddLayout,
}) {
  final layout = _layout();
  return MaterialApp(
    home: Scaffold(
      body: CanvasWorkspace(
        layouts: [layout],
        activeLayoutId: layout.id,
        sourceImages: const {},
        selectedPhotoId: null,
        loading: false,
        locked: locked,
        onSelectLayout: (_) {},
        onSelectPhoto: (_) {},
        onUpdateLayout: (_) {},
        onAddLayout: onAddLayout,
        onDeleteLayout: (_) {},
        tapestryControllers: <String, TapestryCanvasController>{},
      ),
    ),
  );
}

void main() {
  testWidgets(
    'REPRODUCTION: locked (frozen version) makes Canvases controls dead',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var addLayoutCalls = 0;
      await tester.pumpWidget(
        _workspace(locked: true, onAddLayout: () => addLayoutCalls++),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Add layout'), warnIfMissed: false);
      await tester.pump();

      // This is the "unclickable UI": frozen version, not hit-testing.
      expect(addLayoutCalls, 0);
    },
  );

  testWidgets('unlocked workspace Add layout fires', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var addLayoutCalls = 0;
    await tester.pumpWidget(
      _workspace(locked: false, onAddLayout: () => addLayoutCalls++),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Add layout'));
    await tester.pump();

    expect(addLayoutCalls, 1);
  });

  testWidgets(
    'REPRODUCTION: locked CanvasControls absorbs all Settings taps',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var changed = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CanvasControls(
                config: const CanvasConfig(),
                locked: true,
                onChanged: (_) => changed++,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // Frozen banner is shown, and aspect chips do not respond.
      expect(
        find.textContaining('frozen after posting'),
        findsOneWidget,
      );
      final chip = find.byType(ChoiceChip).first;
      await tester.tap(chip, warnIfMissed: false);
      await tester.pump();
      expect(changed, 0);
    },
  );

  testWidgets('unlocked CanvasControls aspect chips respond', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var changed = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CanvasControls(
              config: const CanvasConfig(),
              locked: false,
              onChanged: (_) => changed++,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pump();
    expect(changed, 1);
  });

  test('only Share freezes a version after export — Save must not lock UI', () {
    expect(shouldFreezeAfterExport(ExportDestination.share), isTrue);
    expect(
      shouldFreezeAfterExport(ExportDestination.save),
      isFalse,
      reason: 'freezing on save-to-disk silently locked the whole editor '
          '(the "unclickable UI" bug)',
    );
  });
}
