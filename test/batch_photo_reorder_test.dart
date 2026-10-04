import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/models/project.dart';
import 'package:instalay/widgets/interactive_batch_strip.dart';

PhotoItem _photo(String id, int order) => PhotoItem(
      id: id,
      sourcePath: '/x/$id.jpg',
      order: order,
    );

void main() {
  test('reorderBatchPhotos moves item and reindexes order fields', () {
    final ordered = [_photo('a', 0), _photo('b', 1), _photo('c', 2)];
    final next = reorderBatchPhotos(ordered, 0, 3);
    expect(next.map((p) => p.id).toList(), ['b', 'c', 'a']);
    expect(next.map((p) => p.order).toList(), [0, 1, 2]);
  });

  test('reorderBatchPhotos no-op when from equals dest', () {
    final ordered = [_photo('a', 0), _photo('b', 1)];
    final next = reorderBatchPhotos(ordered, 1, 1);
    expect(next.map((p) => p.id).toList(), ['a', 'b']);
  });
}
