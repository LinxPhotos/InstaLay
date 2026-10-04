import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/services/linx_launch_intent.dart';

void main() {
  test('parses instalay://import query', () {
    final intent = LinxLaunchIntent.tryParse(
      Uri.parse('instalay://import?albumId=alb1&variantIds=v1,v2&itemId=i1'),
    );
    expect(intent, isNotNull);
    expect(intent!.albumId, 'alb1');
    expect(intent.itemId, 'i1');
    expect(intent.variantIds, ['v1', 'v2']);
  });

  test('parses https /import handoff path', () {
    final intent = LinxLaunchIntent.tryParse(
      Uri.parse(
        'https://app.instalay.linx.photos/import?albumId=alb1&variantIds=v1',
      ),
    );
    expect(intent, isNotNull);
    expect(intent!.albumId, 'alb1');
    expect(intent.variantIds, ['v1']);
  });
}
