# Pop Brigade — Hero Roster v1

Generated portraits, downscaled to 512×512. Bust shots (head + upper torso, 3/4 view right). Style: chibi, flat cel-shaded, bold outline.

## Roster

| Slug | Name | Archetype | Color | v1 Active | File |
|---|---|---|---|---|---|
| `fire-knight` | Ember | Fire Knight — tank | RED | ✅ | `fire-knight/fire-knight.png` |
| `ice-mage` | Frost | Ice Mage — slow AoE | BLUE | ✅ | `ice-mage/ice-mage.png` |
| `archer` | Robin | Archer — single-target | YELLOW | ✅ | `archer/archer.png` |
| `druid` | Willow | Druid — healer | GREEN (v2) | ⏳ | `druid/druid.png` |
| `wizard` | Merlin | Wizard — burst AoE | PURPLE (v2) | ⏳ | `wizard/wizard.png` |

## Files per hero
- `<slug>/<slug>.png` — 512² portrait, **white background** (cards, menus)
- `<slug>/<slug>-cutout.png` — 512² **transparent background** (lane sprites, in-game)
- `<slug>/<slug>-src.png` — original high-res source (kept for re-processing)

## Wired into Godot
- **Autoload:** `HeroRoster` (`scripts/HeroRoster.gd`) — registry, lookup by slug or color
- **Scene:** `scenes/HeroCard.tscn` — drop-in display widget
- **Script:** `scripts/HeroCard.gd`

## Usage in GDScript

```gdscript
# White-bg portrait (cards, menus)
var tex: Texture2D = HeroRoster.get_portrait("fire-knight")

# Transparent cutout (for placing over lane backgrounds)
var sprite: Texture2D = HeroRoster.get_cutout("fire-knight")

# Get full entry
var entry := HeroRoster.get_entry("ice-mage")
print(entry["name"], entry["role"])

# Look up the active hero for a BubbleColor (RED → fire-knight)
var red_hero := HeroRoster.get_for_color(GameConfig.BubbleColor.RED)

# List active v1 heroes
for slug in HeroRoster.active_slugs():
	print(slug)
```

## Usage in scene
Drag `scenes/HeroCard.tscn` into any scene. In the Inspector, set `Hero Slug` to one of:
- `fire-knight`, `ice-mage`, `archer`, `druid`, `wizard`

Or at runtime:
```gdscript
$HeroCard.set_hero("druid")
```

## Reprocessing artwork
Re-run downscale + (optional) background removal:
```bash
cd ~/game-research/pop-brigade/godot-prototype/assets/heroes
python3 process_heroes.py
```

For transparent cutouts, install rembg first:
```bash
pip3 install rembg onnxruntime
```

## Next steps for full integration
1. Swap `Hero.tscn` greybox `ColorRect` for `HeroCard.tscn` keyed off the hero's BubbleColor → slug mapping (use `HeroRoster.get_for_color()`).
2. Add a hero pick screen between stages using `HeroCard` as the tile.
3. Run background removal (install `rembg`) so portraits composite cleanly over the lane background.
