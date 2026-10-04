# Agent notes — InstaLay

## Package & paths

- Dart package `instalay` (`package:instalay/...`); on-disk app data folder `instalay/` (one-time migrate from legacy `insta_lay/`).
- `jxl_ffi` git submodule at `packages/jxl_ffi` (authoritative repo: `AMDphreak/jxl_ffi`).
- Version label: `lib/app_version.dart` must match `pubspec.yaml` `version:` (`name+build`).

## CI vs Windows desktop

- PR CI (`.github/workflows/ci.yml`) runs `flutter analyze` + `flutter test` on Ubuntu only — **never compiles Windows**. Green CI ≠ working `flutter run -d windows`.

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

## Canvas workspace (batch / tapestry previews)

- Shared horizontal overflow: `HorizontalCanvasViewport` (`lib/widgets/horizontal_canvas_viewport.dart`) — scrollbar, wheel/trackpad pan on X.
- Batch strip: `InteractiveBatchStrip` — desktop click-drag reorder; mobile long-press + slide; logic tests via `reorderBatchPhotos`.
- Tapestry: `InteractiveTapestryCanvas` uses the same viewport; on touch, first tap selects a layer, drag moves only when already selected (scroll vs drag).
- Editor host: `CanvasWorkspace` — do not wrap tapestry in competing `GestureDetector`s.
- Full write-up: `docs/canvas-workspace.adoc`.
