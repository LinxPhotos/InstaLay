#!/usr/bin/env bash
# Build libjxl static headers/libs for jxl_ffi (Linux x86_64).
# Official release tar.lz only ships CLI tools; we install a dev prefix locally.
set -euo pipefail

VERSION="${1:-0.12.0}"
OUT="${2:-packages/jxl_ffi/native/prebuilt/linux-x86_64-static}"

if [[ -f "${OUT}/lib/libjxl.a" ]]; then
  echo "libjxl prebuilt already present at ${OUT}"
  exit 0
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "build_libjxl_prebuilt.sh: only x86_64 is supported (got $(uname -m))" >&2
  exit 1
fi

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1" >&2
    exit 1
  }
}
need git
need cmake
need ninja

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Cloning libjxl v${VERSION}..."
git clone --depth 1 --branch "v${VERSION}" --recurse-submodules \
  https://github.com/libjxl/libjxl.git "$WORK/libjxl"

PREFIX="$WORK/install"
mkdir -p "$PREFIX"

echo "Building libjxl static..."
cmake -S "$WORK/libjxl" -B "$WORK/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DJPEGXL_STATIC=ON \
  -DBUILD_TESTING=OFF \
  -DJPEGXL_ENABLE_TOOLS=OFF \
  -DJPEGXL_ENABLE_VIEWERS=OFF \
  -DJPEGXL_ENABLE_PLUGINS=OFF \
  -DJPEGXL_ENABLE_OPENEXR=OFF \
  -DJPEGXL_ENABLE_DEVTOOLS=OFF

cmake --build "$WORK/build" -j"$(nproc)"
cmake --install "$WORK/build"

mkdir -p "${OUT}/lib"
cp -a "${PREFIX}/include" "${OUT}/"
cp -a "${PREFIX}/lib/." "${OUT}/lib/"

if [[ ! -f "${OUT}/lib/libjxl.a" ]]; then
  echo "libjxl install did not produce ${OUT}/lib/libjxl.a" >&2
  ls -la "${OUT}/lib" || true
  exit 1
fi

echo "Installed libjxl prebuilt -> ${OUT}"
