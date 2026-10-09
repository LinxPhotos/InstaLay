import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/models/project.dart';

void main() {
  test('legacy photo json without pin flag is treated as pinned when offset set',
      () {
    expect(
      PhotoItem.tapestryPositionPinnedFromJson({
        'id': 'a',
        'sourcePath': 'x.jpg',
        'offsetX': 120,
        'offsetY': 40,
      }),
      isTrue,
    );
  });

  test('explicit tapestryPositionPinned false is honored', () {
    expect(
      PhotoItem.tapestryPositionPinnedFromJson({
        'id': 'a',
        'sourcePath': 'x.jpg',
        'offsetX': 120,
        'tapestryPositionPinned': false,
      }),
      isFalse,
    );
  });
}
