# Machine / environment facts for InstaLay agents

- Flutter SDK path: `C:\flutter-sdk\flutter\bin` (refresh PATH if `flutter` missing in shell) -- used: 3
- CODE_ROOT projects live under `Z:\code\github.com\amdphreak\` -- used: 2
- Windows package manager preference for Node is pnpm; this repo is Dart/Flutter -- used: 1
- Photo decode prefers `dart:ui` `instantiateImageCodecWithSize` (Skia; often libjpeg-turbo under the hood) with `maxLongEdge`; interactive edit path caches decoded RGBA in `SourceBitmapCache` (mem+disk), frames in `Isolate.run`, and displays via `RawImage` without JPEG encode. Export still frames/encodes from full-res decode. Canvas edit path is CPU Lanczos, not GPU -- used: 3
- JPEG XL: default native **libjxl via `packages/jxl_ffi` submodule** (dart:ffi) on Windows/Linux desktop, using libjxl **v0.12.0 static prebuilts** (lossless + lossy encode/decode). Authoritative package repo: `Z:\code\github.com\AMDphreak\jxl_ffi` (https://github.com/AMDphreak/jxl_ffi). `koni_jxl` remains the fallback when the native DLL/SO is unavailable or fails to load. No GPU JXL path. Windows extraction needs **7-Zip** (`C:\Program Files\7-Zip\7z.exe`) -- used: 3
- `jxl_ffi` authoritative clone: `Z:\code\github.com\AMDphreak\jxl_ffi`; InstaLay consumes it as git submodule at `packages/jxl_ffi` -- used: 1
- `jxl_coder` / `flutter-jxl-coder` evaluated and dropped for InstaLay (Apple-only JPEG↔JXL transcode, not RGBA). Local `.forks/flutter-jxl-coder` removed; GitHub fork kept until any upstream docs PR settles -- used: 2
- Forks clone path: `Z:\code\github.com\AMDphreak\.forks\` -- used: 1
- Adapty is the chosen mobile subscription-management platform (access level `instalay`); desktop stays on IL- keys. Public SDK key via `--dart-define=ADAPTY_PUBLIC_SDK_KEY`. Stripe Checkout must send `customer_user_id` for web→app sync -- used: 1
- FoodTruckNerdz org clones: `Z:\code\github.com\FoodTruckNerdz\` (ftn-app, ftn-site, docs). DevCentr docs: `Z:\code\github.com\dev-centr\docs` + `general-knowledge` -- used: 1
- Linx↔InstaLay bridge: deep links + album variant picker API (no nav merge). Linx photo-service at `Z:\code\github.com\LinxPhotos\photo-service`; docs `INSTALAY-BRIDGE.adoc` -- used: 1
