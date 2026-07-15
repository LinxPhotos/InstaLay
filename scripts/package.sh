#!/usr/bin/env bash
# Package Flutter desktop release bundles into installers / archives.
# Usage: scripts/package.sh <windows|macos|linux> <arch> <version> <input_dir> <output_dir>
set -euo pipefail

PLATFORM="${1:?platform}"
ARCH="${2:?arch}"
VERSION="${3:?version}"
INPUT="$(cd "${4:?input dir}" && pwd)"
OUTPUT="$(mkdir -p "${5:?output dir}" && cd "${5}" && pwd)"

NAME="InstaLay-${VERSION}-${PLATFORM}-${ARCH}"

case "$PLATFORM" in
  windows)
    if [[ -f "$INPUT/InstaLaySetup.exe" ]]; then
      cp "$INPUT/InstaLaySetup.exe" "$OUTPUT/${NAME}-setup.exe"
    fi
    if [[ -f "$INPUT/insta_lay.msix" ]]; then
      cp "$INPUT/insta_lay.msix" "$OUTPUT/${NAME}.msix"
    fi
    STAGE="$OUTPUT/_stage_win"
    rm -rf "$STAGE"
    mkdir -p "$STAGE"
    cp -R "$INPUT"/. "$STAGE/"
    (
      cd "$STAGE"
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
    VOL="InstaLay"
    STAGE="$OUTPUT/_stage_dmg"
    rm -rf "$STAGE" "$DMG"
    mkdir -p "$STAGE"
    cp -R "$APP_PATH" "$STAGE/"
    ln -sf /Applications "$STAGE/Applications"
    hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUTPUT/${NAME}.zip"
    rm -rf "$STAGE"
    ;;
  linux)
    TAR="$OUTPUT/${NAME}.tar.gz"
    (
      cd "$INPUT"
      tar -czf "$TAR" .
    )
    if command -v appimagetool >/dev/null 2>&1; then
      APPDIR="$OUTPUT/${NAME}.AppDir"
      rm -rf "$APPDIR"
      mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications"
      cp -R "$INPUT"/. "$APPDIR/usr/bin/"
      cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/insta_lay" "$@"
EOF
      chmod +x "$APPDIR/AppRun"
      find "$APPDIR/usr/bin" -maxdepth 2 -type f -name 'insta_lay' -exec chmod +x {} \;
      cat > "$APPDIR/insta-lay.desktop" <<EOF
[Desktop Entry]
Name=InstaLay
Exec=insta_lay
Icon=insta-lay
Type=Application
Categories=Graphics;Photography;
EOF
      cp "$APPDIR/insta-lay.desktop" "$APPDIR/usr/share/applications/"
      : > "$APPDIR/insta-lay.png"
      ARCH_LABEL="$ARCH"
      [[ "$ARCH" == "x64" ]] && ARCH_LABEL="x86_64"
      [[ "$ARCH" == "arm64" ]] && ARCH_LABEL="aarch64"
      export ARCH="$ARCH_LABEL"
      appimagetool "$APPDIR" "$OUTPUT/${NAME}.AppImage" || true
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
