import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instalay/services/update/update_channel.dart';

void main() {
  group('detectUpdateChannel', () {
    test('marks WindowsApps as msStore', () {
      final c = detectUpdateChannel(
        resolvedExecutable:
            r'C:\Program Files\WindowsApps\LinxPhotos.InstaLay_1.0.0.0_x64\instalay.exe',
        platform: TargetPlatform.windows,
        isWeb: false,
      );
      expect(c, UpdateChannel.msStore);
    });

    test('marks Program Files setup installs as downloadPage', () {
      final c = detectUpdateChannel(
        resolvedExecutable: r'C:\Program Files\InstaLay\instalay.exe',
        platform: TargetPlatform.windows,
        isWeb: false,
      );
      expect(c, UpdateChannel.downloadPage);
    });

    test('marks Homebrew cask paths', () {
      final c = detectUpdateChannel(
        resolvedExecutable:
            '/opt/homebrew/Caskroom/instalay/0.8.0/InstaLay.app/Contents/MacOS/instalay',
        platform: TargetPlatform.macOS,
        isWeb: false,
      );
      expect(c, UpdateChannel.homebrew);
    });

    test('web and mobile are unsupported', () {
      expect(
        detectUpdateChannel(
          resolvedExecutable: '',
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        UpdateChannel.unsupported,
      );
      expect(
        detectUpdateChannel(
          resolvedExecutable: '/app',
          platform: TargetPlatform.windows,
          isWeb: true,
        ),
        UpdateChannel.unsupported,
      );
    });
  });

  group('updatePlatformKey', () {
    test('builds os-arch keys', () {
      expect(
        updatePlatformKey(
          platform: TargetPlatform.windows,
          architecture: 'AMD64',
          isWeb: false,
        ),
        'windows-x64',
      );
      expect(
        updatePlatformKey(
          platform: TargetPlatform.macOS,
          architecture: 'arm64',
          isWeb: false,
        ),
        'macos-arm64',
      );
    });
  });
}
