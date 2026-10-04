# Agent notes — InstaLay

## Package & paths

- Dart package `instalay` (`package:instalay/...`); on-disk app data folder `instalay/` (one-time migrate from legacy `insta_lay/`).
- `jxl_ffi` git submodule at `packages/jxl_ffi` (authoritative repo: `AMDphreak/jxl_ffi`).
- Version label: `lib/app_version.dart` must match `pubspec.yaml` `version:` (`name+build`).

## CI vs Windows desktop

- PR CI (`.github/workflows/ci.yml`) runs `flutter analyze` + `flutter test` on Ubuntu only — **never compiles Windows**. Green CI ≠ working `flutter run -d windows`.
- Run `flutter analyze` locally before pushing; `file_picker` 12.x treats removed API surface as analyzer failures.

## file_picker (12.x)

- Dependency: `file_picker: ^12.0.0-beta.7` (newest that co-resolves with `share_plus` 13 / `win32` ^6).
- `pickFiles()` no longer accepts `allowMultiple`, `withData`, or top-level `lockParentWindow`. Multi-select is the default; InstaLay imports use `PlatformFile.path` only (`editor_screen.dart` `_addPhotos`).
- `saveFile()` / `getDirectoryPath()` in `export_save.dart` may still pass `lockParentWindow` until migrated to `WindowsOptions` / `LinuxOptions` on a future plugin bump.

## Windows JXL / CMake

- Link needs `JXL_STATIC_DEFINE` (+ CMS/THREADS) or `__imp_Jxl*` LNK2019.
- Prefer `.\scripts\build_libjxl_prebuilt_windows.ps1` before `flutter build windows` — official `jxl-x64-windows-static.7z` often fails STL ABI on VS 17.14 (`__std_min_element_*`).
- After clone move/rename or CMake `project()` change: wipe `build/windows` or `flutter clean`; fix script `.\scripts\ensure_windows_cmake_cache.ps1 -Fix`.

## Export pipeline

- Interactive editing: live Skia canvas; export uses CPU `CanvasRenderer` (Lanczos / package:image).
- **Export rotates cropped sources before downsampling** (`rotateBeforeResize`) — thumbs/edit keep resize-then-rotate.
- Export size slider is **height** (`exportLongEdge`); width follows frame aspect.
- Matte *Transparent* keeps alpha in PNG/WebP/AVIF/JXL; JPEG flattens to white.

## Commerce & bridge

- Mobile IAP: optional Adapty (`--dart-define=ADAPTY_PUBLIC_SDK_KEY`). Web/desktop ownership via Linx Photos entitlement (`photo-service` `/apps/instalay`).
- Linx↔InstaLay bridge: deep links + album variant picker API; docs `INSTALAY-BRIDGE.adoc`.

## Brand & packaging

- Canonical SVG `assets/branding/instalay_logo.svg`; regenerate icons: Inkscape export → `python scripts/generate_brand_icons.py`.
- Inno Start Menu display **InstaLay**; keywords script `scripts/windows/set_start_menu_keywords.ps1`.

## UI scale

- Whole-UI zoom: `uiScaleProvider` (`instalay_ui_scale_v1`, 0.75–1.5); `UiScaledChild` is textScaler-only (no Transform / MediaQuery size rewrite).
