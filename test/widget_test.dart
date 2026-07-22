import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instalay/main.dart';

void main() {
  testWidgets('InstaLay home shows brand', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: InstaLayApp()));
    await tester.pump();
    expect(find.text('InstaLay'), findsWidgets);
  });
}
