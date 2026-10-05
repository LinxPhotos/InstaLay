import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/models/canvas_config.dart';
import 'package:instalay/models/project.dart';
import 'package:instalay/widgets/canvas_controls.dart';
import 'package:instalay/widgets/canvas_workspace.dart';
import 'package:instalay/widgets/interactive_tapestry_canvas.dart';

const _first = LayoutCanvas(
  id: 'layout-1',
  name: 'Batch',
  config: CanvasConfig(),
  photos: [],
);

const _second = LayoutCanvas(
  id: 'layout-2',
  name: 'Batch 2',
  config: CanvasConfig(),
  photos: [],
);

Future<void> _setScreen(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Widget _workspace({
  required bool locked,
  required void Function(LayoutCanvas layout) onUpdateLayout,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CanvasWorkspace(
        layouts: const [_first, _second],
        activeLayoutId: _second.id,
        sourceImages: const {},
        selectedPhotoId: null,
        loading: false,
        locked: locked,
        onSelectLayout: (_) {},
        onSelectPhoto: (_) {},
        onUpdateLayout: onUpdateLayout,
        onAddLayout: () {},
        onDeleteLayout: (_) {},
        onExportLayout: (_) {},
        tapestryControllers: <String, TapestryCanvasController>{},
      ),
    ),
  );
}

Finder _segment(String label) => find.descendant(
      of: find.byType(LayoutTypeSelector),
      matching: find.text(label),
    );

void main() {
  for (final screen in const [Size(1200, 800), Size(390, 844)]) {
    testWidgets(
      'layout type switch changes the selected layout at ${screen.width.round()}px',
      (tester) async {
        await _setScreen(tester, screen);
        LayoutCanvas? updated;
        await tester.pumpWidget(
          _workspace(locked: false, onUpdateLayout: (l) => updated = l),
        );
        await tester.pump(const Duration(milliseconds: 400));

        // One switch, on the selected layout, next to Remove layout.
        expect(find.byType(LayoutTypeSelector), findsOneWidget);
        expect(find.byTooltip('Remove layout'), findsNWidgets(2));

        await tester.tap(_segment('Tapestry'));
        await tester.pump();

        expect(updated?.id, _second.id);
        expect(updated?.config.layoutMode, LayoutMode.tapestry);
      },
    );
  }

  testWidgets('layout type switch has 48px segments on a phone',
      (tester) async {
    await _setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      _workspace(locked: false, onUpdateLayout: (_) {}),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final size = tester.getSize(find.byType(SegmentedButton<LayoutMode>));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout type switch is disabled on a frozen version',
      (tester) async {
    await _setScreen(tester, const Size(1200, 800));
    var updates = 0;
    await tester.pumpWidget(
      _workspace(locked: true, onUpdateLayout: (_) => updates++),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(_segment('Tapestry'), warnIfMissed: false);
    await tester.pump();
    expect(updates, 0);
  });

  testWidgets('Settings no longer carries the layout type switch',
      (tester) async {
    await _setScreen(tester, const Size(600, 900));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CanvasControls(
              config: const CanvasConfig(),
              locked: false,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Layout type'), findsNothing);
    expect(find.byType(SegmentedButton<LayoutMode>), findsNothing);
  });
}