import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/widgets/horizontal_canvas_viewport.dart';

void main() {
  testWidgets('HorizontalCanvasViewport shows scrollbar for wide content',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 120,
            child: HorizontalCanvasViewport(
              controller: controller,
              viewportHeight: 120,
              contentWidth: 900,
              child: Row(
                children: [
                  for (var i = 0; i < 6; i++)
                    Container(
                      width: 140,
                      height: 120,
                      color: Colors.primaries[i],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scrollbar), findsOneWidget);
    expect(controller.hasClients, isTrue);
    expect(controller.position.maxScrollExtent, greaterThan(0));
  });
}
