#!/usr/bin/env python3
"""Generate InstaLay raster icons from assets/branding/instalay_logo.png (RGBA)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MASTER_PNG = ROOT / "assets" / "branding" / "instalay_logo.png"
MASTER_SVG = ROOT / "assets" / "branding" / "instalay_logo.svg"


def load_mark(size: int | None = None) -> Image.Image:
    im = Image.open(MASTER_PNG).convert("RGBA")
    if size is not None and im.size != (size, size):
        im = im.resize((size, size), Image.Resampling.LANCZOS)
    return im


def opaque_on(bg: tuple[int, int, int, int], size: int) -> Image.Image:
    mark = load_mark(size)
    canvas = Image.new("RGBA", (size, size), bg)
    canvas.alpha_composite(mark)
    # iOS App Store rejects icons with an alpha channel
    return canvas.convert("RGB")


def save_png(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, format="PNG", optimize=True)
    print(f"wrote {path.relative_to(ROOT)} ({im.size[0]}x{im.size[1]} {im.mode})")


def maskable(size: int, pad_ratio: float = 0.12) -> Image.Image:
    """PWA maskable: mark inset in safe zone on dark plate."""
    canvas = Image.new("RGBA", (size, size), (18, 18, 18, 255))
    inner = int(round(size * (1 - 2 * pad_ratio)))
    mark = load_mark(inner)
    offset = (size - inner) // 2
    canvas.alpha_composite(mark, (offset, offset))
    return canvas


def main() -> None:
    if not MASTER_PNG.is_file():
        raise SystemExit(f"missing master PNG: {MASTER_PNG}")

    master = load_mark(1024)
    save_png(master, MASTER_PNG)

    # Copies for packaging / site
    for dest in (
        ROOT / "web" / "icons" / "instalay_logo.png",
        ROOT / "website" / "public" / "instalay_logo.png",
        ROOT / "windows" / "runner" / "resources" / "instalay_logo.png",
    ):
        save_png(master, dest)

    # Web favicon + PWA icons
    save_png(load_mark(48), ROOT / "web" / "favicon.png")
    save_png(load_mark(192), ROOT / "web" / "icons" / "Icon-192.png")
    save_png(load_mark(512), ROOT / "web" / "icons" / "Icon-512.png")
    save_png(maskable(192), ROOT / "web" / "icons" / "Icon-maskable-192.png")
    save_png(maskable(512), ROOT / "web" / "icons" / "Icon-maskable-512.png")

    # Windows multi-resolution ICO (Pillow resizes from largest)
    ico_sizes = [(16, 16), (32, 32), (48, 48), (256, 256)]
    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    load_mark(256).save(ico_path, format="ICO", sizes=ico_sizes)
    print(f"wrote {ico_path.relative_to(ROOT)} sizes={[s[0] for s in ico_sizes]}")

    # macOS AppIcon set
    mac_dir = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for s in (16, 32, 64, 128, 256, 512, 1024):
        save_png(load_mark(s), mac_dir / f"app_icon_{s}.png")

    # iOS — App Store 1024 must be opaque (no alpha)
    ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_specs = [
        ("Icon-App-20x20@1x.png", 20, False),
        ("Icon-App-20x20@2x.png", 40, False),
        ("Icon-App-20x20@3x.png", 60, False),
        ("Icon-App-29x29@1x.png", 29, False),
        ("Icon-App-29x29@2x.png", 58, False),
        ("Icon-App-29x29@3x.png", 87, False),
        ("Icon-App-40x40@1x.png", 40, False),
        ("Icon-App-40x40@2x.png", 80, False),
        ("Icon-App-40x40@3x.png", 120, False),
        ("Icon-App-60x60@2x.png", 120, False),
        ("Icon-App-60x60@3x.png", 180, False),
        ("Icon-App-76x76@1x.png", 76, False),
        ("Icon-App-76x76@2x.png", 152, False),
        ("Icon-App-83.5x83.5@2x.png", 167, False),
        ("Icon-App-1024x1024@1x.png", 1024, True),
    ]
    dark = (18, 18, 18, 255)
    for name, size, force_opaque in ios_specs:
        if force_opaque:
            im = opaque_on(dark, size)
        else:
            # Device icons: composite on dark so home-screen never shows checkerboard
            im = opaque_on(dark, size)
        save_png(im, ios_dir / name)

    # Android mipmaps
    android = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android.items():
        # Launcher icons look better on an opaque dark plate
        save_png(opaque_on(dark, size), ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png")

    # Website SVG copy
    svg_dst = ROOT / "website" / "public" / "instalay_logo.svg"
    svg_dst.write_text(MASTER_SVG.read_text(encoding="utf-8"), encoding="utf-8")
    print(f"wrote {svg_dst.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
