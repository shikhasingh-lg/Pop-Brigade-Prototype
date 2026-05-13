# Pop Brigade — Combat Design (Heroes + Enemies)

> Sets per-class attack mechanics, targeting, visuals, hero placement/drag rules, and enemy progression.
> Companion to `design-spec.md` §3.4–3.6.

> **Architecture (recap):** Phased Build → Wave. Phase 1 = bubble cluster + move budget + hero-bubble pops freeing heroes (heroes stationary). Phase 2 = combat with cluster-converted enemies + scripted wave; heroes auto-attack and are **draggable along row 0**.

---

## 1 — Hero classes (v1 enabled)

Lane geometry: heroes stand at **row 0** (the spawn line). Enemies enter at **row -15** (top of device), drop fast through rows -15…-1 at 0.25 s/cell, then march row 0 → row 5 at colour-stat speed. Each row = 60 px. **Row 0 is the spawn line.**

| Class (color) | Targeting zone | Fire rate | Damage | Special | Fantasy |
|---|---|---|---|---|---|
| **Fire Knight** (RED) | Cone in front, 4 rows × ±1 col (rows -4…0) | 0.75 s | 1.0× base | 25% chance: **cleave** — also hits enemies in adjacent columns of the same row | Frontline bruiser. Cuts through enemies as they cross the line. |
| **Ice Mage** (BLUE) | Whole column, +1 col splash, rows -10…0 | 1.6 s | 0.7× base | **AoE blast at impact** — 1.5-cell radius. All enemies in radius take damage + 30% slow / 2 s | Standoff caster. Lobs into upper lane; tags packs. |
| **Archer** (YELLOW) | Whole column straight up, rows -15…0 (full screen) | 1.2 s | 1.4× base | **Furthest-first** target priority. **Execute:** +50% dmg vs enemies under 30% HP | Long-range sniper. Drops threats before they're a problem. |

**Notes:**
- Tier (Bronze/Silver/Gold) scales **base HP + base damage**; class multipliers stack on top.
- Color counter (2× vs same-color enemy) and frenzy (+50% during P2 wave) rules from spec §3.5 apply.
- All combat (fire, drag, take damage) happens in Phase 2 only. In Phase 1 heroes stand idle.

### 1.1 — Targeting rules per class

**Fire Knight (RED) — Cone**
- Pick enemies with `lane_col ∈ [hero.col − 1, hero.col + 1]` AND `lane_row ∈ [−4, 0]`.
- Sort by `lane_row` descending (closest to spawn line first — kills imminent threats).
- 25% roll on attack: deal damage to up to 2 additional enemies in the same row in the cone (cleave).

