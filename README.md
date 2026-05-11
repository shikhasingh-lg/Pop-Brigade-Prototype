# Pop Brigade — v1 Godot Prototype Scaffold

> **Status:** Scaffold only. Project opens, runs to a status label. No gameplay implemented yet — that's the W1–W3 sprint per design spec §5.3.

## What this is

A skeleton Godot 4.2+ project for the v1 greybox playable prototype of Pop Brigade. The scaffold encodes the design spec as code:

- **Tuning values** (`scripts/GameConfig.gd`) — every number from §3.10 as an exported `@export var`. Designer-tunable without touching gameplay code.
- **Telemetry schema** (`scripts/Telemetry.gd`) — every event from §6.2 as a typed wrapper function. Engineers call these by name; payload schema can't drift from spec.
- **Gameplay script stubs** — `Cluster.gd`, `Cannon.gd`, `Lane.gd`, `Bubble.gd`, `Hero.gd`, `Enemy.gd`, `MatchScene.gd`. Class structure, signals, exported references, and `TODO` markers tied to spec subsections. Engineer fills in bodies.
- **Minimal scenes** — `Main.tscn` (loads on boot), `Bubble.tscn`, `Hero.tscn`, `Enemy.tscn`. Just enough that the project opens.

Companion docs (don't duplicate — read these first):
- Design spec: `~/game-research/pop-brigade/v1-design-spec.md`
- UI flow: `~/game-research/pop-brigade/v1-ui-flow.md`
- Concept one-pager: `~/game-research/pop-brigade/concept.md`

## How to open

1. Install Godot 4.2+ (https://godotengine.org/download)
2. Open Godot → Import → select `project.godot` in this folder
3. Press F5 (Run Project) — should open a 720×1560 portrait window with a status label
4. Confirm autoloads are loaded: Project → Project Settings → Autoload tab. Should see `GameConfig` and `Telemetry`.

If it opens without errors, the scaffold works.

## Folder structure

```
godot-prototype/
├── project.godot           # Godot project config (mobile preset, autoloads, portrait)
├── icon.svg                # Placeholder app icon
├── README.md               # This file
├── scenes/
│   ├── Main.tscn           # Boot scene (current entry point)
│   ├── Bubble.tscn         # Single bubble entity
│   ├── Hero.tscn           # Single hero entity
│   └── Enemy.tscn          # Single enemy entity
├── scripts/
│   ├── GameConfig.gd       # AUTOLOAD — §3.10 tuning values
│   ├── Telemetry.gd        # AUTOLOAD — §6.2 event logging
│   ├── Main.gd             # Top-level screen switcher
│   ├── MatchScene.gd       # Match orchestrator (cluster + lane + cannon)
│   ├── Cluster.gd          # §3.2 — hex grid, descent, match detection
│   ├── Cannon.gd           # §3.3 — aim, fire, queue, swap
│   ├── Lane.gd             # §3.5 + §3.6 — heroes + enemies
│   ├── Bubble.gd           # Single bubble (in-flight + attached)
│   ├── Hero.gd             # §3.4 + §3.5 — stationary, auto-fire
│   └── Enemy.gd            # §3.6 — march, take damage, reach cannon
└── assets/                 # (empty — greybox uses ColorRect placeholders)
```

## Spec → code map

| Spec section | Implemented in | Status |
|---|---|---|
| §3.1 Spatial layout | `GameConfig.gd` (zone percents) | ✓ Constants set |
| §3.2 Cluster | `Cluster.gd` | ⏳ Stubs + TODOs |
| §3.3 Aim & fire | `Cannon.gd` | ⏳ Stubs + TODOs |
| §3.4 Hero spawn rules | `MatchScene.gd::_on_match_popped()` | ✓ Tier mapping done; column logic TODO |
| §3.5 Hero behavior | `Hero.gd`, `Lane.gd::find_enemy_in_range` | ⏳ Stubs + TODOs |
| §3.6 Enemy behavior | `Enemy.gd`, `Lane.gd::spawn_enemy_*` | ⏳ Stubs + TODOs |
| §3.7 Color bomb | `Cannon.gd::_is_color_bomb()` | ✓ Cadence done; effect TODO |
| §3.8 Win/lose | `MatchScene.gd::_fail_stage()` + `_clear_stage()` | ✓ State machine done; screen switch TODO |
| §3.10 Tuning table | `GameConfig.gd` | ✓ Fully encoded |
| §4.2 Boons | `MatchScene.gd::_apply_boon()`, `Cannon.gd::apply_boon()`, `Lane.gd::apply_damage_boon()` | ✓ Wired; missing some applications |
| §5 Stages | `MatchScene.gd::start_stage()` + `GameConfig.get_stage_*` | ✓ Per-stage tuning ready |
| §6.2 Telemetry events | `Telemetry.gd` | ✓ Fully encoded |

## Build sprint plan (mirrors design spec §5.3)

### Week 1 — Cluster physics
- [ ] Implement `Cluster.setup_for_stage()` — populate hex grid with random colors
- [ ] Implement `Cluster.attach_bubble()` — nearest-hex snap, match detection
- [ ] Implement `Cluster._descend_one_row()` — visual + spawn-line crossing logic
- [ ] Implement `Cluster._pop_match()` — flood-fill detection, falling bubbles
- [ ] Implement `Bubble.gd` physics (velocity, attach trigger, ricochet)
- [ ] **W1 gate:** Cluster alone is playable. No lane yet. Greybox bubbles fire, attach, pop, fall.

### Week 2 — Lane + heroes + enemies
- [ ] Implement `Cannon.gd` input (touch-and-hold, drag-aim, release-fire)
- [ ] Implement `Cannon._draw_from_palette()` weighting + queue swap
- [ ] Implement `Hero._try_fire()` targeting + damage
- [ ] Implement `Enemy._advance_cell()` movement + reach cannon
- [ ] Implement `Lane.find_enemy_in_range()` + `_replace_most_damaged_hero()`
- [ ] **W2 gate:** Full match playable on stages 1–3. Debug-only HUD.

### Week 3 — Stages 4–5, screens, telemetry
- [ ] Stage 4 (color bomb appears) + Stage 5 (boss)
- [ ] Implement 7 remaining screens (MetaHub, Loadout, Pause, StageClear, StageFail, RunEnd) — see UI flow doc
- [ ] Wire all `Telemetry.log_*()` call sites (every TODO `Telemetry.log_*` in scripts)
- [ ] **W3 gate:** All 8 screens connected, full run playable, telemetry firing to `.jsonl`

## How telemetry works

Every gameplay-relevant event calls `Telemetry.log_*(...)`. Output:

```
~/Library/Application Support/Godot/app_userdata/Pop Brigade v1/logs/
  pop-brigade-v1-<tester_id>-<utc_ts>.jsonl
```

One JSON object per line. Each event has `event_name` + `ts_ms` (from session start) + payload. Schema matches §6.2 exactly so post-session analysis scripts can be deterministic.

To start a real session for a tester (replaces "dev" default in `Main.gd::_ready`):
```gdscript
Telemetry.start_session("T07")
```

To end:
```gdscript
Telemetry.end_session(runs_completed)
```

## Key open questions (design spec §7.1)

These should be resolved DURING the build, not before:
- **OQ1:** Should bubble→enemy conversion be morph animation or instant swap? (W2 internal eyeball)
- **OQ3:** Does greybox produce valid readability signal, or does art-absence pollute Q1? (After tester 2–3)
- **OQ5:** 8 vs 7 cluster columns on small phones? (W1 prototype on Pixel 6a)
- **OQ7:** Cluster descent timer-based vs shots-based vs both? (W1–W2 internal A/B)

## Locked variant — DO NOT CHANGE without re-spec

**V2: Cluster-as-spawner.** Bubbles that cross spawn line CONVERT to enemies. This is what we're testing. If paper-test or playtest signal says V2 fails (Q1 in §6.1), we pivot to V3 (bubble bank) or V5 (pop-point spawn) — see `~/.claude/projects/-Users-shikhasingh/memory/game_concept_variants.md`. **Do not silently iterate on V2 past 2 paper-test rounds** (see §7.2 risk row 1).

## Conventions

- Tuning value? → `GameConfig.gd` (never hard-code)
- Logged event? → `Telemetry.log_<name>()` (never raw `print()` for gameplay events)
- New mechanic that's NOT in design spec? → Spec it first; code second. Out-of-scope additions kill v1 signal.
- New color/class? → No. v1 = 3 colors (Red/Blue/Yellow). Green/Purple are v2 per §5.2.
