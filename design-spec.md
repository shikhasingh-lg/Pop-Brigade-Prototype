---
name: Pop Brigade — Design Spec
status: draft
created: 2026-05-11
updated: 2026-05-13
concept_doc: ~/game-research/pop-brigade/concept.md
combat_doc: ~/game-research/pop-brigade/combat-design.md
ui_flow_doc: ~/game-research/pop-brigade/ui-flow.md
locked_architecture: Phased Build → Wave, move-budget triggered, hero bubbles only spawn heroes, same-class-same-tier heroes merge up
---

# Pop Brigade — Design Spec

> **Scope of this doc:** Prototype-ready spec for the v1 greybox. Covers core mechanics, economy, content, and test hypotheses tight enough that engineering + design can build without re-asking the designer. UI lives in `ui-flow.md`. Per-class combat (targeting + VFX) lives in `combat-design.md`.

> **Locked architecture:** **Phased Build → Wave.** Each stage runs in two phases.
> **Phase 1 (Build):** Cluster of bubbles hangs above. Cannon has a fixed **move budget** (10 shots at L1, scaling up by stage). Player aims and fires. Match 3+ pops bubbles. Specific bubbles have heroes trapped inside (visible from spawn, ~1-in-8 density) — popping those frees the trapped hero onto row 0 below where the bubble was. Heroes stand idle; no enemies present.
> **Phase 1 ends when the move budget hits zero.** Any bubbles still in the cluster **convert to enemies** that fall from the top of the cluster zone. A **scripted enemy wave** also begins.
> **Phase 2 (Combat):** Heroes auto-attack the converted-cluster enemies AND the scripted wave. **Heroes are draggable horizontally along row 0** — player repositions them in real time to meet the wave. No bubble firing in Phase 2. Stage clear when all enemies defeated; stage fail at HP 0.
> **Carry-over:** Surviving heroes go to the next level with **HP and column placement preserved**.
> **Hero merging:** Two heroes of the **same class and same tier** combine into one of the next tier (Bronze + Bronze → Silver, Silver + Silver → Gold). Phase 2: drag a hero onto a matching hero to merge. Phase 1: if a freshly-freed hero lands on a row-0 cell already occupied by a same-class-same-tier hero, they merge in place. Gold is the cap — Gold + Gold does not merge.

## Change log

| Date | Change | Why |
|---|---|---|
| 2026-05-12 | v1: V8 phased Cluster→Wave variant locked; misses vanished below spawn line | Earlier critique that V2 cluster-as-spawner risked oppressive overlap |
| 2026-05-13 | **Hero bubbles introduced** — only specific bubbles (visible face/portrait on bubble, 1-in-8 density) spawn heroes. Other bubbles clear pressure only. Class decoupled from bubble colour. | Original color = class = gacha = chaining was a four-way tuning bind |
| 2026-05-13 | **Heroes are draggable along row 0 during Phase 2** | Adds tactical agency to the defend phase (Lucky Defense / merge-game pattern) |
| 2026-05-13 | ✅ Hero drag **implemented** (godot-prototype): row-0 only, no cooldown, swap-on-occupied, modal aim block. Telemetry: `hero_drag {color, tier, from_col, to_col}`. Files: `Cannon.gd` (aim-block flag), `Lane.gd` (hit-test + move/swap), `MatchScene._input` (drag state machine). See combat-design.md §3.2. | Implementation pass — closes the spec→code gap |
| 2026-05-13 | ✅ Hero carry-over **implemented** (godot-prototype): HP + cell preserved, no heal, no reposition; `RunState.run_heroes` survives `MatchScene` re-instantiation between stages. Toggleable via `GameConfig.carry_over_heroes_enabled` (OQ11). Files: `Lane.gd` (snapshot/restore), `MatchScene.start_stage` + `_clear_stage`. | Implementation pass — closes the spec→code gap |
| 2026-05-13 | **Phase 1 end condition switched from time cap to move budget** (10 moves at L1, scaling) | Fixed budget creates a clearer player goal ("make these 10 shots count") than a real-time timer |
| 2026-05-13 | **Phase 1 → Phase 2 transition: remaining cluster bubbles convert to enemies** (entering at top of cluster zone, falling toward heroes) | Replaces v1's "bubbles vanish below spawn line" — now the player is *punished* for not popping enough, but the punishment fuels the wave rather than disappearing |
| 2026-05-13 | **Carry-over rule confirmed: HP + column placement preserved** | Rewards Phase 2 hero preservation; no Bronze downgrade |
| 2026-05-13 | **Hero merging added** — same class + same tier combine up (B+B → S, S+S → G; Gold caps). P2 = drag-to-merge, P1 = auto-merge on row-0 collision with matching hero. Replaces tier-upgrade-replace branch of the row-0-full rule for matching cases. | Adds Lucky Defense / merge-game depth without re-introducing colour-as-class. Lets Phase 2 drag carry two intents (reposition OR merge), and gives players a reason to want multiple low-tier heroes of the same class instead of always praying for match-5. |
| 2026-05-13 | **Spawn-tier thresholds widened**: match 3-5 = Bronze, match 6-9 = Silver, match 10+ = Gold (was: 3 / 4 / 5+). | Old thresholds made spawn-Gold trivial — every match-5+ produced one. New thresholds make spawn-Gold rare (needs a Color Bomb on a heavy single-colour cluster, or a 10-bubble chain) and reposition the merge ladder as the primary path to Gold. Silver becomes a real chain reward (6+ connected), not a routine match-4. Bronze is the default for any normal pop including the most common Color-Bomb result on early stages. Tightens the dopamine curve and makes the merge mechanic load-bearing rather than redundant. |

---

## Section 1 — Pitch

### One-line hook
A vertical-lane tower defense in two phases per stage. **Phase 1:** fire a limited number of bubbles at the cluster overhead; specific bubbles trap heroes — pop them to free the heroes onto your line. **Phase 2:** the bubbles you didn't pop become enemies, a scripted wave joins them, and your pre-built army fights — but you can drag your heroes to meet the threat. Build, then defend.

### Fantasy
Your brigade is sealed in bubbles in the sky. Every shot of your cannon is a decision: free a hero you need, or clear a wall about to become enemies. When your shots run out, the bubbles you left behind fall as monsters. The army you built fights for you, and you reposition them on the line as the wave comes.

### Target player
Slime Legion / Lucky Defense / Capybara Go / Bubble Witch player. Hybrid casual, female-skew, 5-15 min sessions, comfortable with ~4 cognitive layers, plays multiple Habby-tier TD hybrids.

### Why this concept (v1 thesis in one paragraph)
The bubble-shooter lane is the most fragmented top-grossing puzzle lane on mobile (5 publishers in top 5, no UA giant, $500-700K/mo). Slime Legion proved color-as-spawner + lane TD + gacha works. Existing bubble-TD hybrids fail because cluster and lane feel disconnected — they play simultaneously and the player can't focus on either. **Pop Brigade phases them, then ties them with a single dramatic transition:** the bubbles you didn't pop are the wave you'll fight. The phased model is comp-validated (Slime Legion, GearPaw both ship build-then-defend), so the watching phase is solved territory — and v2 makes it actively interesting by letting the player drag heroes during the wave. If v1 proves the build → defend chain reads as **one game** (with the bubbles you didn't pop *becoming* the wave you fight), the lane is ours.

### What we are testing in v1

