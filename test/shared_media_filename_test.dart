import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/services/shared_media_filename.dart';

void main() {
  test('preserves existing extension in display name', () {
    expect(
      displayFileNameWithExtension('Vacation.JPG', 'image/jpeg'),
      'Vacation.JPG',
    );
  });

  test('adds extension from mime when display name has none', () {
    expect(
      displayFileNameWithExtension('IMG_0001', 'image/jpeg'),
      'IMG_0001.jpg',
    );
    expect(
      displayFileNameWithExtension('clip', 'video/mp4'),
      'clip.mp4',
    );
  });

  test('empty display name falls back to shared plus extension', () {
    expect(
      displayFileNameWithExtension('  ', 'image/png'),
      'shared.png',
    );
  });
}
