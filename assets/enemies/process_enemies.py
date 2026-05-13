#!/usr/bin/env python3
# Downscale enemy portraits to 512² and background-remove via rembg.
# Same pipeline as ../heroes/process_heroes.py — kept separate so each
# roster can be reprocessed independently.
#
# Run:  python3 process_enemies.py

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent
ENEMIES = ["red-goblin", "blue-slime", "yellow-brute", "green-spore", "goop-king"]
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

for slug in ENEMIES:
    process(slug)

print("\nDone.")