| Question | Pass signal | Kill signal | Notes |
|---|---|---|---|
| **Q1 (existential):** Does the build → defend chain read as **one game** — specifically, do players connect "bubbles I left unpopped" with "enemies that arrived"? | Testers describe loop as "I had 10 shots to free heroes and clear bubbles; the ones I left came back as enemies" — single causal arc | Testers describe two disjoint experiences; don't connect leftover bubbles to wave composition | **This is the kill question.** Phased TD is comp-validated. What's untested is the causal link between Phase 1 leftovers and Phase 2 difficulty. |
| Q2 (tunable): Is the **hero-bubble priority decision** interesting? | Testers vocalise the trade-off ("do I free this hero or clear that wall?") at least once per stage | Pop choices look random; testers can't articulate why they popped what they popped | The "interesting decision" is the core claim. |
| Q3 (tunable): Does **hero dragging in Phase 2** feel like real agency? | Testers reposition heroes meaningfully (≥2 drags per Phase 2); 60%+ of drags causally tied to a wave threat | Constant fidgeting OR no dragging at all | If no dragging, simplify the lane (fewer columns); if constant, add cooldown. |
| Q4 (tunable): Does each stage produce **≥1 highlight moment per phase** (≥2 per stage)? | P1: chain pop, color frenzy trigger, near-miss hero rescue. P2: narrow survival, big cleave, frenzy carryover | Flat affect in either phase | Tune through boon/wave/frenzy density. |

### Production frame
- Team: 10 (studio constraint)
- v1 build target: 5 stages, 3 hero classes (Red/Blue/Yellow), 3 enemy variants, no meta, no art — greybox only
- v1 timeline: 4 weeks from spec lock to internal playtest
- Engine: Unity (per studio default)
- v1 platform: Android internal build only

### Comp anchor (one row)
| Game | What we steal | What we change |
|---|---|---|
| Slime Legion | Build → fight phasing, color = spawn pattern, gacha meta, lane TD | Input: bubble aim-fire + move budget; **hero identity in bubbles**, not in colour |
| Bubble Witch 3 | Aim-fire feel, cluster physics, ricochet | Move budget replaces moves-or-puzzle-complete; cluster leftovers become wave |
| Lucky Defense | Active hero placement, drag-to-merge tier system, gacha meta | Bubble-shooter is the *input layer* — merging is a Phase 2 layer on top of an aim-fire Phase 1 (rather than the only input) |

---

## Section 2 — Three-loop diagram

### Loop 1 — Stage loop (Phase 1 build → Phase 2 defend)

```
  ┌──── PHASE 1: BUILD (move budget) ────────────────────────────────┐
  │                                                                  │
  │   Cluster spawns. Cannon shows "10 / 10" move counter at L1.     │
  │                                                                  │
  │   [AIM bubble] ──► [FIRE] ──► attaches to cluster ──► match 3+?  │
  │     │                                                            │
  │     │ move budget -1                                              │
  │     ▼                                                            │
  │   ┌─────────────────┐                                            │
  │   │ Match included  │ ──yes──► free trapped hero(es) into row 0  │
  │   │ a HERO BUBBLE?  │          (column directly below their      │
  │   └────────┬────────┘          bubble's column)                  │
  │            │ no                                                  │
  │            ▼                                                     │
  │   Clear bubbles + relieve cluster pressure                       │
  │            │                                                     │
  │            └──► moves left? ──yes──► back to AIM                 │
  │                                                                  │
  │   Phase 1 ends when MOVE BUDGET = 0                              │
  └──────────────────────────────┬───────────────────────────────────┘
                                 ▼
  ┌──── TRANSITION (1s "GET READY!" wipe) ────────────────────────────┐
  │                                                                  │
  │   For every bubble remaining in the cluster:                     │
  │     spawn an enemy of that bubble's colour at top of cluster     │
  │     zone, falling toward row 0                                   │
  │                                                                  │
  │   Also: scripted enemy wave begins                                │
  └──────────────────────────────┬───────────────────────────────────┘
                                 ▼
  ┌──── PHASE 2: COMBAT (drag-and-defend) ────────────────────────────┐
  │                                                                  │
  │   Heroes auto-fire at enemies (cluster-converted + scripted)     │
  │            │                                                     │
  │   Player input: DRAG any hero horizontally along row 0           │
  │            │                                                     │
  │            ▼                                                     │
  │   All enemies defeated? ──YES──► STAGE CLEAR ──► boon pick ──►   │
  │            │                                                     │
  │            ▼                                                     │
  │   Player HP 0?  ──YES──► STAGE FAIL ──► run ends                 │
  │                                                                  │
  │   No bubble firing in Phase 2 (cannon dimmed, tap-inert).        │
  └──────────────────────────────────────────────────────────────────┘
```

**Phase 1 target cadence:** 1 shot every ~2-3 sec. With 10 moves at L1, Phase 1 length ≈ 25-30 sec.
**Phase 2 target cadence:** Wave length 45-90 sec depending on stage and how much leftover cluster the player has.

**Highlight moment targets:**
- **Phase 1:** match 6+ silver hero, match 10+ gold (rare, Color-Bomb territory), color frenzy on full color clear, chain ≥3, freeing a specifically-wanted hero (gacha drop)
- **Phase 2:** narrow survival (HP < 20), enemy chain kill from Druid-buffed hero, color frenzy carryover, well-timed hero drag that intercepts a Brute

### Loop 2 — Session loop (the "run")

```
[Run start] ──► pick starting cannon (color bias)
       │
       ▼
[Stage 1: ~75 sec total] ──► clear wave → boon pick (1 of 3)
       │
       ▼
[Stage 2: ~90 sec total] ──► clear → boon
       │
       ▼
   …5 stages total in v1 greybox…
       │
       ▼
[Boss stage 5: ~150 sec total] ──► boss has cluster-shake mechanic during P1 → run rewards
       │
       ▼
[Run end] ──► back to meta hub
```

**Total v1 run length:** ~10-12 min. Tight enough for 2-3 runs per session.

**Boon pool for v1 greybox (10 boons, pick 1 of 3 after each stage clear):**
- Red Bias / Blue Bias / Yellow Bias (+30% chance next bubble is your chosen color)
- Damage +25% (Red / Blue / Yellow)
- Hero Bubble Density +50% (next stage only)
- Bronze→Silver (next stage, all freed heroes start one tier up)
- Extra Moves (+2 moves to cannon budget for the next stage)
- Synergy: **Color Affinity** — if you have a Color Bias active, that color's bubbles also have +20% chance to be hero bubbles. (One real synergy in v1 to test build-craft signal.)

### Loop 3 — Meta loop (spec only — NOT built in v1)

```
[Run end] → currency + hero shards → unlock/upgrade heroes
                                          │
                                          ▼
                                  Pulled heroes appear in YOUR hero bubbles
                                          │
                                          ▼
                              Battle pass / event progress
                                          │
                                          ▼
                                  Back to next run
```

**Meta surfaces (specced for v2, NOT in v1 prototype):**
- Hero gacha (~25 heroes at launch, ~3 in v1 spec): pull with premium currency
- **Gacha-to-gameplay link:** pulled heroes are weighted heavier in the hero bubbles you encounter during runs
- Cannon upgrades: damage, fire rate, **move budget**, special bubble capacity
- Battle pass: seasonal, $5-10
- Daily/weekly events: color-themed challenges
- Clan raids: post-launch only

**First $4.99 moment:** "Extra Moves" offer when Phase 1 move budget hits 0 with cluster still full — pay a gem cost to extend by 3 moves. Players will be deep into a stage when this fires.

### Loop interaction map

| Loop | Drives | Time horizon | What v1 must prove |
|---|---|---|---|
| Stage (Phase 1 + Phase 2) | Shot dopamine + payoff-watch + drag agency | 60-150 sec | Build → defend reads as one game; leftover bubbles → wave is a causal link the player feels |
| Session (5 stages) | Run completion, "one more run" pull | 10-12 min | Run arc has rising stakes + meaningful boon choices |
| Meta | D7+ retention, monetization | Days-weeks | _Out of scope for v1_ — assume Habby playbook ports |

