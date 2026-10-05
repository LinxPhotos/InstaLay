import 'package:flutter/foundation.dart';

/// How this binary was installed / which updater path to use.
enum UpdateChannel {
  /// Direct download (setup EXE / macOS zip from the download page).
  downloadPage,

  /// Microsoft Store / MSIX — OS-managed updates only.
  msStore,

  /// Homebrew cask — tell the user to `brew upgrade`.
  homebrew,

  /// Flutter web / mobile / Linux Phase 1 — no client binary updater.
  unsupported,
}

/// Detect the update channel from the running executable path and platform.
UpdateChannel detectUpdateChannel({
  required String resolvedExecutable,
  TargetPlatform? platform,
  bool? isWeb,
}) {
  final web = isWeb ?? kIsWeb;
  if (web) return UpdateChannel.unsupported;

  final p = platform ?? defaultTargetPlatform;
  if (p == TargetPlatform.android || p == TargetPlatform.iOS) {
    return UpdateChannel.unsupported;
  }

  final path = resolvedExecutable.replaceAll('\\', '/').toLowerCase();

  if (p == TargetPlatform.windows) {
    if (path.contains('/windowsapps/') ||
        path.contains('/program files/windowsapps/')) {
      return UpdateChannel.msStore;
    }
    return UpdateChannel.downloadPage;
  }

  if (p == TargetPlatform.macOS) {
    if (path.contains('/caskroom/') ||
        path.contains('/cellar/') ||
        path.contains('/homebrew/')) {
      return UpdateChannel.homebrew;
    }
    return UpdateChannel.downloadPage;
  }

  // Linux Phase 1: no in-app replace yet.
  return UpdateChannel.unsupported;
}

/// Platform key in the feed (`windows-x64`, `macos-arm64`, …).
String? updatePlatformKey({
  TargetPlatform? platform,
  required String architecture,
  bool? isWeb,
}) {
  final web = isWeb ?? kIsWeb;
  if (web) return null;
  final p = platform ?? defaultTargetPlatform;
  final arch = architecture.toLowerCase();
  final archKey = (arch.contains('arm') || arch.contains('aarch'))
      ? 'arm64'
      : 'x64';
  return switch (p) {
    TargetPlatform.windows => 'windows-$archKey',
    TargetPlatform.macOS => 'macos-$archKey',
    TargetPlatform.linux => 'linux-$archKey',
    _ => null,
  };
}

/// Normalize CPU arch tokens from env (`AMD64`, `arm64`, …) or paths.
String normalizeArchitecture(String raw) {
  final a = raw.trim().toLowerCase();
  if (a.contains('arm64') || a.contains('aarch64') || a == 'arm') {
    return 'arm64';
  }
  return 'x64';
}
