# Machine / environment facts for InstaLay agents

- Flutter SDK path: `C:\flutter-sdk\flutter\bin` (refresh PATH if `flutter` missing in shell) — used: 2
- CODE_ROOT projects live under `Z:\code\github.com\amdphreak\` — used: 1
- Windows package manager preference for Node is pnpm; this repo is Dart/Flutter — used: 1
- Photo decode prefers `dart:ui` `instantiateImageCodecWithSize` (Skia; often libjpeg-turbo under the hood) with `maxLongEdge`; framing/JPEG encode use `Isolate.run`. Canvas edit path is CPU Lanczos, not GPU — used: 1