---

## Section 3 — Core mechanics spec

> **Rule for this section:** Numbers, not adjectives. Every tuning value listed here is a **v1 default** — designer-adjustable in the build, but locked for the first playtest so signal is comparable across testers. Final tuning table is at §3.9.

### 3.1 Spatial layout

Portrait mobile, 9:19.5 reference (iPhone 15 / Pixel 8). Screen divided into three zones top → bottom:

| Zone | Vertical % | Purpose |
|---|---|---|
| **Cluster zone** | Top 55% | Bubble cluster grid (Phase 1) / enemies falling from cluster remnants (Phase 2 transition). Spawn line at bottom edge. |
| **Lane** | Middle 30% | Vertical channel: heroes hold row 0 in both phases (stationary in P1, draggable in P2). Enemies march here in P2. |
| **Cannon + HUD** | Bottom 15% | Cannon, current/queued bubble, HP, **move budget counter**, pause, phase indicator |

- **Cluster grid:** width tiers per stage — 5 cols (stages 1-3), 6 cols (4-5). Height starts at 4-5 rows, grows to 7 rows at boss. Hex grid.
- **Spawn line:** drawn at the cluster zone's bottom edge — visible glowing horizontal line. **Heroes stand on this line** (row 0). It's also the line the cluster cannot descend past in later stages.
- **Lane:** 5-6 columns × 6 rows. **Row 0 = hero line (stationary in P1, draggable in P2); rows 1-5 = enemy march path.**
- **Phase indicator:** Banner above the cannon — "BUILD" (Phase 1, blue) / "DEFEND" (Phase 2, red). Phase transition: 1s "GET READY!" wipe.

### 3.2 Cluster mechanics (Phase 1 only)

**Attachment:**
- Fired bubble travels along aim trajectory at 1500 px/sec.
- On collision with cluster bubble or top wall, snaps to nearest empty hex cell adjacent to point of contact.
- **Every shot fired costs 1 move from the move budget**, whether or not it attaches or pops.

**Match detection:**
- After attachment, run flood-fill from the new bubble.
- If 3+ same-color bubbles are connected (hex-adjacent), trigger pop.
- Pop animation: 0.3 s.
- **If the popped group includes one or more hero bubbles, free the trapped heroes (see §3.4).**

**Falling bubbles (cascade rule):**
- After a pop, any bubble no longer connected to the top wall falls and is cleared as a bonus.
- Cascade bubbles do **not** free heroes — only direct match-pops free hero bubbles.

**Move budget (Phase 1 timer):**
- Each stage starts with a fixed move budget displayed on the cannon HUD.
- Budget per stage (v1 greybox):
  | Stage | Move budget | Notes |
  |---|---|---|
  | 1 | 10 | Tutorial pace |
  | 2 | 11 | + Blue introduced |
  | 3 | 13 | + Yellow + first Runner enemy |
  | 4 | 14 | + Brute enemy |
  | 5 (boss) | 16 | + cluster shake during P1 |
- Each shot decrements the budget by 1.
- When budget reaches 0, **Phase 1 ends immediately** → 1s "GET READY!" transition → Phase 2 begins.

**Cluster descent (stages 4+ only, secondary pressure):**
- On stages 4+, the cluster also slowly descends during Phase 1: 1 row every 12 s.
- If the cluster reaches row 0 (spawn line) before the move budget is exhausted, **Phase 1 ends early.** Remaining moves are forfeit.
- Descent gives the player a reason to be efficient with moves on later stages — don't dwell.
- Stages 1-3: descent off. The puzzle is the only pressure.

**Boss stage cluster shake (Stage 5 only):**
- The boss adds a passive aura during Phase 1: every 15 s the cluster shakes and drops 2 rows.
- This forces faster cluster clearance — the player cannot just "use all 16 moves carefully."

### 3.3 Aim & fire (Phase 1 only)

The cannon is **active only during Phase 1.** In Phase 2 the cannon is visually dimmed and taps are ignored — players watch the wave and drag heroes.

- **Input:** Touch-and-hold anywhere in the lower 70% of the screen → aim line appears from cannon. Drag to adjust angle. Release to fire.
- **Aim assist (LOCKED ON in v1):** Full trajectory dotted line, including 1 wall ricochet.
- **Ricochet:** Left and right walls bounce bubbles. Top wall = attach.
- **Fire rate cap:** 1 shot per 0.5 s.
- **Bubble queue:** 1 in cannon + 1 visible in on-deck slot.
- **Bubble swap:** Tap the on-deck slot to swap. Free, unlimited.
- **Move counter:** HUD shows remaining moves prominently ("7 / 10"). Counter decrements on each fire.
- **Bubble color rolling:** Each new bubble drawn from active color palette (= colors still present in cluster).

### 3.4 Hero bubbles + hero freeing

**The core architectural change vs v1's "every pop spawns a hero":** Heroes are NOT created by colour-matched pops. They are **freed from specific bubbles** that visibly contain them.

| Property | Value |
|---|---|
| Density | Tiered: 1-in-8 bubbles in v1 greybox (5 stages). v2 will tier by board size (1-in-12, 1-in-17 for larger boards). |
| Floor | Every stage's initial cluster contains ≥1 hero bubble |
| Visibility | Always visible from spawn — a bubble with a hero face/portrait. No cracked-on-damage variant. |
| Hero identity | Drawn from the player's gacha pool, weighted toward owned heroes. v1 greybox: random from 3 enabled classes. |
| Bubble colour | Independent of trapped hero's class. A Yellow Archer can be in a green bubble or a red bubble. |
| Match requirement | Hero bubble is freed only when its bubble is popped via a normal 3+ colour-match. |

**On pop (one or more hero bubbles in matched group):**
1. The hero bubble breaks.
2. The trapped hero spawns at **row 0 in the column directly below where the hero bubble was**. (If that column is full, see §3.4.1 below.)
3. Tier by match size: **3-5 = Bronze, 6-9 = Silver, 10+ = Gold**. **One hero per popped hero-bubble** (size 6, 7, 10, 15+ all still produce exactly one hero, just at the corresponding tier).

**Hero placement is FIXED in Phase 1** — heroes do not move in P1. Drag is a Phase 2 input only.

### 3.4.1 Row-0 full handling (replacement / queue / merge rule)

Resolution order — check in sequence; first match wins:

1. **Direct column merge** — if the column below the popped hero bubble is occupied by a hero of the **same class and same tier** as the incoming hero (Bronze or Silver), **merge in place** (see §3.5.1). No outward search.
2. **Nearest empty** — search outward (±1 col, ±2 col, …) for the nearest empty row-0 cell. Place there.
3. **Adjacent merge** (when row 0 is full) — if any row-0 cell holds a hero of the same class + tier as the incoming, **merge into that cell** (nearest match wins; tie → lower column index).
4. **Tier-upgrade replace** — if all row-0 cells are full and no merge target exists, and the incoming hero's tier > the lowest existing hero's tier, **replace the lowest-tier hero** (tie: oldest).
5. **Queue** — if incoming hero's tier ≤ all existing heroes and no merge target exists, queue (FIFO, max 3). Queued hero fills the next vacated cell.

**No silent overwrite** — Bronze never replaces Gold. Merge is preferred to replace whenever it's available; this rewards stacking multiple low-tier heroes of the same class.

### 3.5 Hero behavior on lane

