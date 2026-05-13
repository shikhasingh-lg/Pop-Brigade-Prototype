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

`Bubble.gd` now has an `is_hero_bubble: bool` flag (defaults `false` — no behavior change for existing code). When set true, the bubble renders the hero-bubble art instead of the regular bubble art.

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

## What's NOT yet wired (gameplay side)

Right now `is_hero_bubble` only affects rendering. To make hero bubbles actually spawn a hero on match, edit the match-handling path in `MatchScene.gd` / `Cluster.gd`:
- When a match clears, if any bubble in the cleared group had `is_hero_bubble = true`, call `lane.spawn_hero(color, tier, col, "hero_bubble")` (already exists for regular matches).
- Decide the **placement rule** — pre-seeded in the cluster on stage start? Converted from random regular bubbles every N shots? Spawned in Phase 2 only? This is a design call, not a wiring call.

## Reprocessing
```bash
cd ~/game-research/pop-brigade/godot-prototype/assets/hero-bubbles
python3 process_hero_bubbles.py
```
