#!/usr/bin/env bash
# Package Flutter desktop release bundles into installers / archives.
# Usage: scripts/package.sh <windows|macos|linux> <arch> <version> <input_dir> <output_dir>
set -euo pipefail

PLATFORM="${1:?platform}"
ARCH="${2:?arch}"
VERSION="${3:?version}"
INPUT="${4:?input dir}"
OUTPUT="${5:?output dir}"

mkdir -p "$OUTPUT"
NAME="InstaLay-${VERSION}-${PLATFORM}-${ARCH}"

case "$PLATFORM" in
  windows)
    # Prefer an already-built installer; otherwise zip the Release folder.
    if [[ -f "$INPUT/InstaLaySetup.exe" ]]; then
      cp "$INPUT/InstaLaySetup.exe" "$OUTPUT/${NAME}-setup.exe"
    fi
    if [[ -f "$INPUT/insta_lay.msix" ]]; then
      cp "$INPUT/insta_lay.msix" "$OUTPUT/${NAME}.msix"
    fi
    # Portable zip of the runner directory
    STAGE="$OUTPUT/_stage_win"
    rm -rf "$STAGE"
    mkdir -p "$STAGE"
    cp -R "$INPUT"/. "$STAGE/"
    (
      cd "$STAGE"
      # shellcheck disable=SC2035
      zip -r "$OUTPUT/${NAME}.zip" . -x "*.pdb"
    )
    rm -rf "$STAGE"
    ;;
  macos)
    APP_PATH="$(find "$INPUT" -maxdepth 3 -name '*.app' -print -quit)"
    if [[ -z "$APP_PATH" ]]; then
      echo "No .app found under $INPUT" >&2
      exit 1
    fi
    DMG="$OUTPUT/${NAME}.dmg"
    APP_NAME="$(basename "$APP_PATH")"
    VOL="Insta Lay"
    STAGE="$OUTPUT/_stage_dmg"
    rm -rf "$STAGE" "$DMG"
    mkdir -p "$STAGE"
    cp -R "$APP_PATH" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
    # Also ship a zip for Homebrew / portable installs
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUTPUT/${NAME}.zip"
    rm -rf "$STAGE"
    ;;
  linux)
    # Tar the Flutter linux bundle; also emit AppImage if appimagetool is present.
    TAR="$OUTPUT/${NAME}.tar.gz"
    (
      cd "$INPUT"
      tar -czf "$TAR" .
    )
    if command -v appimagetool >/dev/null 2>&1; then
      APPDIR="$OUTPUT/${NAME}.AppDir"
      rm -rf "$APPDIR"
      mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share/applications"
      cp -R "$INPUT"/. "$APPDIR/usr/bin/"
      BINARY="$(find "$APPDIR/usr/bin" -maxdepth 2 -type f -executable -name 'insta_lay' | head -n1)"
      cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/insta_lay" "$@"
EOF
      chmod +x "$APPDIR/AppRun"
      if [[ -n "$BINARY" ]]; then
        chmod +x "$BINARY"
      fi
      cat > "$APPDIR/insta-lay.desktop" <<EOF
[Desktop Entry]
Name=Insta Lay
Exec=insta_lay
Icon=insta-lay
Type=Application
Categories=Graphics;Photography;
EOF
      cp "$APPDIR/insta-lay.desktop" "$APPDIR/usr/share/applications/"
      # Placeholder icon
      printf '' > "$APPDIR/insta-lay.png" || true
      ARCH_LABEL="$ARCH"
      [[ "$ARCH" == "x64" ]] && ARCH_LABEL="x86_64"
      [[ "$ARCH" == "arm64" ]] && ARCH_LABEL="aarch64"
      export ARCH="$ARCH_LABEL"
      appimagetool "$APPDIR" "$OUTPUT/${NAME}.AppImage"
      rm -rf "$APPDIR"
    fi
    ;;
  *)
    echo "Unknown platform: $PLATFORM" >&2
    exit 1
    ;;
esac

echo "Packaged $NAME -> $OUTPUT"
ls -la "$OUTPUT"
