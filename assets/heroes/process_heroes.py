#!/usr/bin/env python3
# Downscale hero portraits to 512² and (optionally) background-remove.
#
# Run:    python3 process_heroes.py
# Optional background removal: pip install rembg onnxruntime  (then re-run)
#
# Input:  <slug>/<slug>.png            (source, any size, white bg)
# Output: <slug>/<slug>.png            (overwritten: 512² downscaled)
#         <slug>/<slug>-src.png        (untouched source, renamed)
#         <slug>/<slug>-cutout.png     (transparent, if rembg installed)

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent
HEROES = ["fire-knight", "ice-mage", "druid", "archer", "wizard"]
TARGET = 512

try:
    from rembg import remove
    HAS_REMBG = True
except ImportError:
    HAS_REMBG = False
    print("[info] rembg not installed — skipping background removal.")
    print("[info] to enable: pip install rembg onnxruntime")

def process(slug: str) -> None:
    folder = ROOT / slug
    src = folder / f"{slug}.png"
    if not src.exists():
        print(f"[skip] {slug}: source not found at {src}")
        return

    # Preserve original
    archive = folder / f"{slug}-src.png"
    if not archive.exists():
        src.replace(archive)
    else:
        src.unlink(missing_ok=True)

    img = Image.open(archive).convert("RGBA")

    # Center-crop to square then downscale to 512²
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    img = img.crop((left, top, left + side, top + side))
    img = img.resize((TARGET, TARGET), Image.LANCZOS)
    img.save(src)
    print(f"[ok]   {slug}: downscaled → {src.name} ({TARGET}x{TARGET})")

    if HAS_REMBG:
        cutout = folder / f"{slug}-cutout.png"
        with open(archive, "rb") as f:
            data = f.read()
        out = remove(data)
        cutout.write_bytes(out)
        # Also downscale the cutout
        co = Image.open(cutout).convert("RGBA")
        w, h = co.size
        side = min(w, h)
        left = (w - side) // 2
        top = (h - side) // 2
        co = co.crop((left, top, left + side, top + side))
        co = co.resize((TARGET, TARGET), Image.LANCZOS)
        co.save(cutout)
        print(f"[ok]   {slug}: cutout → {cutout.name}")

for slug in HEROES:
    process(slug)

print("\nDone.")
