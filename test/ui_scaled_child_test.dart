import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/widgets/ui_scaled_child.dart';

void main() {
  testWidgets('UiScaledChild applies textScaler without rewriting layout size', (
    tester,
  ) async {
    const surface = Size(800, 600);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late TextScaler scaler;
    late Size mqSize;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: surface),
          child: UiScaledChild(
            scale: 1.2,
            child: Builder(
              builder: (context) {
                final mq = MediaQuery.of(context);
                scaler = mq.textScaler;
                mqSize = mq.size;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(scaler.scale(10), 12);
    // Must keep the real window size — rewriting size/scale caused overflow
    // and dead hit zones when the window restored from maximized.
    expect(mqSize, surface);
  });

  testWidgets('UiScaledChild passes taps in bottom-right at scale 1.2', (
    tester,
  ) async {
    const surface = Size(800, 600);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return UiScaledChild(scale: 1.2, child: child!);
        },
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed: () => tapped = true,
              child: const Text('BR'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(780, 580));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets(
    'UiScaledChild does not overflow when surface shrinks (un-maximize)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return UiScaledChild(scale: 1.2, child: child!);
          },
          home: Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 200, child: Text('SOURCES')),
                const Expanded(child: Text('CANVASES')),
                SizedBox(
                  width: 240,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: () => taps++,
                      child: const Text('SETTINGS'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Restore from maximized → smaller window.
      await tester.binding.setSurfaceSize(const Size(1100, 700));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('SETTINGS'));
      await tester.pump();
      expect(taps, 1);
    },
  );

  for (final scale in <double>[0.9, 1.0, 1.2]) {
    testWidgets('3-column Settings tap works at scale $scale after shrink', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var settingsTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return UiScaledChild(scale: scale, child: child!);
          },
          home: Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 200, child: Text('SOURCES')),
                const Expanded(child: Center(child: Text('CANVASES'))),
                SizedBox(
                  width: 240,
                  child: ElevatedButton(
                    onPressed: () => settingsTaps++,
                    child: const Text('SETTINGS'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(const Size(1000, 650));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('SETTINGS'));
      await tester.pump();
      expect(settingsTaps, 1);
    });
  }
}