**Phase 1 (Build):**
- Heroes spawn from popped hero-bubbles onto row 0 (the spawn line).
- They stand idle — no enemies present yet.
- Visual: gentle idle bobble.
- Internally gated: `Lane.combat_enabled = false` during P1.
- **No dragging in Phase 1.** Position is determined by where each hero bubble was popped (see §3.4).

**Phase 2 (Combat):**
- `combat_enabled` flips to `true` at P2 start.
- Heroes auto-fire at enemies in range (both cluster-converted enemies and scripted-wave enemies).
- **Heroes are fully draggable.** Touch-and-hold a hero → it lifts, lane column highlights → drag horizontally along row 0 → release commits.
- **Drag resolution on release:**
  - Empty target column → hero moves there.
  - Occupied target, **same class + same tier (Bronze or Silver)** → **merge** (§3.5.1).
  - Occupied target, anything else (different class, or same class but Gold, or tier mismatch) → **swap** (existing behavior).
- No cooldown, no movement budget, full row-0 range. Tune later if degenerate.
- No vertical movement.
- Per-class targeting / fire rates / damage live in `combat-design.md` §5.

### 3.5.1 Hero merging

Same-class-same-tier heroes combine into one of the next tier. Adds Lucky Defense's merge depth on top of bubble-shooter input.

**Rules:**
| Trigger | Result |
|---|---|
| Bronze + Bronze (same class) | 1 Silver (same class), full Silver HP |
| Silver + Silver (same class) | 1 Gold (same class), full Gold HP |
| Gold + Gold | **No merge.** Resolves as swap (P2) or queue (P1). Gold is the cap in v1. |
| Different class | **No merge.** Resolves as swap (P2) or replace/queue (P1). |
| Different tier, same class | **No merge.** Resolves as swap (P2) or replace/queue (P1). |

**Resolution detail:**
- Merged hero takes the **target cell** (destination of the drag, or the hero-bubble's column for P1 freed heroes). Source cell becomes empty.
- HP resets to **full HP of the new tier** (Silver = 150, Gold = 200). Partial HP does not carry. Trade-off is deliberate: merging a damaged Silver into a fresh Silver costs you the damage *and* gives you a full-HP Gold — but you've lost a body on the line.
- Color frenzy buff (if active) re-applies to the merged hero based on its colour.
- Class-damage boons re-apply to the merged hero.
- Merge animation: 0.4 s — both heroes pull together, brief flash + tier-coloured glow ring, merged hero scale-up. Cannon stays dim through merge (P2 only).

**Triggers (recap):**
- **Phase 2:** player-driven via drag onto matching hero.
- **Phase 1:** auto-merge when a freed hero lands on a row-0 cell already holding a matching hero (§3.4.1 rule 1) or the nearest match when full (§3.4.1 rule 3). Player has no manual input in P1.

**Cap behavior:** Once a column holds a Gold, further matching Bronzes/Silvers cannot promote it — they take the nearest empty cell (P1) or swap (P2). Players can still hold up to ~5 Golds on the line.

**Design intent:**
- Phase 2 drag now carries **two intents** — reposition for threat coverage OR merge for tier-up. This is the new 5th cognitive layer.
- Players have a reason to want multiple low-tier heroes of the same class — every match-3-5 pop becomes a Bronze that can ladder toward Gold via merging. With spawn-Gold now requiring match-10+ (rare), the merge ladder is the *primary* route to Gold.
- Creates a tension between merging (raw power) and spreading (column coverage).

**Color counter (legibility crutch in v1):** Heroes of color X deal 2× damage to enemies of color X.

**Color frenzy (Phase 1 trigger, carries into Phase 2):**
- When the player clears all bubbles of one colour from the cluster during Phase 1, mark that colour as "frenzied."
- Frenzied colours deal **+50% damage for the entire Phase 2 wave** (does not expire mid-combat).
- Visual cue: hero glow during buff + screen edge tint pulse on trigger.
- Strategic implication: clearing a color completely is a deliberate Phase 1 goal.

**Hero death:**
- HP 0 → hero disappears with a brief particle. Row-0 cell becomes empty.
- Queued hero (if any) takes the slot.
- The enemy that killed it continues down through rows 1-5 toward the cannon.

### 3.6 Enemy behavior (Phase 2 only)

**Two enemy sources, both active in Phase 2:**

**A) Cluster-converted enemies (NEW vs v1):**
- At the Phase 1 → Phase 2 transition, every bubble still in the cluster spawns an enemy of that bubble's colour at the top of the cluster zone.
- These enemies fall from their bubble's position (visually: bubble → enemy in same column).
- The more bubbles you left unpopped, the heavier this wave.
- Variant: Walker (default). No special variants from cluster conversion.

**B) Scripted wave:**
- Independent of the player's Phase 1 performance — the scripted wave always plays.
- Each stage has a fixed enemy composition (see §4.3) and a fixed spawn schedule.
- Wave enemies spawn at the top of the device, fall through the cluster zone at 0.25 s/cell (~3.75 s anticipation window).

**Total Phase 2 threat = scripted wave + cluster-converted enemies.** If the player popped the cluster aggressively, Phase 2 has only the scripted wave. If they left half the cluster, Phase 2 has roughly double the enemies.

**Enemy stats (v1):**
| Color | HP | Speed (s/cell) | Damage on reach cannon |
|---|---|---|---|
| Red | 50 | 1.0 | 10 |
| Blue | 80 | 1.5 | 10 |
| Yellow | 120 | 1.2 | 15 |

**Mechanical variants (scripted wave only):**
| Variant | First appears | Stat delta |
|---|---|---|
| Walker (default) | Stage 1 | Baseline |
| Runner | Stage 3+ | Speed ×0.6, HP ×0.7 |
| Brute | Stage 4+ | HP ×2.0, speed ×1.3, damage ×1.5 |
| Boss | Stage 5 | HP 1000, damage 50, purple color |

**March:** All enemies start above row 0, drop in fast through the cluster zone (0.25 s/cell), then switch to color-stat cell speed once they cross row 0. Heroes engage immediately on row 0.

### 3.7 Special bubbles (v1: 1 type)

**Color Bomb (only special in v1):**
- Spawn rate: appears in cannon queue every ~15 shots (random within 12-18 range).
- Visual: rainbow-swirl bubble.
- Effect on attach: pops all bubbles of the same color as the cluster bubble it touches. Counts as a single pop event → match size = number cleared → hero tier scales.
- Costs 1 move from budget like any other shot.
- **Interaction with hero bubbles:** a Color Bomb pop *can* free hero bubbles of the matched colour (high-reward play).
- **Tier interaction (with the 3-5 / 6-9 / 10+ threshold):** Color Bomb is the **cleanest spawn-Gold path** in v1, but only on later stages. On stage 1 (~5 of each colour), a Color Bomb hitting a hero bubble produces a **Bronze** — same tier as a normal match-3. On stages 2-3 (~6-8 of each colour), it produces a **Silver**. On stages 4-5 (~10+ of each colour), it produces a **Gold**. Players who learn to **save Color Bombs for hero-bubble-heavy colours on stages 4-5** get a guaranteed Gold — a deliberate skill expression and a reason to delay firing the bomb on cooldown. Almost no other shot in v1 can reliably produce a match of 10 connected same-colour bubbles, so this is the only consistent spawn-Gold route outside the merge ladder.

v2 specials to add later: line bomb, bomb (radius), color swap — **not in v1**.

### 3.8 Win / lose conditions

**Per stage:**
| Condition | Outcome |
|---|---|
| All wave enemies defeated AND no enemies on lane for 2 s | **Stage clear** → boon pick → next stage |
| Player HP reaches 0 during Phase 2 | **Stage fail** → run ends |
| Cluster reaches row 0 during Phase 1 (stages 4+) | **Not a stage fail.** Phase 1 ends early, remaining moves forfeit, Phase 2 begins with remaining cluster as enemies. |