**Ice Mage (BLUE) — Column with splash**
- Primary target: enemy with smallest `lane_row` (highest up the lane) in `lane_col ∈ [hero.col − 1, hero.col + 1]`, range `lane_row ∈ [−10, 0]`.
- On hit, AoE: every enemy within 1.5 cells (Euclidean) of impact takes the same damage and gets slowed.
- Slow stacks refresh (don't add).

**Archer (YELLOW) — Snipe**
- Pick enemy with smallest `lane_row` in `lane_col == hero.col`, range `lane_row ∈ [−15, 0]`.
- If no enemy in own column, fall back to adjacent columns (±1).
- Execute bonus: if target HP/max_HP < 0.30, multiply final damage ×1.5.

### 1.2 — Visual effects per class (~0.25 s each)

| Class | VFX |
|---|---|
| **Fire Knight** | Forward lunge (hero scales 1.1× + slides 8 px toward target for 120 ms, then snaps back). Red **wedge** in front (Polygon2D, 90° arc, ~120 px reach). Subtle ember Particles2D upward. |
| **Ice Mage** | Hero raises slightly (offset y −6 px). Cyan **shard** (small Sprite or Polygon2D triangle) tweens hero to target along a low-arc curve over 180 ms. On impact, **filled circle ring** (Polygon2D, alpha 0.35) expands from 0 → 1.5 cells over 200 ms then fades. |
| **Archer** | Hero recoils −4 px in y briefly. **Yellow line** (Line2D, width 4, white core) drawn from hero to target. Target flashes white for 80 ms. On execute (kill < 30% HP), draw a second longer flash + tiny "crit" particle. |

VFX nodes are short-lived (`SceneTreeTimer` + `queue_free`), authored in code on the hero — no separate scene files needed for v1.

---

## 2 — Hero bubbles + hero freeing

**Heroes are freed from specific bubbles**, not from any matched pop.

| Property | Value |
|---|---|
| Density | 1 in 8 (v1 greybox, flat across stages) |
| Floor | Every stage's initial cluster contains ≥1 hero bubble |
| Visibility | Always visible from spawn — bubble has a hero face/portrait. No cracked-on-damage variant. |
| Hero identity | Drawn from gacha pool (v1 greybox: random from 3 enabled classes) |
| Bubble colour | Independent of trapped hero's class |
| Match requirement | Hero bubble is freed only when its bubble is popped via a normal 3+ colour-match |

**On pop (one or more hero bubbles in matched group):**
1. The hero bubble breaks.
2. The trapped hero spawns at row 0 in the **column directly below where the hero bubble was**.
3. Tier by match size: **3-5 = Bronze, 6-9 = Silver, 10+ = Gold**. **One hero per popped hero-bubble** (size 6, 7, 10, 15+ still produce exactly one hero, just at the corresponding tier).

**Row-0 full handling (resolution order — first match wins):**
1. **Direct column merge** — if the column below the popped hero bubble holds a hero of the **same class and same tier** (Bronze or Silver), merge in place (see §3.5).
2. **Nearest empty** — search outward (±1, ±2…) for nearest empty row-0 cell.
3. **Adjacent merge** (row 0 full) — if any row-0 cell holds a same-class same-tier hero, merge into that cell (nearest match wins; tie → lower column index).
4. **Tier-upgrade replace** — all cells full, no merge target, incoming tier > lowest existing tier: replace lowest-tier hero (tie: oldest).
5. **Queue** — incoming tier ≤ all existing, no merge target: queue (FIFO, max 3). Queued hero fills next vacated cell.

**No silent overwrite** — Bronze never replaces Gold. Merge always wins over replace when both are available.

---

## 3 — Hero behavior on lane

### 3.1 — Phase 1 (Build): idle, stationary

- Heroes spawn from popped hero-bubbles onto row 0.
- They stand idle — no enemies present yet.
- Visual: gentle idle bobble.
- `Lane.combat_enabled = false` during P1.
- **No dragging in Phase 1.** Position is determined by where each hero bubble was popped.

### 3.2 — Phase 2 (Combat): auto-fire + draggable + merge

- `combat_enabled` flips to `true` at P2 start.
- Heroes auto-fire at enemies in range (cluster-converted + scripted wave).
- **Heroes are fully draggable along row 0.** Press-and-hold a hero → it lifts, lane column highlights → drag horizontally → release commits.
- **Drop resolution (drag release):**
  - Empty cell → move.
  - Occupied, same class + same tier (Bronze or Silver) → **merge** (see §3.5).
  - Occupied, anything else → swap.
- **Modal aim block:** while a hero is being dragged, the cannon is already dim (P2 has no firing), so no input conflict. (The aim-block flag is preserved for cases where the same drag pattern might be re-used in Phase 1 in future.)
- No cooldown, no movement budget, full row-0 range in v1. Tune later if degenerate.
- No vertical movement (heroes locked to row 0).

### 3.3 — Color counter and frenzy

- **Color counter:** heroes of colour X deal **2× damage** to enemies of colour X.
- **Color frenzy:** when the player clears all bubbles of one colour from the cluster during Phase 1, that colour's heroes get **+50% damage for the entire Phase 2 wave** (no timer). Visual: hero glow during buff + screen edge tint pulse on trigger.

### 3.4 — Hero death and carry-over

- HP 0 → hero disappears with a brief particle. Row-0 cell becomes empty.
- Queued hero (if any) takes the slot.
- The enemy that killed it continues down through rows 1-5 toward the cannon.
- **Carry-over between stages:** surviving heroes carry to next stage's Phase 1 lane. **HP + column placement preserved.** No heal, no tier change. Class-damage boons reapplied before restore. Color-frenzy buffs do NOT persist across stages.

### 3.5 — Hero merging

Same-class same-tier heroes combine into one of the next tier. Borrowed from Lucky Defense / merge-game pattern; layered onto Pop Brigade's drag system so a single gesture handles reposition + merge.

| Inputs | Output |
|---|---|
| Bronze + Bronze (same class) | 1 Silver of that class, full Silver HP (150) |
| Silver + Silver (same class) | 1 Gold of that class, full Gold HP (200) |
| Gold + Gold | **No merge.** Treated as swap (P2) or queue (P1). Gold caps in v1. |
| Different class or different tier | **No merge.** Treated as swap (P2) or replace/queue (P1). |

**Resolution detail:**
- Merged hero occupies the **target** cell (drag destination in P2; hero-bubble's column / matched cell in P1). Source cell empties.
- HP **resets to full** for the new tier — partial HP does not carry. Cost is deliberate: merging two damaged Silvers gives you a full-HP Gold but burns the damage you'd already taken on the line.
- Class-damage boons + active colour-frenzy buff re-apply to the merged hero.
- Animation: 0.4 s — both heroes converge, brief flash + tier-coloured glow ring, merged hero scale-up.
- **No cascade in v1:** merges do not chain. A fresh Gold formed from two Silvers cannot immediately participate in another merge in the same drag/spawn event.

**Triggers:**
- **Phase 2 (player):** drag onto matching hero.
- **Phase 1 (auto):** when a freed hero lands on a row-0 cell already holding a matching hero (rule 1 of §2.4 row-0 handling) or — if all cells full — the nearest matching cell (rule 3).

**Implementation notes (engineer):**
- `Lane.resolve_drop(hero, target_col)` returns one of `MOVE | SWAP | MERGE`. Hero state machine handles each.
- `Hero.merge_with(other) -> Hero`: spawn new hero at target cell with `tier = self.tier + 1`, `hp = max_hp_for_tier(class, new_tier)`, free both inputs.
- Telemetry: emit `hero_merge { class, color, source_tier, result_tier, source_col, target_col, trigger, source_hp_before, target_hp_before, ms_since_phase_start }`.

---

## 4 — Enemies — types + per-stage progression

### 4.1 — Two enemy sources (both Phase 2)

**A) Cluster-converted enemies (NEW vs original v1):**
- At Phase 1 → Phase 2 transition, every bubble still in the cluster spawns an enemy of that bubble's colour at the top of the cluster zone.
- These enemies fall from their bubble's column (visually: bubble → enemy in same column).
- Variant: Walker (default). No special variants from cluster conversion.

**B) Scripted wave:**
- Independent of Phase 1 performance. Always plays.
- Fixed composition per stage (see §4.4). Wave enemies spawn at top of device, fall through cluster zone at 0.25 s/cell.

