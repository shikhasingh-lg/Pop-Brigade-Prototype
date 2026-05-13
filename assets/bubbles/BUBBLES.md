# Pop Brigade — Bubble Roster

Generated bubble icons, downscaled to 256×256 (bubbles are ~72px in-game; 256 is plenty of headroom for HUD and codex use). Style: chibi cartoon, soft highlight, flat cel-shaded.

## Roster

| Slug | BubbleColor int | v1 Active | File |
|---|---|---|---|
| `red` | 0 | ✅ | `red/red.png` |
| `blue` | 1 | ✅ | `blue/blue.png` |
| `yellow` | 2 | ✅ | `yellow/yellow.png` |
| `green` | 3 | ⏳ v2 | `green/green.png` |
| `purple` | 4 | ⏳ v2 | `purple/purple.png` |

## Files per bubble
- `<slug>/<slug>.png` — 256² (white background)
- `<slug>/<slug>-cutout.png` — 256² (transparent background)
- `<slug>/<slug>-src.png` — original high-res source

## Wired into Godot
- **Autoload:** `BubbleRoster` (`scripts/BubbleRoster.gd`)
- Keyed by `GameConfig.BubbleColor` int (not by slug — bubbles always have a deterministic color, no need for arbitrary lookup).

## Usage in GDScript

```gdscript
# Transparent (default — for in-game over lane/cluster)
var tex = BubbleRoster.get_cutout(GameConfig.BubbleColor.RED)

# White-bg (UI, codex)
var tex_ui = BubbleRoster.get_texture(GameConfig.BubbleColor.BLUE)

# Slug lookup
BubbleRoster.get_slug(GameConfig.BubbleColor.YELLOW)   # "yellow"

# All colors (v1 + v2)
for c in BubbleRoster.all_colors():
	print(c, BubbleRoster.get_slug(c))
```

## Current rendering vs. PNG art

`BubbleVisual.gd` currently draws bubbles **procedurally** (`draw_circle()` with a soft highlight) — used in the cannon HUD preview and on-deck slot. The PNG art is **not yet wired in**.

To switch the cannon/HUD bubbles to PNG:
1. Open `BubbleVisual.gd`
2. Replace the `_draw()` body with a `Sprite2D` child that loads `BubbleRoster.get_cutout(color_index)`
3. Or add a `use_texture: bool` toggle to keep procedural as a fallback.

For in-cluster bubbles (the main grid), the change goes in `Bubble.gd` / `Cluster.gd`.

## Reprocessing
```bash
cd ~/game-research/pop-brigade/godot-prototype/assets/bubbles
python3 process_bubbles.py
```

## See also
- `../hero-bubbles/HERO-BUBBLES.md` — special bubble variant that spawns a hero on match. Same color keying, exposed through the same `BubbleRoster` autoload.
