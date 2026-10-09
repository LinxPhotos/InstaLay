import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/widgets/slow_task_body.dart';

void main() {
  testWidgets('SlowTaskBody shows progress while loading and not ready',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 120,
            child: SlowTaskBody(
              loading: true,
              ready: false,
              progressMessage: 'Working…',
              child: const Text('Done'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Working…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('SlowTaskBody shows child when ready', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 120,
            child: SlowTaskBody(
              loading: true,
              ready: true,
              child: const Text('Done'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