### 4.2 — Three colour archetypes

| Color | HP | Speed (s/cell in lane) | Damage on reach | Vibe |
|---|---|---|---|---|
| RED | 50 | 1.0 | 10 | Standard walker |
| BLUE | 80 | 1.5 | 10 | Slow tank |
| YELLOW | 120 | 1.2 | 15 | Big hitter |

### 4.3 — Mechanical variants (scripted wave only)

| Variant | First appears | Tag visual | Stat delta |
|---|---|---|---|
| **Walker** (default) | Stage 1 | none | baseline |
| **Runner** | Stage 3+ | thin white outline + faster bob anim | speed ×0.6, HP ×0.7 |
| **Brute** | Stage 4+ | scale 1.4 + dark inner ring | HP ×2.0, speed ×1.3, damage ×1.5 |
| **Boss** | Stage 5 | scale 1.6 + boss aura | HP 1000, damage 50, purple |

Variant is a tag, not a separate scene — `Enemy.gd` exports `variant: String` and `_apply_color_stats` multiplies the base.

### 4.4 — Per-stage scaling

| Stage | HP mult | Damage mult | Scripted wave | Variant additions |
|---|---|---|---|---|
| 1 | 1.00 | 1.00 | 5 R | — |
| 2 | 1.10 | 1.00 | 4 R + 2 B | — |
| 3 | 1.20 | 1.05 | 4 R + 3 B + 2 Y | + 1 Runner |
| 4 | 1.35 | 1.10 | 5 R + 3 B + 3 Y | + 1 Runner + 1 Brute |
| 5 (boss) | 1.50 | 1.20 | 6 R + 4 B + 4 Y + Boss | + 2 Runners + 2 Brutes |

