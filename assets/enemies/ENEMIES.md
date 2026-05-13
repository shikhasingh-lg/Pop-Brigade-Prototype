# Pop Brigade — Enemy Roster v1

Generated portraits, downscaled to 512×512. Bust shots (head + upper torso, 3/4 view **left** — visually mirrored from heroes). Style: chibi, flat cel-shaded, bold outline, gooey/monstrous body shapes.

## Roster

| Slug | Name | Archetype | Color | HP | Speed | Dmg | v1 Active |
|---|---|---|---|---|---|---|---|
| `red-goblin` | Snag | Fast melee rusher | RED | 50 | 1.0 s/cell | 10 | ✅ |
| `blue-slime` | Glub | Slow tank | BLUE | 80 | 1.5 s/cell | 10 | ✅ |
| `yellow-brute` | Zap | Heavy hitter | YELLOW | 120 | 1.2 s/cell | 15 | ✅ |
| `green-spore` | Mossy | Healer-minion | GREEN (v2) | tbd | tbd | tbd | ⏳ |
| `goop-king` | Goop King | Stage 5 boss | multi | 1000 | — | 50 | ✅ |
| `purple-wisp` | Hex | Caster | PURPLE (v2) | — | — | — | ❌ art pending |

Stats sourced from `GameConfig.gd` §3.6.

## Files per enemy
- `<slug>/<slug>.png` — 512² portrait, white background
- `<slug>/<slug>-cutout.png` — 512² transparent background
- `<slug>/<slug>-src.png` — original high-res source

## Wired into Godot
- **Autoload:** `EnemyRoster` (`scripts/EnemyRoster.gd`)
- **Scene:** `scenes/EnemyCard.tscn`
- **Script:** `scripts/EnemyCard.gd`

## Usage in GDScript

```gdscript
# Transparent cutout (default, for in-game lane sprites)
$Lane.texture = EnemyRoster.get_cutout("red-goblin")

# White-bg portrait (for menus, codex screens)
$Card.texture = EnemyRoster.get_portrait("red-goblin")

# Lookup by color (BubbleColor.RED → red-goblin entry)
var enemy := EnemyRoster.get_for_color(GameConfig.BubbleColor.RED)

# Stage 5 boss
var boss := EnemyRoster.boss_slug()    # "goop-king"

# All non-boss walkers (for wave spawning)
for slug in EnemyRoster.walker_slugs():
	print(slug)
```

## Usage in scene
Instance `scenes/EnemyCard.tscn`, set `Enemy Slug` in the Inspector to:
- `red-goblin`, `blue-slime`, `yellow-brute`, `green-spore`, `goop-king`

Or at runtime:
```gdscript
$EnemyCard.set_enemy("blue-slime")
```

## Reprocessing
```bash
cd ~/game-research/pop-brigade/godot-prototype/assets/enemies
python3 process_enemies.py
```

## Missing art
- `purple-wisp` — v2 PURPLE enemy. Generate using the master enemy prompt template from `pop_brigade_hero_pipeline.md` memory (purple/magenta/lilac palette, witch-hat wisp). After generation, copy to `purple-wisp/purple-wisp.png`, re-run `process_enemies.py`, and add an entry to `EnemyRoster.gd`'s `ROSTER` dict.
