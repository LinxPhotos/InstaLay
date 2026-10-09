import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/models/project.dart';

void main() {
  test('raise swaps zIndex between photo and text', () {
    const photoA = PhotoItem(
      id: 'a',
      sourcePath: '/a.jpg',
      order: 0,
      zIndex: 0,
    );
    const photoB = PhotoItem(
      id: 'b',
      sourcePath: '/b.jpg',
      order: 1,
      zIndex: 1,
    );
    const text = TextItem(id: 't', text: 'Hi', zIndex: 2);
    final raised = TapestryLayerOrder.raise(
      [photoA, photoB],
      [text],
      'b',
    );
    expect(raised.photos[1].zIndex, 2);
    expect(raised.texts.single.zIndex, 1);
  });
}