**Phase 1 end (transition to Phase 2):**
- Phase 1 ends when move budget = 0, OR cluster reaches row 0 (stages 4+), OR cluster is completely cleared.
- Whichever fires first triggers transition.
- 1 s "GET READY!" wipe → cluster bubbles convert to enemies → Phase 2 begins.

**Stage clear rewards:**
- Run currency: +50 coins (in-run only, logged for telemetry)
- Boon pick: 1 of 3 (see §4.2)
- Cluster reset: new cluster generated for next stage at stage-defined starting size
- **Surviving heroes carry over to next stage's Phase 1.** HP + column placement preserved. No heal, no tier change. Class-damage boons picked at stage clear apply to restored heroes. Color-frenzy buffs do NOT persist across stages.

**Boss stage (Stage 5):**
- Cluster starts at 5×7 (35 bubbles). Cannon move budget = 16.
- **Cluster shake** every 15 s during Phase 1: cluster drops 2 rows. Player must clear faster than the shake or lose moves to descent.
- Phase 2: scripted wave (6 R + 4 B + 4 Y + 2 Runners + 2 Brutes) + cluster-converted enemies (whatever's left).
- Boss spawns 30 s into Phase 2 OR after last walker dies, whichever first. Boss HP 1000, damage 50, purple (no hero color counter — pure throughput test).

### 3.9 v1 tuning value summary (single-page reference)

| Parameter | Value | Notes |
|---|---|---|
| **Cluster (Phase 1)** | | |
| Grid width | 5 cols (stages 1-3) / 6 cols (4-5) | Hex |
| Grid max height | 12 rows | |
| Stage 1-2 starting rows | 4 | |
| Stage 3-4 starting rows | 5 | |
| Stage 5 starting rows | 7 | Boss |
| Cluster descent | Off stages 1-3 / 1 row per 12 s stages 4+ | Secondary pressure |
| Boss cluster shake | Drops 2 rows every 15 s during P1 | Stage 5 only |
| **Move budget (Phase 1 end trigger)** | | |
| Stage 1 / 2 / 3 / 4 / 5 | 10 / 11 / 13 / 14 / 16 | Decrements on each shot |
| **Aim & fire (Phase 1 only)** | | |
| Bubble speed | 1500 px/s | |
| Fire rate cap | 1 / 0.5 s | |
| Aim assist | ON, 1 ricochet preview | Locked v1 |
| Queue depth | 1 + 1 on-deck | |
| Swap cost | Free | |
| Cannon disabled in Phase 2 | Yes | Dimmed + tap-inert |
| **Hero bubbles** | | |
| Density | 1 in 8 (v1 greybox flat) | v2 will tier by board size |
| Minimum in starting cluster | 1 | Floor every stage |
| Visibility | Always visible (face on bubble) | No cracked-on-damage |
| **Heroes** | | |
| Heroes per popped hero-bubble | 1 | Tier scales by match size: **3-5 → Bronze, 6-9 → Silver, 10+ → Gold** |
| Bronze HP / DMG | 100 / 10 | Match 3-5 (default for any normal hero-bubble pop; also Color Bomb on early-stage clusters where ~5 of each colour are present) |
| Silver HP / DMG | 150 / 20 | Match 6-9 (good chain or mid-stage Color Bomb on a slightly heavy colour) |
| Gold HP / DMG | 200 / 30 | Match 10+ (rare — heavy single-colour cluster or Color Bomb on stage 4-5 sized boards) |
| Hero spawn row | Row 0 only (on spawn line) | Column directly below popped hero bubble; nearest empty if full |
| Row-0 full handling | Tier-upgrade replace OR FIFO queue (max 3) | No silent overwrite |
| Drag (Phase 2) | Free, no cooldown, full row-0 range | Phase 1 = stationary; Phase 2 = fully draggable |
| **Merge (drag onto match)** | Same class + same tier → next tier, full new-tier HP | Bronze+Bronze → Silver; Silver+Silver → Gold; Gold caps; cross-tier and cross-class do NOT merge |
| Merge animation | 0.4 s (pull-in + flash + scale-up) | Same in P1 and P2 |
| P1 auto-merge | On, if freed hero lands on matching row-0 cell | Resolves before nearest-empty / replace / queue |
| Carry-over | **HP + column placement preserved** | No heal, no tier change |
| Color frenzy buff | +50% damage, entire Phase 2 | On full color clear in P1; persists no-timer; does not carry across stages |
| Color counter | 2× damage | Same color hero vs enemy |
| **Hero class behavior (v1 enabled: Red, Blue, Yellow)** | | See `combat-design.md` §5 |
| Red (Fire Knight) | Cone, 0.75 s, 1.0× dmg, 25% cleave | DPS |
| Blue (Ice Mage) | Column splash, 1.6 s, 0.7× dmg, 30% slow / 2 s | Slow |
| Yellow (Archer) | Full column, 1.2 s, 1.4× dmg, execute +50% under 30% HP | Range |
| **Enemies (Phase 2)** | | |
| Red HP / speed / dmg | 50 / 1.0 / 10 | |
| Blue HP / speed / dmg | 80 / 1.5 / 10 | |
| Yellow HP / speed / dmg | 120 / 1.2 / 15 | |
| Enemy spawn position | Top of device (~row -15) | Drop-in 0.25 s/cell |
| Wave spawn interval | 1.5 s default | Per-stage tunable |
| **Cluster-converted enemies** | | NEW v2 mechanic |
| Type | Walker (no variant) | One per leftover bubble |
| Spawn position | At bubble's column, falls from cluster zone | |
| **Specials** | | |
| Color bomb cadence | Every ~15 shots | 12-18 random |
| **Player** | | |
| Stage start HP | 100 | Persists within stage |
| **Stage** | | |
| Stage clear "no enemies" timer | 2 s | After last enemy death |
| Phase transition "GET READY" | 1 s wipe | P1 → P2 |
| Coins per clear | 50 | Logged only |
| **Boss (stage 5)** | | |
| Boss HP | 1000 | |
| Boss damage on reach | 50 | |
| Stage 5 move budget | 16 | + cluster shake |
| Boss spawn | 30 s into P2 OR after last walker | Whichever first |

---

## Section 4 — Economy & progression

> **v1 stance: zero economy in the playable build.** No currencies, no shop, no gacha, no battle pass, no daily quests, no ads, no IAP. The boon pick after each stage is the only reward surface. First $4.99 moment is specced (Extra Moves continue) but not implemented.

### 4.1 v1 — what exists

| Element | v1? | Notes |
|---|---|---|
| In-run coins (logged but unused) | ✅ Logged only | +50 per stage clear |
| Boon pick | ✅ | 1 of 3 cards after each stage clear (§4.2) |
| Run completion reward | ✅ Logged only | "Run stars" 0-5 based on stages cleared + HP remaining |
| Cross-run currency | ❌ | No persistent currency in v1 |
| Hero unlocks | ❌ | All 3 v1 classes available from Run 1 |
| Gacha | ❌ | v2 |
| Battle pass | ❌ | v2 |
| Extra Moves continue offer | ❌ Specced, not built | v1.5 |

### 4.2 Boon pool (v1)

10 boons total. 3 drawn without replacement per stage clear. 4 boons picked across a 5-stage run = 40% of the pool — high variety.

| Boon | Effect | Notes |
|---|---|---|
| Red Bias | +30% chance next bubble is Red | Color-focus play |
| Blue Bias | +30% chance next bubble is Blue | Color-focus play |
| Yellow Bias | +30% chance next bubble is Yellow | Color-focus play |
| Damage +25% (Red) | All Red heroes deal +25% damage for the run | Class buff |
| Damage +25% (Blue) | All Blue heroes deal +25% damage for the run | Class buff |
| Damage +25% (Yellow) | All Yellow heroes deal +25% damage for the run | Class buff |
| Hero Bubble Density +50% | Next stage only — more hero bubbles in cluster | NEW v2 boon |
| Bronze→Silver | Next stage, all freed heroes start one tier up | NEW v2 boon |
| Extra Moves +2 | Next stage cannon gets +2 to move budget | NEW v2 boon — tunes Phase 1 generosity |
| **Color Affinity** (synergy) | If you have any Color Bias active, that color's bubbles also have +20% chance to be hero bubbles | Build-craft test boon |

### 4.3 Progression curve (within a run)

| Stage | Cluster | Move budget | Wave composition | New element | Difficulty intent |
|---|---|---|---|---|---|
| 1 | 5 × 4 | 10 | 5 Red walkers + leftover-cluster enemies | Red only — tutorial pace | "Easy win" — learn aim + hero-bubble pop + Phase 2 dragging |
| 2 | 5 × 5 | 11 | 4 R + 2 B + leftover | + Blue introduced | "First color-mix wave" |
| 3 | 5 × 5 | 13 | 4 R + 3 B + 2 Y + 1 Runner + leftover | + Yellow + Runner variant | "Three-color juggle, drag matters more" |
| 4 | 6 × 6 + cluster descent | 14 | 5 R + 3 B + 3 Y + 1 Runner + 1 Brute + leftover | + Cluster descent + Brute | "Be efficient with moves OR lose to descent" |
| 5 (boss) | 6 × 7 + cluster shake | 16 | 6 R + 4 B + 4 Y + 2 Runners + 2 Brutes + Boss + leftover | + Cluster shake + boss | "All systems at once: aggressive Phase 1 to limit leftovers + balanced army + drag timing in Phase 2" |

**Tuning intent:** Stages 1-3 teach mechanics one at a time. Stage 4 introduces descent — player must be efficient. Stage 5 stress-tests with cluster shake.

### 4.4 What v2 economy will look like (spec-only, not built)

| Stream | Rough shape | Lifted from |
|---|---|---|
| Soft currency | "Pop Coins" — earned per stage, spent on cannon upgrades + boon-pool unlocks | Lucky Defense |
| Premium currency | "Gems" — IAP + sparse drops, spent on gacha pulls + Extra Moves continue | Slime Legion |
| Gacha | ~25 heroes (5 per color), 4 rarities, pity at 80 | Habby standard |
| **Gacha-to-gameplay link** | Pulled heroes weighted heavier in hero bubbles you encounter during runs | **Pop Brigade's distinctive monetization shelf** |
| Battle pass | Seasonal $5-10, ~30 levels, free + premium track | Slime Legion / Lucky Defense |
| Energy | 5 runs / day, refill via gems or 30-min timer | Standard |
| Ad rewards | Revive on stage fail, double end-of-run rewards, free daily spin | Standard |
| **First $4.99 moment** | "Extra Moves" continue — when Phase 1 budget hits 0 with cluster still full, pay gems for +3 moves | Players will be deep into a stage when this fires |
| Daily/weekly events | Color-themed challenges (e.g. "Red Week — bonus drops on Red pops") | Habby live ops |

---

## Section 5 — Content scope for v1

### 5.1 Content lock list

| Category | v1 count | Items |
|---|---|---|
| **Stages** | 5 | S1 (intro), S2 (Blue), S3 (Yellow + Runner), S4 (descent + Brute), S5 (boss + shake) |
| **Hero classes** | 3 | Red (Fire Knight), Blue (Ice Mage), Yellow (Archer) |
| **Hero tiers** | 3 | Bronze, Silver, Gold |
| **Enemy types** | 3 | Red walker, Blue walker, Yellow walker |
| **Enemy variants** | 3 | Walker (default), Runner (stage 3+), Brute (stage 4+) |
| **Bosses** | 1 | Purple "Sludge Lord" — placeholder. Cluster-shake P1 mechanic. |
| **Special bubbles** | 1 | Color bomb |
| **Boons** | 10 | See §4.2 (includes 1 synergy boon) |
| **Cannon variants** | 3 | Red-bias, Blue-bias, Yellow-bias (loadout) |
| **Cluster patterns** | 3 | One per starting-row tier (4-row, 5-row, 7-row) |
| **VFX states** | ~10 | Pop, hero-bubble pop (face-burst), falling, hero spawn, hero attack, hero death, hero drag-lift, enemy hit, enemy death, color frenzy, cluster-converted-enemy spawn, cluster descent tick (stage 4+) |
| **Screens** | 8 | See `ui-flow.md` |
| **Music tracks** | 0 | None in v1 |
| **SFX** | ~6 | Optional v1.1 |

### 5.2 Explicitly out of v1

| Asked for | Decision | Reason |
|---|---|---|
| Green (Druid) / Purple (Wizard) heroes | v1.5 | 3 classes are enough to test the architecture |
| Multiple boss types | v2 | One boss enough |
| Tutorial overlay | v2 | Verbal tester guidance |
| Settings menu | v2 | Device defaults work |
| Sound design | v1.1 | Optional |
| Player profile / stats screen | v2 | Run-end screen is enough |
| Retry on fail | ❌ Never | Clean instrumentation |
| Daily reward | v2 | No persistent state |
| Cosmetics | v2+ | Greybox = no art |
| Multiplayer / clan | v2+ | Way later |
| Hero gacha UI | v2 | v1 uses random pool from 3 classes |
| Extra Moves continue offer | v1.5 | Specced; not built |
| Multi-row hero placement | v2 | Row 0 only |

### 5.3 Build sprint plan (4 weeks, 1 designer + 1 engineer)

| Week | Designer | Engineer | Gate |
|---|---|---|---|
| **W1** | Lock cluster grid + spawn line + hero-bubble visibility. Move-budget UX (HUD counter). Greybox art on paper. Boon copy. | Phase 1: cluster physics, attach, match detection, hero-bubble system (visible face overlay, free-on-pop), move-budget counter, Phase 1 end on budget = 0. Phase state machine + 1s wipe. | Phase 1 playable in isolation; ends correctly on budget exhaustion; heroes sit idle on row 0. |
| **W2** | Lock hero class behaviors (R/B/Y) + drag input model + wave scripts stages 1-3. | Phase 2: scripted wave spawner, **cluster-converted enemy spawner**, hero auto-fire, **drag-to-reposition on row 0**, color counter, color frenzy carryover, HP/damage, stage clear/fail, hero carry-over (HP + column preserved). | Full 3-stage playable end-to-end. |
| **W3** | Cluster descent rules (stages 4+) + boss cluster-shake. Stage 4-5 tuning. | Stages 4-5 (descent + Brute + boss + cluster shake). Boss mechanic. | Full 5-stage run playable. |
| **W4** | Boon UX. Run-end stats screen. Tester recruitment + debrief script. | Screens 1/2/3/5/6/7/8, instrumentation logging, polish + bug fix. | All 8 screens connected; full run end-to-end; telemetry firing. |

---

## Section 6 — Test hypothesis + instrumentation

### 6.1 The 4 questions → measurable signals

**Question priority:** Q1 is the **existential** test (architecture lives or dies on it). Q2-Q4 are **tunable**.

| # | Question | Pass signal | Kill signal | Measurement |
|---|---|---|---|---|
| **Q1 (existential)** | Does build → defend read as one game — specifically, do players connect "bubbles I left unpopped" with "enemies that arrived in Phase 2"? | Tester describes: "the bubbles I left came back as enemies" or equivalent. Can predict "if I pop more, fewer enemies" correctly at debrief. | Tester describes two disjoint experiences; treats the Phase 2 wave as scripted/unrelated to their P1 play | Verbal debrief Q1, Q9; transcribed and tagged |
| Q2 (tunable) | Is the hero-bubble priority decision interesting? | Testers vocalise the trade-off ≥1 per stage; 70%+ of hero-bubble pops look intentional | Pop choices look random; testers can't articulate priority | Observer notes; debrief Q5 |
| Q3 (tunable) | Does Phase 2 hero dragging feel like real agency? | ≥2 drags per Phase 2 average; 60%+ of drags causally tied to a wave threat | Constant fidgeting OR no dragging | Drag event count per P2; observer "purpose of drag" tally |
| Q4 (tunable) | Does each stage produce ≥1 highlight per phase (≥2 per stage)? | Observer counts ≥1 audible reaction per phase | Flat affect in either phase | Observer tally per phase |

### 6.2 Telemetry — events to log (engineer spec)

Log to local file per session: `pop-brigade-v1-<tester-id>-<utc-ts>.jsonl`.

| Event | Payload | When logged |
|---|---|---|
| `session_start` | `{ tester_id, build_version, device_model, os_version }` | App boot |
| `loadout_pick` | `{ cannon_color }` | Loadout screen tap |
| `stage_start` | `{ stage_num, cluster_start_rows, move_budget, hp, heroes_carried_in }` | Match begin |
| `phase1_start` | `{ stage_num, cluster_start_size, move_budget }` | Phase 1 begin |
| `bubble_fired` | `{ stage_num, bubble_color, moves_remaining_after, queue_swap_used, aim_angle_deg }` | Each shot |
| `bubble_attached` | `{ bubble_color, attached_row, attached_col, was_hero_bubble: bool, cluster_size_after }` | Each successful attach |
| `match_pop` | `{ match_size, color, cascade_chain_count, hero_bubbles_in_match: int, heroes_freed: [{class, tier, lane_col}] }` | Each pop |
| `hero_bubble_freed` | `{ class, tier, lane_col, source: "match" \| "carryover" }` | Each hero placed on row 0 |
| `cluster_descend` | `{ rows_now, time_since_last_descend_ms, stage_num }` | Each descent tick (stages 4+) |
| `boss_cluster_shake` | `{ rows_dropped, time_since_last_shake_ms }` | Each shake (boss only) |
| `color_frenzy_trigger` | `{ color, heroes_at_trigger_count }` | Each full color clear in P1 |
| `phase1_end` | `{ stage_num, ms_elapsed, reason: "budget_exhausted" \| "cluster_cleared" \| "cluster_reached_row_0", moves_used, bubbles_left_in_cluster, heroes_built_total, max_chain, frenzied_colors }` | P1 → P2 transition |
| `cluster_converted_to_enemy` | `{ bubble_color, lane_col, count_total }` | Per leftover bubble at transition |
| `phase2_start` | `{ stage_num, hero_count, hero_composition, scripted_wave_size, cluster_converted_enemy_count }` | P2 begin (after wipe) |
| `enemy_spawn` | `{ enemy_id, color, lane_col, variant, source: "wave_script" \| "cluster_converted" \| "boss_drop" }` | Each enemy on lane |
| `hero_drag` | `{ hero_id, from_col, to_col, dragged_ms, color, tier, resolution: "move" \| "swap" \| "merge" }` | Each completed drag. **Note (impl 2026-05-13):** prototype allows drag in P1 + transition + P2 (only blocked once stage ends). Payload also denormalises `color, tier` to avoid a join. Spec originally said "P2 only" — left open as a tuning question (do P1 drags hurt the spawn-column read?). |
| `hero_merge` | `{ class, color, source_tier, result_tier, source_col, target_col, trigger: "drag" \| "p1_auto", source_hp_before, target_hp_before, ms_since_phase_start }` | Each completed merge. Drag-triggered (P2) or auto-triggered (P1 row-0 collision). Logged regardless of trigger. |
| `hero_attack` | `{ hero_id, target_id, damage_dealt }` | Each attack (sample 1 in 10) |
| `hero_death` | `{ hero_id, class, tier, lifetime_ms, damage_dealt_total }` | Each hero death |
| `enemy_death` | `{ enemy_id, color, variant, killed_by_class, lifetime_ms }` | Each enemy killed |
| `enemy_reached_cannon` | `{ enemy_id, color, hp_damage }` | Each leak |
| `phase2_end` | `{ stage_num, ms_elapsed, result: "clear" \| "fail", hp_remaining, enemies_killed, enemies_leaked, heroes_lost, drag_count }` | P2 ends |
| `boon_picked` | `{ stage_num, boon_id, alternatives }` | Stage clear pick |
| `stage_clear` | `{ stage_num, hp_remaining, total_ms, p1_ms, p2_ms, moves_used, total_pops, hero_bubble_pops, hero_drags, max_chain }` | Stage clear |
| `stage_fail` | `{ stage_num, hp_remaining, reason: "hp", ms_elapsed }` | Stage fail (P2 only) |
| `run_end` | `{ stages_cleared, total_ms, total_pops, total_moves_used, total_heroes_freed, total_drags, total_enemies_killed, total_frenzies, max_chain, completion: "win" \| "fail" \| "quit" }` | Run end |
| `pause_open` | `{ stage_num, phase: 1 \| 2, ms_into_stage }` | Pause |
| `pause_resume` | `{ pause_duration_ms }` | Resume |
| `session_end` | `{ runs_completed, total_session_ms }` | App close |

**Key derived metrics:**
- **Pop rate** = pops / moves used (target: ≥0.4 by stage 3)
- **Hero-bubble pop ratio** = hero_bubble_pops / total_pops (target: matches 1-in-8 density baseline)
- **Cluster leftover ratio** = bubbles_left_in_cluster / cluster_start_size (correlate with Q1 — testers who connect leftovers → wave will minimize this on later stages)
- **Drag count per Phase 2** = drag_count / stages played (target: 2-4/stage; 0 or 10+ flags a problem)
- **Merge rate** = merges / stage; **merge intent share** = merge-resolution drags / total P2 drags (target: ≥20% of P2 drags resolve as merges by stage 3 — confirms players grasp the mechanic)
- **Tier composition at P2 end** = ratio of Bronze:Silver:Gold surviving (correlate with merge rate — high merge rate should shift composition toward Silver/Gold)
- **Phase 1 end reason distribution** — diagnostic for pacing (budget vs descent vs cleared)
- **Q4 dopamine density** = (silvers + golds + hero_freed + frenzies + chain≥3 + drag_save_moments) / stage_min

### 6.3 Tester recruit + debrief

**Recruit profile (target 6-8 testers):**
- Plays at least one of: Slime Legion, Lucky Defense, Capybara Go
- Plays at least one bubble shooter
- Age 25-45, mixed gender (target ≥50% female)
- Plays mobile ≥30 min/day

**Session structure (45 min per tester):**
1. **5 min** — intake
2. **2 min** — "Play it however you want. No help unless stuck 30+ s."
3. **20 min** — observed play, 2-3 runs
4. **15 min** — structured debrief
5. **3 min** — wrap

### 6.4 Debrief script (locked questions)

1. "Describe what you just played in one sentence."
2. "Walk me through what happens in a stage from start to finish." → **Q1 signal**
3. "How did the building part feel? How did the defending part feel?" → **Q2/Q3 signal**
4. (Likert) "Phase 1 (popping bubbles) — engaging / neutral / boring 1-5"
5. (Likert) "Phase 2 (watching and dragging your heroes) — engaging / neutral / boring 1-5"
6. (Likert) "How likely to play more rounds now? 1-5"
7. "Were there moments that felt great? When?" → **Q4 signal**
8. "Were there moments that felt bad? When?"
9. "What did your shots in Phase 1 control? What changes if you pop more bubbles?" → **Q1 causal-chain probe** (if they don't connect leftover bubbles to wave, Q1 fails)
10. "Tell me about a time you moved a hero. Why did you move them there?" → **Q3 signal**
11. "What did the bubbles with faces on them do?" → hero-bubble visibility check
12. "Anything else?"

### 6.5 Decision matrix (post-test)

**Kill question = Q1.** Q2-Q4 are tuning signals.

| Q1 | Q2 | Q3 | Q4 | Outcome |
|---|---|---|---|---|
| Pass | Pass | Pass | Pass | **Go to vertical slice** with art + sound |
| Pass | Pass | Pass | Fail | Iterate dopamine density. Same architecture. |
| Pass | Pass | Fail | Pass | Iterate drag affordance / column count. Same architecture. |
| Pass | Fail | Pass | Pass | Iterate hero-bubble density / readability. Same architecture. |
| Pass | Fail | Fail | Any | Iterate multiple axes. Same architecture. |
| **Fail** | Any | Any | Any | **Causal link failed** — testers don't connect leftover bubbles to wave. Rework Phase 1 → Phase 2 visualization (more dramatic conversion VFX, telegraphed in-cluster previews). Re-test. |

**Bar:** 5/8 testers pass Q1 for the architecture to live.

---

## Section 7 — Open questions & risks

### 7.1 Open questions

| # | Question | When to answer |
|---|---|---|
| OQ1 | Move budget tuning: 10 at L1 right, or 8 / 12 / 15? | W1 internal play |
| OQ2 | Phase transition wipe: 1 s "GET READY!" vs longer "INCOMING!" w/ leftover-cluster preview that shows the conversion in slow-motion | W2 internal play — slower wipe might help Q1 causal link |
| OQ3 | Hero-bubble density 1-in-8 fixed in v1, or scale down with stage 4+ (bigger boards)? | W3 — confirm at greybox |
| OQ4 | Cluster descent rate (stages 4+): 12 s/row vs 15 s/row vs scaling with moves used | Internal — try both |
| OQ5 | Boss cluster shake interval: 15 s vs 12 s vs 20 s | W3 |
| OQ6 | Color frenzy carryover duration: full wave (current) vs first 10 s of wave vs 3 enemy kills | W2 internal play |
| OQ7 | Drag affordance — column highlight follows finger continuously, or only snap to discrete columns? | W2 |
| OQ8 | Greybox readability — does no-art produce valid signal for Q1 specifically? | After tester 2-3 |
| OQ9 | One synergy boon (Color Affinity) — is one enough, or do we need 2-3 to test build-craft? | After tester 3-4 |
| OQ10 | Cluster-converted enemies — should they have a distinct visual (e.g., "angry bubble" look) vs identical to scripted-wave walkers? Strong visual link to Q1 causal arc. | W3 |
| OQ11 | Carry-over HP — preserved exactly, or partial heal (e.g., +20 HP between stages)? Current: exact preserve. | After tester 2-3 |
| OQ12 | **Merge HP rule** — full new-tier HP (current spec) vs sum-of-HPs vs higher-HP-source. Full reset is cleanest but punishes merging damaged heroes; sum-of-HPs rewards merging early. | After tester 2-3 |
| OQ13 | **Merge readability** — is drag-to-merge legible without a tutorial prompt? Tester reaction when they accidentally merge will tell us. If <50% of testers grasp it within stage 2, add a one-time hint on first matching-pair spawn. | After tester 2-3 |
| OQ14 | **Should mass-merge cascade?** If a Silver merges with another Silver into Gold, and a third Silver is adjacent — does the resulting Gold immediately become available to merge? v1: no — each merge is a discrete drag (or discrete P1 spawn event). | W3 |

### 7.2 Risks (and mitigations)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Players can't connect leftover bubbles → wave (Q1 fails)** | Medium | **Existential** | Pre-test: design the transition VFX to be impossible to miss. Each leftover bubble visibly drops out of cluster and becomes an enemy in the same column. "Conversion ratio" preview during the wipe ("8 bubbles left → 8 extra enemies"). If Q1 still fails, rework transition staging. |
| **Move budget feels too tight (testers can't make 10 shots count)** | Medium | Phase 1 frustration | Have +2 budget pre-tuned per stage; swap in if Stage 1 testers run out without freeing any hero. |
| **Move budget feels too generous (testers clear cluster easily with shots to spare)** | Medium | Phase 2 too easy | Have -2 budget pre-tuned; check leftover_ratio metric — if <20% across testers, tighten. |
| **Hero dragging is unused / pointless** | Medium | Q3 fails | First lever: spawn heroes in unhelpful columns more often (force drag). Second lever: position-bonus boons (heroes deal +10% in adjacent-color column). |
| **Greybox confuses testers** | Medium | Q1/Q4 polluted | Pre-test: 1-2 friendly internal testers in W4. If "no art" dominates, recruit one artist for v1.1 hero-portrait pass before external test. |
| **4-week build slips** | Medium | Pushes tester window | Cut scope: drop Brute variant (only Walkers + Runners), drop synergy boon (Color Affinity), drop boss cluster-shake (boss is just bigger wave). Test stays valid. |
| **Cluster descent (stages 4+) feels arbitrary** | Medium | Stage 4-5 frustration | Visual cue: descent tick has a clear bump/shake animation. Internal play test at W3. |
| **Aim assist too aggressive → bubble shooter identity lost** | Medium | Q2/Q3 mixed | A/B in test: half testers get full assist, half get first-segment only. |
| **Designer/engineer disagreement on tuning** | Medium | Slippage | §3.9 is source of truth for W1-W4. Tuning changes need both signatures + a 1-line "why" in commit. |
| **Merge intent collides with reposition intent in P2** | Medium-High | Q3 muddied — drag count goes up but "purpose of drag" gets noisy | `hero_drag.resolution` field separates move/swap/merge in telemetry. If observers see frustration ("I meant to reposition, it merged"), add a long-press → "merge mode" affordance or visual matching-pair highlight on drag-lift. |
| **Players never use merge** | Medium | New mechanic dead | Pre-test: ensure stage 2-3 spawns produce ≥1 matching-pair opportunity per stage (designer-tuned). First lever: increase hero-bubble density of single colour. Second: hint on first matching-pair spawn ("drag to merge"). |
| **Merge makes Phase 2 too easy** (one Gold per column trivialises stage 4-5) | Medium | Difficulty curve breaks | Enemy HP/wave scripts tuned assuming average tier mix of B/S/G ≈ 50/35/15 by stage 5. If testers consistently reach 60%+ Gold composition, scale stage 4-5 wave by +20%. |

### 7.3 What this v1 is NOT trying to prove

- **Monetization.** No spend signal. v2.
- **D1/D7 retention.** No persistent state, no push, no ads. v2.
- **Long-term meta loop appeal.** Meta isn't built.
- **Live ops cadence.** v2+.
- **Soft-launch market fit.** v3+.
- **Hero diversity / collection appeal.** 3 classes only; gacha not built.
- **UA creative testing.** No marketing assets needed for v1.
- **Full class roster.** Druid (Green) and Wizard (Purple) deferred to v1.5.

If a stakeholder asks "does this prove X?" and X is on this list, the answer is no — by design.
