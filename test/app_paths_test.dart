import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/services/app_paths.dart';

void main() {
  group('rewriteLegacyAppDataPath', () {
    test('rewrites Windows Documents path segment', () {
      const legacy =
          r'C:\Users\rjamd\Documents\insta_lay\projects\abc\media\x.jpg';
      const next =
          r'C:\Users\rjamd\Documents\instalay\projects\abc\media\x.jpg';
      expect(rewriteLegacyAppDataPath(legacy), next);
    });

    test('rewrites forward-slash paths', () {
      const legacy =
          '/Users/rjamd/Documents/insta_lay/projects/abc/media/x.jpg';
      const next =
          '/Users/rjamd/Documents/instalay/projects/abc/media/x.jpg';
      expect(rewriteLegacyAppDataPath(legacy), next);
    });

    test('is a no-op when already migrated', () {
      const path =
          r'C:\Users\rjamd\Documents\instalay\projects\abc\media\x.jpg';
      expect(rewriteLegacyAppDataPath(path), path);
    });

    test('does not rewrite unrelated substrings', () {
      const path = r'C:\photos\insta_layout_backup\x.jpg';
      expect(rewriteLegacyAppDataPath(path), path);
    });
  });
}
