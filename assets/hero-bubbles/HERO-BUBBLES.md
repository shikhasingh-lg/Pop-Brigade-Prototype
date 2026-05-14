# Pop Brigade — Hero Bubbles

Special bubble variant that **spawns a hero of its color when matched**. Visually distinct from regular bubbles so players can spot them at a glance in the cluster.

256×256 portraits, downscaled + background-removed. Style: same chibi cartoon as regular bubbles, with a small hero face / icon inside.

## Roster

| Slug | BubbleColor int | Spawns hero | File |
|---|---|---|---|
| `red` | 0 | Fire Knight (Ember) | `red/red.png` |
| `blue` | 1 | Ice Mage (Frost) | `blue/blue.png` |
| `yellow` | 2 | Archer (Robin) | `yellow/yellow.png` |
| `green` | 3 | Druid (Willow, v2) | `green/green.png` |
| `purple` | 4 | Wizard (Merlin, v2) | `purple/purple.png` |

## Files per hero bubble
- `<slug>/<slug>.png` — 256² white background
- `<slug>/<slug>-cutout.png` — 256² transparent
- `<slug>/<slug>-src.png` — high-res source

## Wired into Godot
Exposed through the existing `BubbleRoster` autoload (no new autoload — they share the same `BubbleColor` keying).

```gdscript
BubbleRoster.get_hero_cutout(GameConfig.BubbleColor.RED)   # transparent
BubbleRoster.get_hero_texture(GameConfig.BubbleColor.RED)  # white bg
```

## How to use in the cluster

`Bubble.gd` has an `is_hero_bubble: bool` flag. When set true, the bubble renders the hero-bubble art instead of the regular bubble art **and** spawns a hero of that color on match.

**Set on spawn:**
```gdscript
var b: Bubble = bubble_scene.instantiate()
b.color = GameConfig.BubbleColor.RED
b.is_hero_bubble = true
```

**Flip at runtime:**
```gdscript
existing_bubble.set_hero_bubble(true)
```

## Gameplay wiring (live)

Hero spawning is now gated on hero bubbles — **regular matches no longer spawn heroes**.

- **Placement rule:** `Cluster.setup_for_stage` calls `_seed_hero_bubbles(N)` after building the grid. `N` is rolled per stage from `GameConfig.hero_bubble_count_weights` — default 1–4 with weights `[0.20, 0.30, 0.30, 0.20]` (P(1)=20%, P(2)=30%, P(3)=30%, P(4)=20%). Eligible cells exclude color bombs.
- **Spawn trigger:** `Cluster._pop_match` collects the colors of any matched hero bubbles and ships them in the `match_popped` signal's `hero_colors: Array` arg. `MatchScene._on_match_popped` iterates that array and calls `lane.spawn_hero(hero_color, tier, spawn_col, "hero_bubble")` — one hero per hero bubble in the cleared group.
- **Tier:** still scales with the overall match size (3 = bronze, 4 = silver, 5+ = gold), so chaining multiple hero bubbles into one match upgrades them all.
- **Mid-stage refresh:** `GameConfig.hero_bubble_grow_chance` adds hero bubbles to top-row growth (defaults to `0.0` — off).

Tuning knobs in `GameConfig.gd` under the `Specials` group.

## Reprocessing
```bash
cd ~/game-research/pop-brigade/godot-prototype/assets/hero-bubbles
python3 process_hero_bubbles.py
```
