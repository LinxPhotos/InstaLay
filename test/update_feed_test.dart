import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/services/update/update_feed.dart';
import 'package:instalay/services/update/version_compare.dart';

void main() {
  group('compareVersionStrings', () {
    test('orders dotted releases', () {
      expect(compareVersionStrings('0.8.0', '0.8.0'), 0);
      expect(compareVersionStrings('0.8.1', '0.8.0'), greaterThan(0));
      expect(compareVersionStrings('0.7.9', '0.8.0'), lessThan(0));
      expect(compareVersionStrings('1.0.0', '0.9.9'), greaterThan(0));
      expect(compareVersionStrings('v0.8.0', '0.8.0'), 0);
      expect(compareVersionStrings('0.8.0+17', '0.8.0'), 0);
      expect(isVersionNewer('0.8.1', '0.8.0'), isTrue);
      expect(isVersionNewer('0.8.0', '0.8.0'), isFalse);
    });

    test('pads missing segments as zero', () {
      expect(compareVersionStrings('1.0', '1.0.0'), 0);
      expect(compareVersionStrings('1.0.1', '1.0'), greaterThan(0));
    });
  });

  group('UpdateFeed.parse', () {
    test('parses platforms and optional signature', () {
      const raw = '''
{
  "schemaVersion": 1,
  "version": "0.8.1",
  "channel": "stable",
  "publishedAt": "2026-10-05T12:00:00Z",
  "notesUrl": "https://github.com/LinxPhotos/InstaLay/releases/tag/v0.8.1",
  "mandatory": false,
  "platforms": {
    "windows-x64": {
      "url": "https://example.com/InstaLay-0.8.1-windows-x64-setup.exe",
      "sha256": "AAAABBBB",
      "signature": null,
      "installerKind": "exe-setup",
      "size": 12
    },
    "macos-arm64": {
      "url": "https://example.com/InstaLay-0.8.1-macos-arm64.zip",
      "sha256": "ccccdddd",
      "installerKind": "zip-app"
    }
  }
}
''';
      final feed = UpdateFeed.parse(raw);
      expect(feed.version, '0.8.1');
      expect(feed.channel, 'stable');
      expect(feed.platforms.length, 2);
      final win = feed.platform('windows-x64')!;
      expect(win.installerKind, 'exe-setup');
      expect(win.sha256, 'aaaabbbb');
      expect(win.hasSignature, isFalse);
      final mac = feed.platform('macos-arm64')!;
      expect(mac.installerKind, 'zip-app');
      expect(isVersionNewer(feed.version, '0.8.0'), isTrue);
    });

    test('rejects non-object root', () {
      expect(() => UpdateFeed.parse('[]'), throwsFormatException);
    });
  });
}