**Total Phase 2 threat = scripted wave + cluster-converted enemies.** A player who popped aggressively in Phase 1 has only the scripted wave. A player who left half the cluster has roughly double.

### 4.5 — Enemy "tell" before attacking heroes

Enemies don't fire back in v1. The threat model is "they reach the cannon and damage HP." Reserved for v2.

---

## 5 — Boss stage (Stage 5) — Cluster Shake mechanic

The boss adds pressure during **Phase 1** of stage 5:

- Every **15 s during P1**, the boss rumbles and the cluster drops **2 rows.**
- Forces faster Phase 1 cluster clearance — player can't dwell using all 16 moves slowly.
- In Phase 2, boss spawns 30 s after wave start OR after last walker dies, whichever first.
- Boss HP 1000, damage 50 on reach, purple colour (no hero counter — pure throughput test).

Rejected boss mechanics (kept for reference):
- ~~Hero-bubble drain~~ — anti-fun, punishes Phase 1 success
- ~~Column lock~~ — drags Phase 2, plays as "wait it out"

---

## 6 — Numbers summary (what becomes a `GameConfig` value)

Per-class behavior:
```gdscript
# Fire Knight (RED) — cone
@export var red_cone_rows: int = 4
@export var red_cone_cols: int = 1
@export var red_fire_rate_sec: float = 0.75
@export var red_cleave_chance: float = 0.25
@export var red_cleave_targets: int = 2

# Ice Mage (BLUE) — column splash
@export var blue_col_radius: int = 1
@export var blue_reach_rows: int = 10
@export var blue_fire_rate_sec: float = 1.6
@export var blue_aoe_radius_cells: float = 1.5
@export var blue_dmg_mult: float = 0.7

# Archer (YELLOW) — snipe
@export var yellow_reach_rows: int = 15
@export var yellow_fire_rate_sec: float = 1.2
@export var yellow_dmg_mult: float = 1.4
@export var yellow_execute_threshold: float = 0.30
@export var yellow_execute_bonus: float = 0.50
```

Hero bubbles + placement:
```gdscript
@export var hero_bubble_density: float = 0.125         # 1 in 8
@export var hero_bubble_min_in_starting_cluster: int = 1
@export var hero_bubble_always_visible: bool = true

@export var hero_drag_enabled_phase2: bool = true
@export var hero_drag_cooldown_sec: float = 0.0
@export var hero_drag_range_cells: int = 99             # full row 0
@export var hero_drag_swap_on_occupied: bool = true

# Hero merge (B+B → S, S+S → G; Gold caps)
@export var hero_merge_enabled: bool = true
@export var hero_merge_max_tier: int = 3                 # 1=Bronze, 2=Silver, 3=Gold
@export var hero_merge_animation_sec: float = 0.4
@export var hero_merge_hp_rule: String = "full_new_tier" # OQ12: "full_new_tier" | "sum" | "max_source"
@export var hero_merge_p1_auto: bool = true              # P1 row-0 collision auto-merges
@export var hero_merge_cascade: bool = false             # v1: no chain merges

@export var carry_over_heroes_enabled: bool = true      # OQ11 toggle
@export var carry_over_preserve_hp: bool = true
@export var carry_over_preserve_column: bool = true
```

