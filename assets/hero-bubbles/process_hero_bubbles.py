#!/usr/bin/env python3
# Downscale hero-bubble icons to 256² and background-remove via rembg.
# Hero bubbles are special bubbles that spawn a hero when matched —
# they need to read distinctly from regular bubbles at the same 72px in-game size.

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent
COLORS = ["red", "blue", "yellow", "green", "purple"]
TARGET = 256

try:
    from rembg import remove
    HAS_REMBG = True
except ImportError:
    HAS_REMBG = False
    print("[info] rembg not installed — skipping background removal.")

def process(slug: str) -> None:
    folder = ROOT / slug
    src = folder / f"{slug}.png"
    if not src.exists():
        print(f"[skip] {slug}: source not found at {src}")
        return

    archive = folder / f"{slug}-src.png"
    if not archive.exists():
        src.replace(archive)
    else:
        src.unlink(missing_ok=True)

    img = Image.open(archive).convert("RGBA")
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
        co = Image.open(cutout).convert("RGBA")
        w, h = co.size
        side = min(w, h)
        left = (w - side) // 2
        top = (h - side) // 2
        co = co.crop((left, top, left + side, top + side))
        co = co.resize((TARGET, TARGET), Image.LANCZOS)
        co.save(cutout)
        print(f"[ok]   {slug}: cutout → {cutout.name}")

for slug in COLORS:
    process(slug)

print("\nDone.")
