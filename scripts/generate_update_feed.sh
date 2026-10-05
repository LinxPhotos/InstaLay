#!/usr/bin/env bash
# Build updates/latest.json from a release asset directory (+ SHA256SUMS).
# Usage: scripts/generate_update_feed.sh <version> <asset_dir> [output_json]
set -euo pipefail

VERSION="${1:?version}"
DIR="${2:?asset dir}"
OUT="${3:-$DIR/latest.json}"
REPO="${GITHUB_REPOSITORY:-LinxPhotos/InstaLay}"
TAG="v${VERSION}"
ASSET_BASE="https://github.com/${REPO}/releases/download/${TAG}"
PUBLISHED_AT="${PUBLISHED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
NOTES_URL="${NOTES_URL:-https://github.com/${REPO}/releases/tag/${TAG}}"

hash_for() {
  local base="$1"
  local sums="$DIR/SHA256SUMS"
  if [[ -f "$sums" ]]; then
    # SHA256SUMS lines: "<hash>  <filename>" or "<hash> *<filename>"
    local line
    line="$(grep -E "[[:space:]](\*|)${base}\$" "$sums" | head -n1 || true)"
    if [[ -n "$line" ]]; then
      echo "$line" | awk '{print $1}'
      return 0
    fi
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$DIR/$base" | awk '{print $1}'
  else
    shasum -a 256 "$DIR/$base" | awk '{print $1}'
  fi
}

size_for() {
  local f="$DIR/$1"
  if [[ -f "$f" ]]; then
    wc -c <"$f" | tr -d ' '
  else
    echo "null"
  fi
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))' <<<"$1"
}

pick_windows() {
  local arch="$1"
  local setup="InstaLay-${VERSION}-windows-${arch}-setup.exe"
  if [[ -f "$DIR/$setup" ]]; then
    echo "$setup|exe-setup"
    return
  fi
  echo ""
}

pick_macos() {
  local arch="$1"
  local zip="InstaLay-${VERSION}-macos-${arch}.zip"
  if [[ -f "$DIR/$zip" ]]; then
    echo "$zip|zip-app"
    return
  fi
  echo ""
}

emit_platform() {
  local key="$1"
  local file="$2"
  local kind="$3"
  [[ -n "$file" ]] || return 0
  local hash size url
  hash="$(hash_for "$file")"
  size="$(size_for "$file")"
  url="${ASSET_BASE}/${file}"
  printf '    "%s": {\n' "$key"
  printf '      "url": %s,\n' "$(json_escape "$url")"
  printf '      "sha256": %s,\n' "$(json_escape "$hash")"
  printf '      "signature": null,\n'
  printf '      "installerKind": %s,\n' "$(json_escape "$kind")"
  if [[ "$size" == "null" ]]; then
    printf '      "size": null\n'
  else
    printf '      "size": %s\n' "$size"
  fi
  printf '    }'
}

platforms=()
win_x64="$(pick_windows x64)"
win_arm="$(pick_windows arm64)"
mac_arm="$(pick_macos arm64)"
mac_x64="$(pick_macos x64)"

tmp="$(mktemp)"
{
  echo '{'
  echo "  \"schemaVersion\": 1,"
  echo "  \"version\": $(json_escape "$VERSION"),"
  echo "  \"channel\": \"stable\","
  echo "  \"publishedAt\": $(json_escape "$PUBLISHED_AT"),"
  echo "  \"notes\": $(json_escape "InstaLay ${TAG}"),"
  echo "  \"notesUrl\": $(json_escape "$NOTES_URL"),"
  echo '  "mandatory": false,'
  echo '  "platforms": {'

  first=1
  add() {
    local key="$1" spec="$2"
    [[ -n "$spec" ]] || return 0
    local file="${spec%%|*}"
    local kind="${spec##*|}"
    if [[ $first -eq 0 ]]; then echo ','; fi
    first=0
    emit_platform "$key" "$file" "$kind"
    echo
  }
  add "windows-x64" "$win_x64"
  add "windows-arm64" "$win_arm"
  add "macos-arm64" "$mac_arm"
  add "macos-x64" "$mac_x64"

  echo '  }'
  echo '}'
} >"$tmp"

mkdir -p "$(dirname "$OUT")"
mv "$tmp" "$OUT"
echo "Wrote $OUT"
cat "$OUT"