Enemies + variants:
```gdscript
@export var runner_hp_mult: float = 0.7
@export var runner_speed_mult: float = 0.6
@export var brute_hp_mult: float = 2.0
@export var brute_speed_mult: float = 1.3
@export var brute_dmg_mult: float = 1.5

@export var stage_hp_mults:  Array[float] = [1.0, 1.1, 1.2, 1.35, 1.5]
@export var stage_dmg_mults: Array[float] = [1.0, 1.0, 1.05, 1.1, 1.2]

# Cluster-converted enemies (P1 → P2 transition)
@export var cluster_converted_variant: String = "walker"
@export var cluster_converted_spawn_delay_per_bubble_ms: int = 80   # stagger spawn so player reads each one
```

Move budget:
```gdscript
@export var move_budget_per_stage: Array[int] = [10, 11, 13, 14, 16]
```

Cluster descent (stages 4+) + boss shake:
```gdscript
@export var stage_descent_intervals_sec: Array[float] = [0.0, 0.0, 0.0, 12.0, 12.0]
@export var boss_cluster_shake_interval_sec: float = 15.0
@export var boss_cluster_shake_rows: int = 2
```

---

## 7 — Implementation plan (in order)

1. **GameConfig**: add the new exports above.
2. **Cluster**: add `hero_bubble: bool` flag per cell + face/portrait overlay sprite. Random density per spawn (1/8 weighted, floor 1 per stage).
3. **MatchScene**: add `move_budget` state. Decrement on each `bubble_fired`. End Phase 1 when budget = 0.
4. **MatchScene** (transition): on P1 end, iterate remaining cluster cells; spawn an Enemy at each cell's column with variant=walker, stagger by `cluster_converted_spawn_delay_per_bubble_ms`. Then start scripted wave.
5. **Lane**: pickers for Fire Knight (cone), Ice Mage (column-splash), Archer (snipe).
6. **Hero**: `_try_fire` splits by colour into class-specific fire functions + VFX.
7. **Hero drag**: `_input` handles `drag_start` / `drag_move` / `drag_release` on touched hero. Lane handles hit-test + swap-on-occupied. Phase-gated (Phase 2 only).
8. **Hero carry-over**: snapshot `(class, tier, hp, col)` at stage_clear; restore at next stage_start. Toggle via `carry_over_heroes_enabled`.
9. **Cluster descent + boss shake**: tick timers from `stage_descent_intervals_sec[current_stage_idx]` and `boss_cluster_shake_interval_sec` (stage 5 only).
10. **Telemetry**: events listed in `design-spec.md` §6.2.

Estimated touch surface: 6 files (`GameConfig.gd`, `Cluster.gd`, `Lane.gd`, `Hero.gd`, `Enemy.gd`, `MatchScene.gd`). Hero drag + carry-over are already implemented in the godot-prototype.

---

## 8 — Open questions

1. **Cluster-converted enemy visual.** Distinct from scripted-wave walkers (e.g., "angry bubble" silhouette) or identical? Distinct strengthens Q1 causal-arc readability. Recommend distinct.
2. **Cluster-converted enemy stat scaling.** Use stage HP/damage multipliers, or always baseline (so leftover ratio is the only difficulty signal)? Recommend baseline — keep the causal link clean.
3. **Conversion stagger.** 80 ms per bubble means 30 leftover bubbles = 2.4 s of falling enemies before the wave script starts. Too slow? Try 50 ms.
4. **Friendly fire on Ice Mage AoE.** Spec assumption: no, filters to enemies only.
5. **Archer execute on bosses.** Spec assumption: yes; 30% threshold makes it a late-fight reward, not cheese.
6. **Cleave proc on Fire Knight.** 25% proc vs always-on 50% cleave. Spec assumption: proc — feels punchier.
7. **Runner / Brute scenes.** Tag-based for v1 (no new scenes). If you want distinct silhouettes, swap ColorRect for Sprite2D + 2 textures.

---

## 9 — Out of scope for v1
- Enemy projectile attacks (no enemy fires back).
- Hero animations beyond translate/scale tweens.
- Status effect icons on enemies (slow indicator etc.).
- Per-class hero portraits for Bronze/Silver/Gold (still scale-based for tier).
- Druid (Green) and Wizard (Purple) classes — v1.5.
- Multi-row hero placement — row 0 only in v1.
