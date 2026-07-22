#!/usr/bin/env bash
# Emit a Markdown release body with an asset table and SHA-256 checksums.
# Usage: scripts/release_notes.sh <version> <asset_dir>
set -euo pipefail

VERSION="${1:?version}"
DIR="${2:?asset dir}"
REPO="${GITHUB_REPOSITORY:-LinxPhotos/InstaLay}"
TAG="v${VERSION}"
ASSET_BASE="https://github.com/${REPO}/releases/download/${TAG}"

echo "## InstaLay v${VERSION}"
echo
echo "Batch canvas, no-crop framing, and SCRL-style tapestry layouts for Instagram."
echo

HIGHLIGHTS="$(dirname "$0")/release-highlights/${VERSION}.md"
if [[ -f "$HIGHLIGHTS" ]]; then
  echo "### What's new"
  echo
  cat "$HIGHLIGHTS"
  echo
fi

echo "### Downloads"
echo
echo "| Platform | Arch | Package | SHA-256 |"
echo "|----------|------|---------|---------|"

shopt -s nullglob
for f in "$DIR"/*; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f")"
  # Skip checksum files themselves
  [[ "$base" == *.sha256 ]] && continue
  [[ "$base" == SHA256SUMS ]] && continue

  platform="—"
  arch="—"
  kind="archive"

  case "$base" in
    *windows*) platform="Windows" ;;
    *macos*) platform="macOS" ;;
    *linux*) platform="Linux" ;;
  esac
  case "$base" in
    *x64*|*x86_64*) arch="x64" ;;
    *arm64*|*aarch64*) arch="arm64" ;;
  esac
  case "$base" in
    *.exe|*setup*) kind="installer" ;;
    *.msix) kind="MSIX" ;;
    *.dmg) kind="DMG" ;;
    *.AppImage) kind="AppImage" ;;
    *.zip) kind="ZIP" ;;
    *.tar.gz) kind="tar.gz" ;;
  esac

  if command -v sha256sum >/dev/null 2>&1; then
    hash="$(sha256sum "$f" | awk '{print $1}')"
  else
    hash="$(shasum -a 256 "$f" | awk '{print $1}')"
  fi
  url="${ASSET_BASE}/${base}"
  echo "| ${platform} | ${arch} | [\`${base}\`](${url}) (${kind}) | \`${hash}\` |"
done

echo
echo "### Install"
echo
echo '```text'
echo "# Windows (winget) -- after package acceptance"
echo "winget install LinxPhotos.InstaLay"
echo
echo "# macOS (Homebrew)"
echo "brew install --cask amdphreak/tap/instalay"
echo
echo "# Linux (portable)"
echo "tar -xzf InstaLay-${VERSION}-linux-x64.tar.gz && ./insta_lay"
echo '```'
echo
echo "### Notes"
echo
echo "- Portable ZIP/tar bundles include the Flutter desktop runner."
echo "- Windows setup EXE is built with Inno Setup when available on the builder."
echo "- macOS builds are unsigned in CI unless Apple notarization secrets are configured."
echo
echo "See [CHANGELOG.adoc](https://github.com/${REPO}/blob/${TAG}/CHANGELOG.adoc) for details."
