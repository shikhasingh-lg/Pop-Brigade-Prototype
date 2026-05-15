---
name: Pop Brigade — Design Spec
status: draft
created: 2026-05-11
updated: 2026-05-14
concept_doc: ~/game-research/pop-brigade/concept.md
combat_doc: ~/game-research/pop-brigade/combat-design.md
ui_flow_doc: ~/game-research/pop-brigade/ui-flow.md
locked_architecture: Phased Build → Wave, Phase 1 ends on hero-bubbles-exhausted OR move-budget-zero (whichever first), hero bubbles only spawn heroes, same-class-same-tier heroes merge up
---

# Pop Brigade — Design Spec

> **Scope of this doc:** Prototype-ready spec for the v1 greybox. Covers core mechanics, economy, content, and test hypotheses tight enough that engineering + design can build without re-asking the designer. UI lives in `ui-flow.md`. Per-class combat (targeting + VFX) lives in `combat-design.md`.

> **Locked architecture:** **Phased Build → Wave.** Each stage runs in two phases.
> **Phase 1 (Build):** Cluster of bubbles hangs above. Cannon has a fixed **move budget** (10 shots at L1, scaling up by stage). Player aims and fires. Match 3+ pops bubbles. Specific bubbles have heroes trapped inside (1-4 per stage in v1 greybox, weighted roll) — popping those frees the trapped hero onto row 0 below where the bubble was. Heroes stand idle; no enemies present.
> **Phase 1 ends when ALL hero bubbles have been bursted, OR the move budget hits zero — whichever happens first.** Any non-hero bubbles still in the cluster are swept off the field. A **scripted enemy wave** begins.
> **Phase 2 (Combat):** Heroes auto-attack the scripted wave. **Heroes are draggable horizontally along row 0** — player repositions them in real time to meet the wave. No bubble firing in Phase 2. Stage clear when all enemies defeated; stage fail at HP 0.
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
| 2026-05-14 | **Meta progression spec rewritten (§4.4)** — adopted Slime Legion spine: hero level (1–30) as identity track, hero shards + Pop Coins + Gems as the only 3 currencies, chest gacha (40 heroes, 8/color), chapter map (5 realms × 5 stages), cannon mastery (moves/capacity/choice — NO damage), bubble-pool weighting as monetization shelf. Added 30-day pacing journey + anti-goals. | v1 critique flagged meta as the biggest gap. Locked the spine before vertical-slice playtest so the v1 signal is interpretable in meta context, and so the bubble-pool weighting (the only true differentiator) is validated for readability in greybox rather than at soft launch. |
| 2026-05-14 | **Cross-realm scaling locked (§3.10)** — cluster grows R1→R5 (rows +1/realm, width up at R3+), move budget scales +2/realm at every stage, hero density drops 1/8 → 1/10 to keep hero count bounded against merge snowball, classes chapter-gated in cluster (R3 +Green / R5 +Purple) but always-pullable from gacha, enemy HP/DMG ×3.2 by R5 with speed capped at ×1.4 for readability, new enemy variant per realm (Shielder/Healer/Accelerator/Phaser), hero level 1-30 scaling base stats × 1.0→2.5 (range/AS/special untouched as class identity), modifier stacking additive (counter stays multiplicative, frenzy+boons add). | Closes the cross-realm progression gap surfaced by the systems-designer review — v1 telemetry stays interpretable in the full curve, and the modifier-stacking decision is locked BEFORE we add synergy boons (§4.2.B) so the math ceiling doesn't explode. |
| 2026-05-14 | **Realm content build locked (Section 8)** — all 25 stages, 5 bosses, 5 class additions (R/B/Y baseline; +Green at R3; +Purple at R5), 4 new enemy variants (Shielder R2 / Healer R3 / Accelerator R4 / Phaser R5), realm gimmicks (R2 early-shake / R3 vine-lock / R4 cluster-descent-everywhere / R5 two-boss finale). Druid (Green) = chain-heal support; Wizard (Purple) = AOE burst. Star criteria, shard-rotation pool per realm, content-specific risk register locked. | Playable progression sketched end-to-end before economy numbers pass so chest drops, shard rotation, and energy economy can be tuned against a known content runway — not a vague "R5 will exist eventually." |
| 2026-05-14 | **Phase 2 added (§9) — full R1-R5 playable + chapter UI.** R1 hypothesis test still gates the rest (§6.5). New phase adds: R2-R5 content (§8.3-§8.6), Druid + Wizard classes, 4 new enemy variants, 5 new bosses, chapter map UI (3 new screens, 11 total), and the `playtest_mode` config preset (simulated L15 roster, all classes pre-unlocked) so testers play full content without meta built. §5 v1 scope preserved as-is. | Original R1-only plan was correct for testing the core loop in isolation. Committing to all 5 realms unlocks cross-realm progression validation, playtest of content runway at scale, and commercial-shape conviction before the meta econ pass. Hypothesis test on R1 still de-risks the architecture before broader content commits. |
| 2026-05-14 | **Leftover-bubbles-become-enemies REMOVED.** Phase 1 → Phase 2 transition no longer converts unbursted cluster bubbles into Phase 2 enemies; leftovers are swept off the field. Phase 2 difficulty comes from the scripted wave alone. | The cluster-converted-enemy hook was the central differentiator in the original concept but never landed in the v1 prototype (`cluster.sweep_all()` clears leftovers) and on review the team agreed the dual-source enemy stream muddied Phase 2 readability — testers couldn't separate "wave I'm fighting" from "punishment for missed shots." Removing it simplifies Phase 2 and lets the hero-bubble recruitment race carry the Phase 1 → Phase 2 throughline. |
| 2026-05-14 | **Phase 1 end condition changed: `hero_bubbles_remaining == 0 OR move_budget == 0` (whichever first).** Hero-bubble exhaustion is the new "success" trigger; budget-zero remains the "you ran out of room" trigger. Cluster cleared and time cap retained as belt-and-braces. | Pairs with the leftover-removal above. Without leftover-becomes-enemies, the only meaningful Phase 1 goal is *recruit your army* — so the moment every hero is freed, Phase 1 should end. This sharpens the move-budget into a real recruit-or-waste race and removes the awkward "I freed all the heroes 4 shots ago, why am I still firing into trash?" tail. |

---

## Section 1 — Pitch

### One-line hook
A vertical-lane tower defense in two phases per stage. **Phase 1:** fire a limited number of bubbles at the cluster overhead; specific bubbles trap heroes — pop them to free the heroes onto your line. Phase 1 ends the moment every hero bubble is freed, or you run out of shots. **Phase 2:** a scripted wave attacks, and your pre-built army fights — but you can drag your heroes to meet the threat. Build, then defend.

### Fantasy
Your brigade is sealed in bubbles in the sky. Every shot is a recruit-or-waste decision: free a hero you need, or burn a shot clearing the wall in front of them. The moment your last hero is freed (or your last shot is gone), the army you built marches; you reposition them on the line as the wave comes.

### Target player
Slime Legion / Lucky Defense / Capybara Go / Bubble Witch player. Hybrid casual, female-skew, 5-15 min sessions, comfortable with ~4 cognitive layers, plays multiple Habby-tier TD hybrids.

### Why this concept (v1 thesis in one paragraph)
The bubble-shooter lane is the most fragmented top-grossing puzzle lane on mobile (5 publishers in top 5, no UA giant, $500-700K/mo). Slime Legion proved color-as-spawner + lane TD + gacha works. Existing bubble-TD hybrids fail because cluster and lane feel disconnected — they play simultaneously and the player can't focus on either. **Pop Brigade phases them, then ties them with a recruit-race transition:** Phase 1 ends the moment you've freed every trapped hero (or burned through your shots), and the army you assembled is exactly what fights for you in Phase 2. The phased model is comp-validated (Slime Legion, GearPaw both ship build-then-defend), so the watching phase is solved territory — and we make it actively interesting by letting the player drag heroes during the wave. If v1 proves the build → defend chain reads as **one game**, the lane is ours.

### What we are testing in v1

| Question | Pass signal | Kill signal | Notes |
|---|---|---|---|
| **Q1 (existential):** Does the build → defend chain read as **one game** — specifically, do players experience Phase 1 as "I am recruiting the army that Phase 2 fights with"? | Testers describe loop as "I had 10 shots to free as many heroes as I could before the wave came; the heroes I freed are the ones that fought" — single causal arc, build-then-defend | Testers describe two disjoint experiences; treat Phase 2 as scripted/unrelated to the heroes they freed | **This is the kill question.** Phased TD is comp-validated. What's untested is whether *hero-bubble recruitment under a shot budget* makes Phase 1 feel like setup for the Phase 2 they're about to play. |
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
| Bubble Witch 3 | Aim-fire feel, cluster physics, ricochet | Move budget replaces moves-or-puzzle-complete; hero-bubble recruitment is the real Phase 1 goal, not cluster clear |
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
  │            └──► moves left AND hero bubbles left? ──yes──► AIM   │
  │                                                                  │
  │   Phase 1 ends when HERO BUBBLES = 0  OR  MOVE BUDGET = 0        │
  │   (whichever first)                                              │
  └──────────────────────────────┬───────────────────────────────────┘
                                 ▼
  ┌──── TRANSITION (1s "GET READY!" wipe) ────────────────────────────┐
  │                                                                  │
  │   Any non-hero bubbles still in the cluster: swept (cleared).    │
  │   No conversion to enemies.                                      │
  │                                                                  │
  │   Scripted enemy wave begins.                                    │
  └──────────────────────────────┬───────────────────────────────────┘
                                 ▼
  ┌──── PHASE 2: COMBAT (drag-and-defend) ────────────────────────────┐
  │                                                                  │
  │   Heroes auto-fire at scripted-wave enemies                      │
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

**Phase 1 target cadence:** 1 shot every ~2-3 sec. With 10 moves at L1 and a hero-bubble exhaustion trigger, Phase 1 length ≈ 15-30 sec (shorter when the player gets to hero bubbles efficiently; longer when they burn shots clearing walls).
**Phase 2 target cadence:** Wave length 45-90 sec depending on stage.

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
[Boss stage 5: ~150 sec total] ──► boss spawns after last walker → run rewards
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
| Stage (Phase 1 + Phase 2) | Shot dopamine + payoff-watch + drag agency | 60-150 sec | Build → defend reads as one game; the heroes the player freed in Phase 1 *are* the army they fight with in Phase 2 |
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

**Move budget + hero-bubble race (Phase 1 end triggers):**
- Each stage starts with a fixed move budget displayed on the cannon HUD AND a fixed count of hero bubbles seeded into the cluster.
- Budget per stage (v1 prototype, see `GameConfig.move_budget_per_stage`):
  | Stage | Move budget | Notes |
  |---|---|---|
  | 1 | 10 | Tutorial pace |
  | 2 | 12 | + Blue introduced |
  | 3 | 12 | + Yellow + first Runner enemy |
  | 4 | 14 | + Brute enemy |
  | 5 (boss) | 16 | + boss spawn after walker wave |
- Each shot decrements the budget by 1.
- **Phase 1 ends the first time either trigger fires:**
  - `hero_bubbles_remaining == 0` (success — recruited every hero on the board), OR
  - `move_budget == 0` (you ran out of room — any un-bursted hero bubbles are forfeit).
- Cluster-fully-cleared and Phase 1 time cap (45/50/60/65/75 s for stages 1–5) are retained as safety nets.
- Whichever trigger fires first → 1s "GET READY!" transition → Phase 2 begins. Any non-hero bubbles still in the cluster are swept (no enemy conversion).

**Design implication:** the player's Phase 1 goal is *burst every hero bubble* before the budget runs out. Walls of non-hero bubbles between the cannon and a hero bubble force trade-offs — spend a shot drilling through, or angle a bank shot to reach the hero in fewer moves. Once the last hero bubble is bursted, Phase 1 ends instantly; you can't keep firing into trash.

**Removed in this rev:** Cluster descent (stages 4+) and boss-stage cluster shake — both were pressure mechanics for the old "burn budget by 0" model. With the hero-bubble exhaustion trigger, the race is naturally tense without secondary descent pressure. `GameConfig.cluster_descent_*` values remain zeroed in code as legacy.

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
- Heroes auto-fire at scripted-wave enemies in range. (No cluster-converted enemies — leftovers are swept on transition.)
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

**Single enemy source: the scripted wave.** Cluster leftovers do **not** convert to enemies — they are swept on the Phase 1 → Phase 2 transition.

**Scripted wave:**
- Independent of the player's Phase 1 performance — the scripted wave always plays.
- Each stage has a fixed enemy composition (see §4.3) and a fixed spawn schedule.
- Wave enemies spawn at the top of the device, fall through the cluster zone at 0.25 s/cell (~3.75 s anticipation window).

**Phase 2 threat = scripted wave only.** Phase 2 difficulty does NOT scale with how much cluster the player left behind. The Phase 1 performance signal lives entirely in *which heroes the player freed* (and at what tier) — a richer army handles a fixed wave more easily.

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

**Phase 1 end (transition to Phase 2):**
- Phase 1 ends on the FIRST of:
  - `hero_bubbles_remaining == 0` (every hero bubble has been bursted), OR
  - `move_budget == 0`, OR
  - Cluster cleared (no bubbles left at all), OR
  - Phase 1 time cap elapses (45/50/60/65/75 s for stages 1–5 — safety net).
- 1 s "GET READY!" wipe → any non-hero bubbles still in the cluster are swept → Phase 2 begins.
- No cluster-to-enemy conversion. No "cluster reaches row 0" early-end (descent is disabled).

**Stage clear rewards:**
- Run currency: +50 coins (in-run only, logged for telemetry)
- Boon pick: 1 of 3 (see §4.2)
- Cluster reset: new cluster generated for next stage at stage-defined starting size
- **Surviving heroes carry over to next stage's Phase 1.** HP + column placement preserved. No heal, no tier change. Class-damage boons picked at stage clear apply to restored heroes. Color-frenzy buffs do NOT persist across stages.

**Boss stage (Stage 5):**
- Cluster starts at 5×7 (35 bubbles). Cannon move budget = 16.
- Phase 1 ends when every hero bubble has been bursted OR move budget = 0.
- Phase 2: scripted wave (6 R + 4 B + 4 Y + 2 Runners + 2 Brutes).
- Boss spawns after last walker dies. Boss HP 1000, damage 50, purple (no hero color counter — pure throughput test).

### 3.9 v1 tuning value summary (single-page reference)

| Parameter | Value | Notes |
|---|---|---|
| **Cluster (Phase 1)** | | |
| Grid width | 5 cols (stages 1-3) / 6 cols (4-5) | Hex |
| Grid max height | 12 rows | |
| Stage 1-2 starting rows | 4 | |
| Stage 3-4 starting rows | 5 | |
| Stage 5 starting rows | 7 | Boss |
| Cluster descent | **Disabled** (legacy zeroed in `GameConfig`) | Was stages 4+; removed when hero-bubble exhaustion became the primary P1 end trigger |
| Boss cluster shake | **Removed** | Same reason — race-to-burst supplies the pressure |
| **Phase 1 end triggers** | `hero_bubbles_remaining == 0` OR `move_budget == 0` (first to fire); cluster-cleared and time cap as safety | See §3.8 |
| Phase 1 time cap (safety net) | 45 / 50 / 60 / 65 / 75 s for stages 1-5 | Only fires if both primary triggers somehow miss |
| **Move budget per stage** | | Decrements on each shot |
| Stage 1 / 2 / 3 / 4 / 5 | 10 / 12 / 12 / 14 / 16 | v1 prototype values (see `GameConfig.move_budget_per_stage`); concept aimed at 10/11/13/14/16 — open tuning |
| **Aim & fire (Phase 1 only)** | | |
| Bubble speed | 1500 px/s | |
| Fire rate cap | 1 / 0.5 s | |
| Aim assist | ON, 1 ricochet preview | Locked v1 |
| Queue depth | 1 + 1 on-deck | |
| Swap cost | Free | |
| Cannon disabled in Phase 2 | Yes | Dimmed + tap-inert |
| **Hero bubbles** | | |
| Count per stage (v1 prototype) | 1-4, weighted: P(1)=20%, P(2)=30%, P(3)=30%, P(4)=20% | Stage 1 floor = 2. Set via `GameConfig.hero_bubble_count_weights`. |
| Minimum in starting cluster | 1 (stages 2-5) / 2 (stage 1) | Floor every stage |
| Visibility | Always visible (face on bubble) | No cracked-on-damage |
| **Role** | Bursting every hero bubble is the **primary Phase 1 success trigger** | When the last hero bubble pops, Phase 1 ends immediately |
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
| **Cluster leftovers** | **Swept (cleared)** at Phase 1 → Phase 2 transition | No enemy conversion (removed 2026-05-14) |
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
| Stage 5 move budget | 16 | |
| Boss spawn | After last walker dies | |

### 3.10 Cross-realm scaling (R1 → R5, spec-only — NOT in v1 greybox)

> **Stance.** v1 greybox is **Realm 1 only**. This section specs how cluster size, enemy stats, hero stats, and modifiers scale across all 5 launch realms so the v1 telemetry stays interpretable in the larger curve. Locked now to avoid post-greybox rework.
>
> **Design rule.** Cluster grows, ammo grows with it, enemies grow harder, heroes get a *long-tail* scaling track. Class identity (range, AS, special) **does not** scale.

#### 3.10.1 Cluster + move budget per realm

Cluster grows by row count + occasional column count. Move budget scales with it so a skilled player can still race to burst every hero bubble before running out of shots — the more crowded the cluster, the more shots they need to drill to the hero bubbles.

| Realm | Cols | S1 → S5 rows | Move budget S1 → S5 | Cluster size at S1 / S5 | Notes |
|---|---|---|---|---|---|
| **R1** | 5 (S1-3) / 6 (S4-5) | 4 → 7 | 10 → 16 | 20 / 42 | Vanilla. Locked v1 spec. |
| **R2** | 5 (S1-3) / 6 (S4-5) | 5 → 8 | 12 → 18 | 25 / 48 | + Cluster shake on S3-5 |
| **R3** | 6 (all stages) | 5 → 8 | 14 → 20 | 30 / 48 | + Green class enters cluster; color-lock row gimmick |
| **R4** | 6 | 6 → 9 | 16 → 22 | 36 / 54 | + Cluster descent (1 row / 8 s, all stages) |
| **R5** | 6 | 7 → 10 | 18 → 24 | 42 / 60 | + Purple class enters cluster; two-boss finale |

**Scaling rule (formula):** `rows(R, S) = R1_rows(S) + (R - 1)`. Move budget scales +2 per realm at every stage. Width fixed by realm (no width changes mid-realm).

#### 3.10.2 Hero bubble density per realm

Density scales *down* per realm to keep hero count proportional to cluster size — prevents merge snowball at R5.

| Realm | Density | Heroes in cluster at S1 / S5 (expected) |
|---|---|---|
| R1 | 1 in 8 | 2.5 / 5.3 |
| R2 | 1 in 8 | 3.1 / 6.0 |
| R3 | 1 in 9 | 3.3 / 5.3 |
| R4 | 1 in 9 | 4.0 / 6.0 |
| R5 | 1 in 10 | 4.2 / 6.0 |

**Minimum floor: 1 hero bubble per cluster** at every stage (carries over from v1 §3.4).

#### 3.10.3 Color (class) availability in the cluster

Class-color reveal is chapter-gated in the cluster, **NOT** in gacha. Gacha can drop any of the 5 classes from D1; those heroes sit in collection until their color's realm unlocks. This means pulling a Druid on D1 is not wasted — her bubble-weight kicks in the moment R3 starts.

| Realm | Colors in cluster | Classes spawnable from bubbles |
|---|---|---|
| R1 | Red, Blue, Yellow | Fire Knight, Ice Mage, Archer |
| R2 | Red, Blue, Yellow | (same) |
| R3 | + Green | + Druid |
| R4 | Red, Blue, Yellow, Green | (same as R3) |
| R5 | + Purple | + Wizard |

#### 3.10.4 Enemy scaling per realm

Enemies scale on HP / damage / speed / attack-rate. Speed is capped to preserve drag-reposition readability.

```
enemy_hp     = base_hp_color   × realm_mult_hp   × stage_mult
enemy_damage = base_dmg_color  × realm_mult_dmg  × stage_mult
enemy_speed  = base_speed_color × realm_mult_speed
enemy_atk_rate = base_atk_rate × realm_mult_atkrate
```

**Realm multipliers:**

| Realm | HP × | DMG × | Speed × | Attack rate × |
|---|---|---|---|---|
| R1 | 1.00 | 1.00 | 1.00 | 1.00 |
| R2 | 1.35 | 1.35 | 1.10 | 1.10 |
| R3 | 1.80 | 1.80 | 1.20 | 1.15 |
| R4 | 2.40 | 2.40 | 1.30 | 1.20 |
| R5 | 3.20 | 3.20 | 1.40 | 1.30 |

**Stage multipliers within realm (S1 → S5):** 1.00 / 1.10 / 1.20 / 1.35 / 1.50 (boss).

**Worked example:** R5S5 Red walker HP = 50 × 3.20 × 1.50 = **240**. Speed = 1.0 × 1.40 = **1.40 s/cell** (vs R1 = 1.0 s/cell — 40% slower march, more readable than doubling).

**Boss scaling:** Bosses get **+50% HP on top of the realm multiplier** (so R5 boss = 1000 × 3.20 × 1.50 = 4,800 HP) — they're meant to be the headline check on whether the player has built well. Damage scales 1:1 with realm multiplier.

#### 3.10.5 Enemy roster expansion per realm

Mix of new mechanical variants AND scaled walkers (per Shikha's call: "both"). New variant per realm so realms have *identity*, not just bigger numbers.

| Realm | New enemy variant | Mechanic |
|---|---|---|
| R1 | Walker / Runner / Brute / Boss | (v1 baseline) |
| R2 | **Shielder** | Blocks first 2 hits (forces sustained DPS over burst) |
| R3 | **Healer** | Heals nearest enemy +5 HP/sec; priority kill target |
| R4 | **Accelerator** | Triggers mid-wave speed-up (+50% speed for 5 s) on death |
| R5 | **Phaser** | Skips one row at random — disrupts Archer column targeting |

Each variant: max 1-2 per scripted wave, introduced at S3+ of its realm to give R-S1/S2 ramp room.

#### 3.10.6 Hero scaling — level curve

Hero level scales **base stats only**, applied BEFORE tier and modifiers. Range, attack speed, and special abilities **do not scale** (class identity preserved).

```
final_hp  = base_hp_class  × tier_mult × level_mult
final_dmg = base_dmg_class × tier_mult × level_mult × color_counter × (1 + frenzy_bonus + boon_bonus)
final_AS  = base_AS_class           (unchanged)
final_range = base_range_class      (unchanged)
final_special_pct = base_special_pct (unchanged)
```

**Level multiplier curve (L1 → L30):**

| Level | Stat × | Cumulative shards | Expected day-to-reach (median F2P) |
|---|---|---|---|
| L1 | 1.00 | 0 (unlock) | D0 |
| L5 | 1.15 | 50 | D2-3 |
| L10 | 1.35 | 200 | D7 |
| L15 | 1.60 | 500 | D14 |
| L20 | 1.85 | 950 | D21 |
| L25 | 2.15 | 1,500 | D28 |
| L30 | 2.50 | 2,200 | D45+ |

**Why this shape:** Gentle early so first-week leveling feels good. Steeper late so L30 is a long-tail goal. L30 = 2.5× base — meaningful but not roster-breaking.

#### 3.10.7 Tier multipliers (locked from v1)

Tier is in-run only; multipliers stack with level on top of class base.

| Tier | HP × | DMG × |
|---|---|---|
| Bronze | 1.0 | 1.0 |
| Silver | 1.5 | 2.0 |
| Gold | 2.0 | 3.0 |

#### 3.10.8 Modifier stacking — additive mix

Color counter stays **multiplicative** (it's the class-identity pillar). Frenzy and boon damage add to each other as a single combined bonus. This avoids stacking modifiers exploding combat-modifier multipliers in late realms.

```
combat_modifier_bonus = 1.0 + frenzy_bonus + boon_bonus
                      (e.g. 1.0 + 0.5 + 0.25 = 1.75×, not 1.5 × 1.25 = 1.875×)
final_dmg = base_dmg × tier_mult × level_mult × color_counter × combat_modifier_bonus
```

| Source | Value | Stacking behavior |
|---|---|---|
| Color counter (same-color hero vs enemy) | 2.0× | **Multiplicative** with everything |
| Color frenzy (cleared a colour in P1) | +0.5 (additive) | Adds to combat_modifier_bonus |
| Class-damage boon (e.g. +25% Red) | +0.25 (additive) | Adds to combat_modifier_bonus |
| Future modifiers (synergy boons, gear if ever added) | +X (additive) | All additive into the combined bonus |

**Worst-case stacked bonus at v1 modifier set:** 1.0 + 0.5 + 0.25 = 1.75× (vs 1.875× under pure multiplicative). Looks like a tiny delta now but **becomes load-bearing once we add synergy boons in §4.2.B** — additive math keeps the modifier ceiling sane as we add new boons.

#### 3.10.9 Worked DPS examples across the curve

End-to-end sanity check: same Fire Knight at different points in the player's life.

| Snapshot | Tier | Level | Modifiers | HP | DMG/hit | DPS (0.75s AS, 1.25× cleave) |
|---|---|---|---|---|---|---|
| **D0 R1S1** | Bronze | L1 | None | 100 | 10 | 17 |
| **D3 R2S3 vs Red** | Bronze | L5 | counter | 115 | 23 | 38 |
| **D7 R3S3 vs Red** | Silver | L10 | counter + frenzy | 203 | 81 | 135 |
| **D14 R4S3 vs Red** | Silver | L15 | counter + frenzy + boon | 240 | 105 | 175 |
| **D21 R5S3 vs Red** | Gold | L20 | counter + frenzy + boon | 370 | 208 | 347 |
| **D45 R5S5 vs Boss** | Gold | L30 | frenzy + boon (boss = no counter) | 500 | 263 | 438 |

**Boss-fight sanity:** D45 R5S5 boss has 4,800 HP. 4 maxed Gold L30 heroes ≈ 1,750 DPS. Kill time ≈ **2.7 s of clean uptime**. Realistic with scripted-wave interference (Runners, Brutes splitting hero attention): 6-10 s. **Feels like a boss, not a slog.**

**Early-game sanity:** D3 R2S3 Red walker has 81 HP. Bronze L5 Fire Knight at 23 DMG/hit kills it in 4 hits = 3 s. **Reasonable for an early-stage walker.**

#### 3.10.10 Open questions deferred to balance pass

- **OQ16:** Should Brute / Runner variants get realm-scaled stat deltas independent of base walker scaling? (Default: no — they're already differentiated. Revisit if mid-realm waves feel one-note.)
- **OQ17:** ~~Cluster descent rate scaling~~ — **Closed.** Cluster descent removed (see 2026-05-14 change log entry). Hero-bubble exhaustion is the primary P1 end trigger.
- **OQ18:** Does color frenzy bonus scale with realm (e.g. R5 frenzy = +75%)? (Default: hold at +50% across all realms — keeps the math predictable and additive.)
- **OQ19:** Hero-shard drop rates per stage at the chapter map level — defer to economy pass (§4.5).

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

41 boons total across 7 categories. 3 drawn without replacement per stage clear. 4 picks per 5-stage run = ~10% pool coverage — variety is wide, repeats per run rare. Green/Purple class boons are **realm-gated**: only enter the draw pool once that class has been seen in cluster (R3+ Green, R5+ Purple). v1 R1 prototype pool = 28 boons (R/B/Y only).

**A. Color Bias (3) — cluster RNG, full run**

| Boon | Effect | Notes |
|---|---|---|
| Red Bias | +30% chance next bubble is Red | Color-focus play |
| Blue Bias | +30% chance next bubble is Blue | Color-focus play |
| Yellow Bias | +30% chance next bubble is Yellow | Color-focus play |

**B. Cannon — Move Budget (3) — next stage only**

| Boon | Effect | Notes |
|---|---|---|
| Extra Moves +2 | Next stage cannon gets +2 to move budget | Light Phase 1 generosity |
| Extra Moves +3 | Next stage cannon gets +3 to move budget | Medium generosity |
| Extra Moves +5 | Next stage cannon gets +5 to move budget | Big swing — for hard stages |

**C. Cannon — Super Ball (2) — next stage only**

| Boon | Effect | Notes |
|---|---|---|
| Super Ball ×1 | Next stage cannon queue includes 1 super ball that pops any color (and any hero bubble) on contact | Universal pop — bypasses match-3 rule |
| Super Ball ×3 | Next stage cannon queue includes 3 super balls | Stronger version — cleanup on awkward clusters |

**D. Cannon HP — Max + Heal (4) — persistent for run**

| Boon | Effect | Notes |
|---|---|---|
| Cannon HP +25 (max) | Increase cannon max HP by 25 for the rest of the run; heals to new max | Defensive — survive boss leaks |
| Cannon HP +50 (max) | Increase cannon max HP by 50 for the rest of the run; heals to new max | Big defensive swing |
| Heal Cannon +25 | Instantly restore 25 cannon HP (cap at max) | Bandage — late-stage rescue |
| Heal Cannon Full | Restore cannon HP to max | Reset button before boss |

**E. Cluster Density + Tier Promote (3 + 1) — next stage or immediate**

| Boon | Effect | Notes |
|---|---|---|
| Hero Bubble Density +50% | Next stage only — more hero bubbles in cluster | Roster-size lever |
| Bronze→Silver (mass) | Next stage, all freed heroes start one tier up | Existing v2 boon |
| Promote Random Hero | Immediately upgrade one random surviving hero by one tier (Bronze→Silver, Silver→Gold; Gold = re-roll) | Run-state interaction |
| Promote Best Hero | Immediately upgrade the hero with most damage dealt this run by one tier | Reward play pattern |

**F. Class-Specific Promote (5 — G/P realm-gated)**

| Boon | Effect | Notes |
|---|---|---|
| Promote a Red Hero | Upgrade one random surviving **Red** (Fire Knight) by one tier | Build-direction |
| Promote a Blue Hero | Upgrade one random surviving **Blue** (Ice Mage) by one tier | Build-direction |
| Promote a Yellow Hero | Upgrade one random surviving **Yellow** (Archer) by one tier | Build-direction |
| Promote a Green Hero | Upgrade one random surviving **Green** (Druid) by one tier | R3+ only |
| Promote a Purple Hero | Upgrade one random surviving **Purple** (Wizard) by one tier | R5+ only |

**G. Class Damage — Percentage (5 — G/P realm-gated)**

| Boon | Effect | Notes |
|---|---|---|
| Damage +25% (Red) | All Red heroes deal +25% damage for the run | Existing |
| Damage +25% (Blue) | All Blue heroes deal +25% damage for the run | Existing |
| Damage +25% (Yellow) | All Yellow heroes deal +25% damage for the run | Existing |
| Damage +25% (Green) | All Green heroes deal +25% damage for the run | R3+ only |
| Damage +25% (Purple) | All Purple heroes deal +25% damage for the run | R5+ only |

**H. Class Damage — Flat (15 — G/P realm-gated)**

Flat damage adds onto `base_dmg_class` before all multipliers. Base damage is 10 across R/B/Y in v1 — flat tiers are sized 50% / 100% / 200% of base for clear feel separation.

| Boon | Effect |
|---|---|
| +5 dmg per Red hero attack | Flat damage add for the run |
| +10 dmg per Red hero attack | Flat damage add for the run |
| +20 dmg per Red hero attack | Flat damage add for the run |
| +5 / +10 / +20 dmg per Blue hero attack | Three Blue flat tiers (R3+ for Green/Purple equivalents) |
| +5 / +10 / +20 dmg per Yellow hero attack | Three Yellow flat tiers |
| +5 / +10 / +20 dmg per Green hero attack | R3+ only |
| +5 / +10 / +20 dmg per Purple hero attack | R5+ only |

**I. Synergy (1)**

| Boon | Effect | Notes |
|---|---|---|
| **Color Affinity** | If you have any Color Bias active, that color's bubbles also have +20% chance to be hero bubbles | Build-craft test boon |

**Stacking note (cross-ref §3.10):** Flat damage adds happen pre-multiplier (into `base_dmg_class`). Percentage damage stays additive into `combat_modifier_bonus` alongside frenzy. Color counter stays multiplicative. The math ceiling is unchanged at the modifier layer — flat scaling lives one tier deeper.

### 4.3 Progression curve (within a run)

| Stage | Cluster | Move budget | Wave composition | New element | Difficulty intent |
|---|---|---|---|---|---|
| 1 | 5 × 4 | 10 | 5 Red walkers | Red only — tutorial pace | "Easy win" — learn aim + hero-bubble pop + Phase 2 dragging |
| 2 | 5 × 5 | 12 | 4 R + 2 B | + Blue introduced | "First color-mix wave" |
| 3 | 5 × 5 | 12 | 4 R + 3 B + 2 Y + 1 Runner | + Yellow + Runner variant | "Three-color juggle, drag matters more" |
| 4 | 6 × 6 | 14 | 5 R + 3 B + 3 Y + 1 Runner + 1 Brute | + Brute | "Tighter cluster + Brute — fewer wasted shots" |
| 5 (boss) | 6 × 7 | 16 | 6 R + 4 B + 4 Y + 2 Runners + 2 Brutes + Boss | + Boss | "All systems at once: race the hero-bubble burst, fielded army + drag timing carries Phase 2" |

**Tuning intent:** Stages 1-3 teach mechanics one at a time. Stage 4 tightens the cluster so more shots are spent drilling to hero bubbles. Stage 5 stress-tests with the boss after a full walker wave.

### 4.4 Meta progression (spec-only, NOT built in v1)

> **Stance.** Pop Brigade's meta spine is lifted **wholesale from Slime Legion** with two deliberate bends: (a) the in-run tier ladder (Bronze/Silver/Gold) and the merge mechanic carry the depth that Slime Legion gets from gear; (b) the gacha-to-bubble-pool link (§4.4.6) is the distinctive monetization shelf. Everything else is genre-standard Habby/Slime-Legion shape.
>
> **Design rule.** **One identity track per hero** (level). **One permanent cannon track.** **Three currencies max** (gems / coins / per-hero shards). **One chapter spine.** If a proposed system doesn't fit one of these slots, it doesn't ship.

#### 4.4.1 Hero progression — the identity track

**Lifted from Slime Legion. Bent so class identity (range/AS) stays intact across levels.**

| Field | Spec |
|---|---|
| Hero level range | 1–30 |
| Stats that scale with level | **HP (+linear), base damage (+linear)** |
| Stats that DON'T scale | **Range, attack speed, special ability** — these are class identity; do not touch |
| Level cost | **X hero shards (specific to that hero) + Y Pop Coins** |
| Shard sources | (1) chest pulls — dupes convert to shards (2) stage drops on chapter map (3) event-targeted drops (4) battle pass rewards |
| Shard curve (rough) | L1→2: 5 shards. L5→6: 30. L10→11: 80. L20→21: 200. L30 cap: ~2,200 cumulative |
| Coin curve | Scales 1:1 with shard count, roughly 200× (so L30 ≈ 440k coins) |
| Interaction with in-run tier | Hero level adds **flat HP + flat damage** on top of whatever tier the hero spawns/merges into. A level-10 Bronze Fire Knight is stronger than a level-1 Bronze Fire Knight. **In-run tier multiplier still applies on top.** |

**Bend from Slime Legion:** Slime Legion scales all 4 stats (HP, dmg, AS, range). Pop Brigade scales only HP + dmg because **range and attack speed ARE the class** — a leveled Archer is still a long-range slow-shooter; a leveled Fire Knight is still a short-range tank. Don't let levels homogenize the roster.

#### 4.4.2 Currencies

**Three currencies. No more.**

| Currency | Type | Source | Sink |
|---|---|---|---|
| **Pop Coins** | Soft | Stage drops (every clear), missions, BP free track, ad rewards, chest reward | Hero levels (with shards), cannon mastery (§4.4.5) |
| **Gems** | Hard | IAP, missions, BP premium track, login calendar, achievements | Chests, energy refill, revive, coin packs |
| **Hero shards** (per-hero) | Soft, hero-specific | Chest dupes, stage drops on chapter map, events, BP | Hero levels (with coins) |

**Explicitly NOT in the economy:** gear, runes, talents, gear-shards, hero XP (separate from shards), refining materials, account XP, dust, fragments, tokens. If we feel a depth gap post-launch, the answer is **chapter map expansion or hero roster expansion**, not currency proliferation.

#### 4.4.3 Chests (gacha)

**Lifted from Slime Legion. Bent to integrate with the bubble-pool weighting (§4.4.6).**

| Field | Spec |
|---|---|
| Hero roster at launch | **40 heroes** (8 per color, 5 colors) — revised up from 25; ascension-less depth needs roster breadth |
| Rarities | 3: Common / Rare / Epic (drop rates 70 / 25 / 5) |
| Chest types | (1) **Basic chest** — 1 hero pull, 200 coins, ad-watch daily free + buyable with coins (2) **Premium chest** — 1 hero pull, 1k coins, weighted toward Rare+ — buyable with gems (3) **Premium 10-pull** — 10 pulls, 1 guaranteed Rare+, ~10% discount |
| Pity | Soft pity from pull 60, hard pity (guaranteed Epic) at pull 80 — premium chest only |
| Dupes | New hero = shards-toward-unlock floor (50 shards); after unlock, dupes convert to that hero's shard pool at 1:5 (1 dupe = 5 shards) |
| Event chests | Themed weekly chests that **weight one color heavier** + **drop targeted hero shards** for a featured hero from that color |

**Why 40 not 25:** No ascension means breadth IS the depth. Slime Legion ships ~50; Lucky Defense ~45; Wittle Defender ~40+. 25 makes pity feel pointless by week 2.

#### 4.4.4 Chapter map (the missing D2–D30 spine)

**This is the system v1's review flagged as the biggest gap. Lock the shape now even if content lands incrementally.**

| Field | Spec |
|---|---|
| Structure | **Realms → Stages.** 5 realms at launch. Each realm = 5 stages + 1 boss (matches v1 run arc). |
| Realm gimmick | One mechanical twist per realm (e.g. R1 vanilla / R2 cluster shake / R3 color lock / R4 enemy speed-up mid-stage / R5 boss gauntlet) |
| Star system | 0–3 stars per stage based on (cleared / HP remaining / move budget unused). Stars unlock realm-completion rewards. |
| Shard rotation | **Each realm drops shards for a different hero pool** (R1 → Red pool, R2 → Blue, etc.). This is the free-play path to specific heroes — answers "how do I level the hero I want without pulling for them." |
| Replay | Stages replayable. Shard drop rates per stage decay after first 3-star clear (caps farming, pushes new-content consumption). |
| Energy gate | 1 energy per stage attempt. Replay-grinding costs energy → gem-refill pressure. |
| Content cadence | Add 1 realm every 4–6 weeks post-launch. Realm 6+ at higher level cap (raise to L40 then L50). |

**Why this structure not "endless mode":** Casual female-skew players in this comp set want **completion-shaped goals** (Slime Legion chapters, Wittle Defender stages, Capybara Go zones). Endless modes are a *bonus* surface, not the spine.

#### 4.4.5 Cannon mastery (the permanent cannon track)

**One track. No damage scaling.**

| Mastery node | Cost (Pop Coins, cumulative) | Effect |
|---|---|---|
| L1 → L5 | 5k each step | +1 move budget per L5 (so L5 = +1 move on every stage, L10 = +2, capped at +5) |
| L1 → L10 (parallel) | 8k each step | +1 special-bubble capacity per L5 (e.g. L5 = +1 color bomb slot) |
| L1 → L5 (parallel) | 20k each step | +1 boon pick choice (3-of-3 → 4-of-3 at L5) |

**Bend from Slime Legion (and from the original v2 sketch):** **No damage / fire-rate cannon upgrades.** Damage scaling already lives in hero levels (long-term) + run boons (short-term). A third damage knob collapses the boon decision. Cannon mastery owns **moves, capacity, choice** — three things heroes and boons can't touch.

#### 4.4.6 Bubble-pool weighting — the distinctive monetization shelf

**Pop Brigade's only true meta differentiator. Lock into v1 playtest, not v2.**

| Field | Spec |
|---|---|
| Rule | Hero bubbles in-cluster draw from your **owned + leveled** hero pool. Higher-level heroes appear more often. |
| Weight formula | `weight(hero) = 1 + (hero_level × 0.5)` if owned; 0 if unowned. Normalize across owned roster. |
| Unowned-class fallback | If a color has zero owned heroes, weight reverts to flat across that color's default v1 hero (so new players never see empty bubbles) |
| Bubble bias from gacha | Newly-pulled heroes get a **2× weight multiplier for 7 days** ("featured" feel) |
| Player visibility | The hero portrait on the bubble shows **which hero will pop out**. This is the readable causal link between gacha spend and run feel. |
| v1 playtest variant | Even in greybox: give tester a pre-pull moment ("here's your starter Fire Knight, here's Ice Mage from the gacha demo"); confirm in debrief they notice their pulled heroes showing up |

**Why this matters:** Every other meta surface in this spec is genre-standard. This one is what gives Pop Brigade a reason to exist commercially — the visible feedback loop from "I pulled this hero" → "I see her in my runs" → "I level her up" → "she shows up more." It IS the monetization shelf. If it doesn't read in playtest, kill it before soft launch.

#### 4.4.7 Monetization surfaces

**All standard Habby/Slime Legion shape except (D) and (G).**

| # | Surface | Mechanic | Currency |
|---|---|---|---|
| A | **Energy** | 5 max, regen 1 per 30 min, refill via gems. 1 stage = 1 energy. | Gems → energy |
| B | **Revive** | On stage fail in Phase 2: continue with 50% HP. **Watch ad OR pay gems.** No $0.99 paywall. | Ad / gems |
| C | **Extra Moves continue (first $4.99 moment)** | Phase 1 budget hits 0 with cluster ≥50% full: pay gems for +3 moves. | Gems |
| D | **Starter hero pack ($4.99 one-time)** | 10 premium chest pulls + guaranteed Rare hero from a closed starter pool. Triggers after run 3. | IAP |
| E | **Battle pass (seasonal, $5–10)** | 60 levels. Free track: coins, common shards. Premium track: skins, premium chests, gems, targeted hero shards. | IAP |
| F | **Daily/weekly missions** | Daily: 4 missions, reset 00:00 local. Weekly: 6 missions. Reward: gems + coins + chest tickets. | Free |
| G | **Color-themed events (weekly)** | "Red Week" — bonus shards for Red heroes, color-locked event stages, color-weighted event chests. Drives focused gacha pity. | Free + IAP |
| H | **Login calendar** | 7-day rotating + 28-day monthly. Day 7 = premium chest. Day 28 = guaranteed Epic hero. | Free |
| I | **Ad rewards** | (1) Revive (B) (2) 2× end-of-run rewards (3) Free daily basic chest (4) Free 30-min energy refill (cap 3/day) | Ad |
| J | **Achievements ("Bubble Atlas")** | Lifetime track: pops, frenzies, merges, heroes-collected, realms-cleared. One-time gem rewards per milestone. | Free |

**Things explicitly OUT of the launch monetization plan:** subscription / VIP system, lootbox stacking discounts, time-limited "summon-only" heroes that vanish forever, $99.99 mega-packs day 1, banner-style limited rate-ups that lock players out of the standard pool. These can come later if economy underperforms — they're easy to add, brutal to remove without backlash.

#### 4.4.8 First-30-day pacing (player journey)

**The shape we want testers + soft-launch cohorts to actually experience.**

| Day | Player has access to | Gating intent |
|---|---|---|
| **D0 (FTUE)** | 1 starter hero (Red Fire Knight). Realm 1 unlocked. Energy uncapped for first 3 runs. No chests, no shop yet. | Pure mechanic learning — no economy noise |
| **D1** | Energy ON (5 cap). First chest unlocked after run 4. Basic missions unlocked. | Introduce the loop: play → earn → spend on chest → see new hero in bubbles |
| **D2–D3** | Premium chest unlocked. Realm 2 unlocked at stage-5 clear. First battle pass season visible. | "Build a roster" feel kicks in. Bubble-pool weighting becomes visible. |
| **D4–D7** | Cannon mastery unlocked. First event week. Starter pack offer fires after run 12. | First real spend decision. Targeted shard farming becomes available. |
| **D8–D14** | Realms 3–4 unlocked progressively. First hero hits level 10 → "level cap pressure" begins. | "Level a main vs spread" decision surfaces. |
| **D15–D30** | Realm 5 unlocked. Battle pass season climax. First "build a second hero" identity moment for whales. | The whale identity track shape becomes visible — but completionist F2P can also feel a complete arc. |
| **D30+** | New realm cadence kicks in. Hero L30 unlocked. Achievements long-tail. | Game has more to play than a 30-day commitment requires. |

**Two retention bets in this pacing:**
1. **D2 hook = "the hero I pulled showed up in my bubble."** If that doesn't read, D2 dies regardless of any other system.
2. **D7 hook = "I unlocked Realm 3 with a different boss gimmick."** Chapter cadence is the spine. Without realm 2/3 distinctness, D7 dies.

#### 4.4.9 What this meta is NOT trying to do (anti-goals)

- **Not a city-builder / base-builder.** Even though the CEO's pedigree is SLG, the core loop is action — meta should support runs, not compete with them.
- **Not a PvP-first economy.** PvP can come as a side mode (arena ladder, post-launch) but the core economy must work entirely on PvE.
- **Not a "limited heroes vanish forever" gacha.** All heroes remain in the pool; events bias rates, never lock out.
- **Not a deep gear/rune meta.** That ceiling belongs to a later expansion (or to the next game) — not v1 launch.

---

### 4.5 First $4.99 moment — design intent (carried from prior spec)

When Phase 1 budget hits 0 with cluster ≥50% full, offer: **+3 moves for X gems** (or $4.99 first-time direct-buy). Players will be deep into a stage when this fires; the offer attacks a specific frustration ("I almost had it") rather than a baseline gate. **First-time gem price discounted 50%** to create a starter-IAP funnel; subsequent uses charge full price.

This is the **panic-buy** lane in the monetization plan. The **aspiration-buy** lane is the starter hero pack (§4.4.7 D). Both need to exist; neither alone is enough.

---

## Section 5 — Content scope for v1

### 5.1 Content lock list

| Category | v1 count | Items |
|---|---|---|
| **Stages** | 5 | S1 (intro), S2 (Blue), S3 (Yellow + Runner), S4 (Brute), S5 (boss) |
| **Hero classes** | 3 | Red (Fire Knight), Blue (Ice Mage), Yellow (Archer) |
| **Hero tiers** | 3 | Bronze, Silver, Gold |
| **Enemy types** | 3 | Red walker, Blue walker, Yellow walker |
| **Enemy variants** | 3 | Walker (default), Runner (stage 3+), Brute (stage 4+) |
| **Bosses** | 1 | Purple "Sludge Lord" — placeholder. Spawns after the last walker dies. |
| **Special bubbles** | 1 | Color bomb |
| **Boons** | 41 (28 in v1 R1 pool) | See §4.2 (7 categories incl. 1 synergy boon; G/P boons realm-gated) |
| **Cannon variants** | 3 | Red-bias, Blue-bias, Yellow-bias (loadout) |
| **Cluster patterns** | 3 | One per starting-row tier (4-row, 5-row, 7-row) |
| **VFX states** | ~10 | Pop, hero-bubble pop (face-burst), falling, hero spawn, hero attack, hero death, hero drag-lift, enemy hit, enemy death, color frenzy, "ARMY READY" transition beat, cluster-sweep on transition |
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

### 5.3 Build state (current)

R1 fully specced (§4.3, §8.2). Greybox playable in `godot-prototype/` per §3.9. Hypothesis test (§6) runs on R1 only and gates the broader content build. R1 hypothesis test pass = green-light to proceed to Phase 2 (§9). Q1 fail = pause and rework.

---

## Section 6 — Test hypothesis + instrumentation

### 6.1 The 4 questions → measurable signals

**Question priority:** Q1 is the **existential** test (architecture lives or dies on it). Q2-Q4 are **tunable**.

| # | Question | Pass signal | Kill signal | Measurement |
|---|---|---|---|---|
| **Q1 (existential)** | Does build → defend read as one game — specifically, do players experience Phase 1 as recruiting the army Phase 2 fights with? | Tester describes: "the heroes I freed are the ones that fought" or equivalent. Can predict "if I free more heroes / higher-tier heroes, Phase 2 is easier" correctly at debrief. | Tester describes two disjoint experiences; treats the Phase 2 wave as unrelated to their P1 play | Verbal debrief Q1, Q9; transcribed and tagged |
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
| `color_frenzy_trigger` | `{ color, heroes_at_trigger_count }` | Each full color clear in P1 |
| `phase1_end` | `{ stage_num, ms_elapsed, reason: "hero_bubbles_exhausted" \| "budget_exhausted" \| "cluster_cleared" \| "time_cap", moves_used, moves_remaining, hero_bubbles_remaining, bubbles_swept, heroes_built_total, max_chain, frenzied_colors }` | P1 → P2 transition |
| `phase2_start` | `{ stage_num, hero_count, hero_composition, scripted_wave_size }` | P2 begin (after wipe) |
| `enemy_spawn` | `{ enemy_id, color, lane_col, variant, source: "wave_script" \| "boss_drop" }` | Each enemy on lane |
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
- **Hero-bubble burst completion** = hero_bubbles_bursted / hero_bubbles_seeded per stage (target: ≥80% by stage 3 — confirms the race trigger is reachable)
- **Phase 1 end reason distribution** = share of P1 ends by `hero_bubbles_exhausted` vs `budget_exhausted` vs `cluster_cleared` vs `time_cap` (target: hero_bubbles_exhausted dominant on stages 1-2, mix by stage 4-5 — diagnostic for pacing tightness)
- **Moves remaining when P1 ended via hero exhaustion** — if consistently ≥4 across testers, hero bubbles are too easy to reach; if consistently ≤1, the race is too tight
- **Drag count per Phase 2** = drag_count / stages played (target: 2-4/stage; 0 or 10+ flags a problem)
- **Merge rate** = merges / stage; **merge intent share** = merge-resolution drags / total P2 drags (target: ≥20% of P2 drags resolve as merges by stage 3 — confirms players grasp the mechanic)
- **Tier composition at P2 end** = ratio of Bronze:Silver:Gold surviving (correlate with merge rate — high merge rate should shift composition toward Silver/Gold)
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
9. "What did your shots in Phase 1 control? What were you trying to achieve before the wave came?" → **Q1 causal-chain probe** (if they don't describe freeing heroes / preparing the army, Q1 fails)
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
| **Fail** | Any | Any | Any | **Recruit-arc failed** — testers don't experience Phase 1 as building the army they'll fight with. Rework hero-bubble salience (bigger portraits, "ARMY READY" beat at transition that lingers on the heroes you freed). Re-test. |

**Bar:** 5/8 testers pass Q1 for the architecture to live.

---

## Section 7 — Open questions & risks

### 7.1 Open questions

| # | Question | When to answer |
|---|---|---|
| OQ1 | Move budget tuning: 10 / 12 / 12 / 14 / 16 (current v1) vs 10 / 11 / 13 / 14 / 16 (concept) vs tighter (-2 each) — measured against hero-bubble exhaustion completion | W1 internal play |
| OQ2 | Phase transition wipe: 1 s "GET READY!" vs longer "ARMY READY" beat that lingers on the heroes just freed | W2 internal play — longer wipe might help Q1 recruit-arc read |
| OQ3 | Hero-bubble count distribution per stage — current weighted 1-4 with stage 1 floor 2; alternatives: fixed 3, scaling with stage, or tying count to cluster size | W3 — confirm at greybox |
| OQ4 | (removed — cluster descent disabled) | — |
| OQ5 | (removed — boss cluster shake removed) | — |
| OQ6 | Color frenzy duration: full wave (design intent) vs current 10 s vs 3 enemy kills | W2 internal play |
| OQ7 | Drag affordance — column highlight follows finger continuously, or only snap to discrete columns? | W2 |
| OQ8 | Greybox readability — does no-art produce valid signal for Q1 specifically? | After tester 2-3 |
| OQ9 | One synergy boon (Color Affinity) — is one enough, or do we need 2-3 to test build-craft? | After tester 3-4 |
| OQ10 | "ARMY READY" lingering beat after the wipe — show the heroes freed in P1 lined up before the wave spawns, vs straight cut to combat | W3 |
| OQ11 | Carry-over HP — preserved exactly, or partial heal (e.g., +20 HP between stages)? Current: exact preserve. | After tester 2-3 |
| OQ12 | **Merge HP rule** — full new-tier HP (current spec) vs sum-of-HPs vs higher-HP-source. Full reset is cleanest but punishes merging damaged heroes; sum-of-HPs rewards merging early. | After tester 2-3 |
| OQ13 | **Merge readability** — is drag-to-merge legible without a tutorial prompt? Tester reaction when they accidentally merge will tell us. If <50% of testers grasp it within stage 2, add a one-time hint on first matching-pair spawn. | After tester 2-3 |
| OQ14 | **Should mass-merge cascade?** If a Silver merges with another Silver into Gold, and a third Silver is adjacent — does the resulting Gold immediately become available to merge? v1: no — each merge is a discrete drag (or discrete P1 spawn event). | W3 |

### 7.2 Risks (and mitigations)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Players don't experience Phase 1 as recruiting (Q1 fails)** | Medium | **Existential** | Pre-test: design the transition to spotlight the freed heroes. "ARMY READY" beat at wipe end. Hero portraits scale up briefly before the wave starts. If Q1 still fails, rework transition staging. |
| **Hero bubbles run out too fast — Phase 1 feels truncated** | Medium-High | Phase 1 too short / shallow | Tune `hero_bubble_count_weights` upward; if testers consistently end P1 with ≥4 moves remaining via hero exhaustion, shift the count distribution toward 3-4 per stage. |
| **Move budget feels too tight (testers run out before freeing all hero bubbles)** | Medium | Phase 1 frustration | Have +2 budget pre-tuned per stage; swap in if hero-bubble burst completion <70% on stage 1. |
| **Move budget feels too generous (testers always free every hero with shots to spare)** | Medium | Phase 1 boring | Have -2 budget pre-tuned; check the moves-remaining-on-hero-exhaustion metric. |
| **Hero dragging is unused / pointless** | Medium | Q3 fails | First lever: spawn heroes in unhelpful columns more often (force drag). Second lever: position-bonus boons (heroes deal +10% in adjacent-color column). |
| **Greybox confuses testers** | Medium | Q1/Q4 polluted | Pre-test: 1-2 friendly internal testers in W4. If "no art" dominates, recruit one artist for v1.1 hero-portrait pass before external test. |
| **4-week build slips** | Medium | Pushes tester window | Cut scope: drop Brute variant (only Walkers + Runners), drop synergy boon (Color Affinity). Test stays valid. |
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

---

## Section 8 — Realm content build (R1 → R5)

> **Scope.** This section specs the playable content of all 5 launch realms — stage layouts, wave compositions, realm gimmicks, new enemies, new classes, boss designs. v1 ships **R1 only**; R2-R5 are designed to a fidelity tight enough that an engineer + designer pair can build each realm in ~1.5-4 weeks once R1 ships clean. Numbers reference scaling tables in §3.10.

### 8.1 Realm map at a glance

| Realm | Theme / fantasy | Gimmick | Class added | New enemy variant | Boss |
|---|---|---|---|---|---|
| **R1 — Skyline** | Floating sky island, cloud cluster | — (baseline) | (R/B/Y baseline) | (Walker / Runner / Brute) | **Sludge Lord** |
| **R2 — Storm Reach** | Thunderhead spire, lightning sky | Cluster shake on S3-S5 | — | **Shielder** | **Storm Tyrant** |
| **R3 — Verdant Maze** | Overgrown jungle ruin, vines | Vine-locked cluster rows | **+ Green (Druid)** | **Healer** | **Verdant Warden** |
| **R4 — Falling Spire** | Crumbling tower, descent | Cluster descent on ALL stages | — | **Accelerator** | **Spire Ravager** |
| **R5 — Voidcrown** | Cosmic void, twin moons | Two-boss finale (S3 mini-boss + S5 boss) | **+ Purple (Wizard)** | **Phaser** | **Voidcrown Twins** |

Each realm = 5 stages + boss. Total launch content: **25 stages, 5 bosses, 5 classes, 7 enemy variants.**

### 8.2 Realm 1 — Skyline (v1, locked)

Full spec in §4.3 and §3.9. Summary for reference:

| Stage | Cluster | Moves | Wave | Intent |
|---|---|---|---|---|
| S1 | 5×4 | 10 | 5R | Tutorial — Phase 1/2 split, hero-bubble pop |
| S2 | 5×5 | 12 | 4R + 2B | First color mix |
| S3 | 5×5 | 12 | 4R + 3B + 2Y + 1 Runner | Three-color juggle |
| S4 | 6×6 | 14 | 5R + 3B + 3Y + 1 Runner + 1 Brute | Tighter cluster, fewer wasted shots |
| S5 (Sludge Lord) | 6×7 | 16 | 6R + 4B + 4Y + 2 Runners + 2 Brutes + Boss | Boss check — all systems |

**Boss — Sludge Lord:** HP 1000 (no realm mult, R1 baseline × 1.5 boss = 1500). Spawns after the last walker dies. Pure throughput test, no extra P2 mechanic.

### 8.3 Realm 2 — Storm Reach

**Intent:** First scaling test. Same class roster as R1 — players have nothing new to learn except harder math + Shielder + cluster shake earlier. Validates that the *core loop scales* before we add classes.

**Gimmick — early cluster shake (S3-S5):** Cluster drops 1 row every 18 s during Phase 1. Forces the player to find hero-bubble pop angles faster — descent is purely time pressure on the recruit race (cluster reaching row 0 has no separate punishment now that leftover-becomes-enemy is gone; if it ever did, P1 would simply end on time-cap).
> **R2+ note:** cluster shake is a Realm 2+ scaling mechanic, layered on top of the R1 hero-bubble-exhaustion race. R1 still ships without shake or descent (see §3.2 and §8.2).

**New enemy — Shielder:**
- Wears a colored shield matching its color. First 2 hits remove the shield (with a "ping" SFX + shield-shatter VFX); 3rd hit onward damages HP.
- HP under shield: 60 (Red base × R2 mult). Damage: 12. Speed: 1.1.
- **Design intent:** disrupts burst-down strategy. Player can't one-shot Shielders with a Gold Archer — must commit sustained damage. Pulls value back into Bronze/Silver heroes that can chip.

**Stage table:**

| Stage | Cluster | Moves | Wave (in spawn order) | New element | Intent |
|---|---|---|---|---|---|
| S1 | 5×5 | 12 | 6R + 2B | (R2 baseline HP/DMG) | Re-familiarize with harder R/B walkers |
| S2 | 5×6 | 13 | 5R + 3B + 1Y | Yellow rejoins | Mixed-color comfort |
| S3 | 6×6 + shake | 15 | 5R + 3B + 2Y + 1 Shielder (R) | + Shielder + cluster shake | Teach Shielder + new P1 pressure |
| S4 | 6×7 + shake | 17 | 6R + 4B + 3Y + 1 Shielder (B) + 1 Brute | Brute returns | Compound pressure |
| S5 (Storm Tyrant) | 6×8 + shake | 18 | 7R + 5B + 4Y + 2 Shielders + 2 Brutes + Boss | Boss | Storm Tyrant |

**Boss — Storm Tyrant:** HP 1000 × 1.35 × 1.5 = **2,025**. Damage on reach: 50 × 1.35 = 68. Color: Blue (Yellow heroes get counter).

**Boss mechanic — Electrified Column:**
- Every 8 s, the Tyrant marks a random hero column (2 s telegraph: lightning indicator above the column flashes).
- After telegraph, the column is "electrified" for 4 s: heroes in that column take 1.5× damage from enemy attacks while electrified.
- **Tactical response:** drag heroes OUT of the marked column during telegraph window. Tests the drag mechanic under time pressure.

### 8.4 Realm 3 — Verdant Maze

**Intent:** Roster expansion realm. Adds **Green (Druid)** as a playable class AND as an enemy color. The first realm where "your roster shapes the run" feels real — Druid plays fundamentally differently (heals other heroes).

**Gimmick — Vine-Locked Rows:**
- 1-2 random rows in the starting cluster are "vine-locked" (visual: bubbles wrapped in green vines).
- Vine-locked bubbles **cannot be popped by direct hits.** Cannon shots glance off (no damage, no move consumed if visually telegraphed; design call — could go either way).
- Two ways to unlock: (a) clear all bubbles in the row directly above OR below the locked row, OR (b) detonate any Color Bomb that hits the locked row.
- **Design intent:** introduces puzzle order — players must clear *around* before going through. Color Bomb usage becomes a strategic choice (use it to break a vine row).

**New class — Druid (Green):**

| Stat | Value | Notes |
|---|---|---|
| Base HP | 100 | Same as others |
| Base DMG | 9 (0.9× baseline) | Lower because of utility |
| Attack speed | 1.0 s | Mid-tempo |
| Range | 3 cells (mid) | Between Fire Knight (1) and Archer (full) |
| Special | **Chain heal** — every attack also heals the 2 nearest allied heroes +5 HP | Tank-support hybrid |
| Color counter | 2× vs Green enemies | Standard |

**New enemy — Healer:**
- Heals the nearest enemy +5 HP/sec. Visible green wisp particle indicator on enemy receiving the heal.
- HP: 70 (R3 mult applied). Damage: 8 (lowest in roster — it's a support unit). Speed: 1.0.
- **Tactical response:** kill Healer first OR isolate the healed enemy. Druid's color counter trivializes Healers (2× damage on counter), creating an elegant rock-paper-scissors moment.

**Stage table:**

| Stage | Cluster | Moves | Wave | New element | Intent |
|---|---|---|---|---|---|
| S1 | 5×6 (1 vine row) | 14 | 4R + 2B + 2G | + Green walker | Meet Green class & enemy |
| S2 | 6×6 (1 vine row) | 15 | 4R + 2B + 3G + 1Y | Green-heavy wave | Test Druid output |
| S3 | 6×7 (2 vine rows) | 17 | 5R + 3B + 3G + 1Y + 1 Healer | + Healer | Teach priority targeting |
| S4 | 6×7 (1 vine + shake) | 19 | 6R + 4B + 4G + 2Y + 1 Healer + 1 Shielder | Returning enemies | Compound complexity |
| S5 (Verdant Warden) | 6×8 (2 vines + shake) | 20 | 6R + 4B + 5G + 3Y + 2 Healers + Boss | Boss | Verdant Warden |

**Boss — Verdant Warden:** HP 1000 × 1.80 × 1.5 = **2,700**. Damage on reach: 50 × 1.80 = 90. Color: Green.

**Boss mechanic — Vine Roots:**
- Spawns 2 vine-root pillars on row 0 (occupy hero slots — heroes in those slots get pushed to nearest empty column) every 12 s.
- Vine roots: 200 HP each. While at least one is alive, Warden takes -50% damage and deals +25% damage.
- **Tactical response:** force-kill vine roots fast. Heroes auto-target nearest threat, so the player decides positioning. Druid healing makes "tanking the Warden while DPS-ing vines" viable. Tests positioning + priority targeting.

### 8.5 Realm 4 — Falling Spire

**Intent:** Pressure realm. No new class — this is about *mastering* the roster under aggressive time pressure. Cluster descent on ALL stages means Phase 1 is never relaxed.

**Gimmick — Cluster Descent everywhere:**

| Stage | Descent cadence |
|---|---|
| S1 | 1 row / 10 s |
| S2 | 1 row / 9 s |
| S3 | 1 row / 8 s |
| S4 | 1 row / 7 s + shake |
| S5 | 1 row / 6 s + shake |

Phase 1 ends early on row-0 contact (existing rule). Skilled players still clear the cluster cleanly; less-skilled get Phase 2 converted heavily.

**New enemy — Accelerator:**
- On death, the **next 1-2 enemies that spawn within 5 s get +50% speed for 5 s** (visible red trail VFX).
- HP: 90 (R4 mult applied). Damage: 14. Speed: 1.0 baseline.
- **Tactical response:** don't burst Accelerators in clusters — spread their deaths out. Tests *attention to enemy type before targeting*, not just "kill highest HP."

**Stage table:**

| Stage | Cluster | Moves | Wave | New element | Intent |
|---|---|---|---|---|---|
| S1 | 6×6 (desc 1/10s) | 16 | 5R + 3B + 3G + 1Y | Descent introduced as baseline | Adapt to time pressure |
| S2 | 6×7 (desc 1/9s) | 17 | 5R + 4B + 4G + 2Y + 1 Accelerator | + Accelerator | Teach accelerator timing |
| S3 | 6×8 (desc 1/8s) | 19 | 6R + 4B + 4G + 2Y + 2 Accelerators + 1 Healer | Mixed pressure | Multi-variant combat |
| S4 | 6×8 (desc 1/7s + shake) | 21 | 7R + 5B + 4G + 3Y + 1 Shielder + 1 Accelerator + 1 Healer + 1 Brute | All variants live | Information overload test |
| S5 (Spire Ravager) | 6×9 (desc 1/6s + shake) | 22 | Full mixed wave + Boss | Boss | Spire Ravager |

**Boss — Spire Ravager:** HP 1000 × 2.40 × 1.5 = **3,600**. Damage on reach: 50 × 2.40 = 120. Color: Red.

**Boss mechanic — Lane Slam:**
- Every 10 s, the Ravager slams the lane. 2 s telegraph (ground-crack VFX along row 0, screen tremor pre-roll).
- On slam: all heroes are forcibly **collapsed to column 0** (far left). Stack resolves with leftmost-priority; any heroes that can't fit go to the back of the row in FIFO order.
- **Tactical response:** pre-position heroes before slam (cluster on the right so the collapse fans them out left), then redistribute. Tests whether players can read/react to a forced-reposition mechanic under fire. Drag mechanic is load-bearing here.

### 8.6 Realm 5 — Voidcrown

**Intent:** Endgame realm. Adds **Purple (Wizard)** — burst-damage class. Two-boss finale. All systems active simultaneously. The "did we build this game well" exam.

**New class — Wizard (Purple):**

| Stat | Value | Notes |
|---|---|---|
| Base HP | 100 | Same as others |
| Base DMG | 25 (2.5× baseline) | Burst spec |
| Attack speed | 2.0 s | Slowest |
| Range | Full lane | Like Archer |
| Special | **Arcane burst** — every 5th attack deals AOE damage in a 3-cell radius around the primary target | Crowd control |
| Color counter | 2× vs Purple enemies | Standard |

**New enemy — Phaser:**
- Periodically (every 4-6 s) skips one row at random — instead of stepping down one row, **jumps two rows**. Brief flicker VFX when phasing.
- HP: 75 (R5 mult applied). Damage: 12. Speed: 1.1.
- **Tactical response:** disrupts Archer/Wizard column-targeting (they aim at a row that's empty after a phase). Front-load damage with Fire Knights, use frenzy bursts, accept some leak.

**Stage table:**

| Stage | Cluster | Moves | Wave | New element | Intent |
|---|---|---|---|---|---|
| S1 | 6×7 | 18 | 5R + 3B + 3G + 2Y + 2P | + Purple | Meet Wizard class & enemy |
| S2 | 6×8 | 19 | 5R + 4B + 4G + 3Y + 3P + 1 Shielder + 1 Healer | Compound | Multi-color juggling |
| S3 (mini-boss) | 6×8 + desc 1/8s | 21 | 5R + 3B + 3G + 2Y + 3P + 2 Phasers + Echo of Voidcrown | + Phaser + mini-boss | Phaser tutorial + boss warmup |
| S4 | 6×9 + desc + shake | 22 | Full mixed 5-color + 3 Phasers + 1 Healer + 1 Accelerator + 1 Shielder | All variants | Maximum complexity |
| S5 (Voidcrown Twins) | 6×10 + desc + shake | 24 | Full mixed wave + 4 Phasers + 2 Healers + 2 Accelerators + Twin Boss | Two-boss | Finale |

**Mini-boss — Echo of Voidcrown (R5S3):** HP 1500 (no boss multiplier — mid-realm encounter). Damage: 60. Color: Purple. Mechanic: every 6 s, summons a Phaser at the top of the device. Kill fast or get overrun by Phasers.

**Final boss — Voidcrown Twins (R5S5):** Two-phase fight.

**Phase A — Sister Lumen (Light):**
- HP 1000 × 3.20 × 1.5 = **4,800**. Damage 50 × 3.20 = 160. Color: Yellow.
- Mechanic: every 7 s, fires a "Light Beam" down a random column (1.5 s telegraph) — instant-kill any hero in that column on hit.
- **Tactical response:** evacuate the marked column. Tests drag urgency.

**Phase B — Sister Umbra (Shadow):**
- Spawns when Lumen drops below 50% HP. HP 1000 × 3.20 × 1.5 = **4,800**. Damage 160. Color: Purple.
- Mechanic: every 8 s, swaps positions of 2 random heroes on row 0 (no telegraph) — disorients player positioning.
- **Tactical response:** keep heroes that work in any column (Wizard, Archer — full-lane range). Avoid heavy positional builds for this fight.

**Twin synergy (while both alive):**
- Both heal each other +10 HP/sec.
- Both deal +15% damage.
- **Tactical response:** burn down Lumen *fast* before Umbra arrives. If both alive simultaneously, the fight gets exponentially harder.

### 8.7 Star criteria (per stage, all realms)

Universal:

| Stars | Criteria |
|---|---|
| ★ | Stage cleared (any HP > 0 at end) |
| ★★ | Stage cleared with ≥ 50% cannon HP remaining |
| ★★★ | Stage cleared with ≥ 75% cannon HP **AND** ≥ 30% move budget unused |

**Realm 3-star completion reward:** 1 premium chest + 50 hero shards for the realm's featured hero pool + 500 gems. One-time per realm.

### 8.8 Hero-shard rotation per realm (drop pool)

Each realm's stages drop hero shards from a specific class pool. Creates "play R3 if I want Druid shards." Drop rates locked in economy pass (§4.5 forthcoming).

| Realm | Featured shard pool |
|---|---|
| R1 | Red (Fire Knight + 7 other Red heroes) |
| R2 | Blue (Ice Mage + 7 others) |
| R3 | Green (Druid + 7 others) |
| R4 | Yellow (Archer + 7 others) |
| R5 | Purple (Wizard + 7 others) |

**Replay decay:** First 3-star clear of a stage gives full drops. Subsequent farming gives 50% drops. Caps grind, pushes new-content consumption.

### 8.9 New systems per realm (build state summary)

| Realm | What it adds beyond R1 |
|---|---|
| R1 | (baseline — Phase 1 cluster/wave, drag, merge, color counter, frenzy, Sludge Lord) |
| R2 | Shielder enemy, cluster shake on S3-S5, Storm Tyrant electrified-column boss, **chapter map UI** |
| R3 | Druid class + chain-heal, Healer enemy, vine-lock cluster system, Verdant Warden vine-root boss |
| R4 | Accelerator enemy (death-trigger speed buff), descent-on-all-stages, Spire Ravager lane-slam boss |
| R5 | Wizard class + AOE burst, Phaser enemy (row-skip), Echo mini-boss (S3), Voidcrown Twins two-phase finale (S5) |

### 8.10 Risks specific to multi-realm content

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Druid heal stacking trivializes R3** | Medium | R3 too easy | Cap chain-heal at +5 HP/sec per Druid (no compounding); cap healing rate per hero at +15 HP/sec total |
| **Phaser breaks Archer/Wizard targeting too hard** | Medium | R5 feels unfair to column-class builds | Telegraph phase 0.5s before; column classes get a 1-cell prediction buffer |
| **Lane Slam (Ravager) creates uninteractive frustration** | Medium-High | R4S5 quit risk | Heroes regain prior positions over 2 s after slam ends (gentle restore, not instant); 2 s telegraph is generous |
| **Twin boss requires perfect builds (whale-only)** | High | R5S5 paywall feel | Tune Twin synergy heal-rate so F2P L20 roster can win in 3-4 attempts; consider auto-grant "Heal Resistance" boon for R5S5 |
| **Realm gimmicks compound badly** (shake + descent + Phaser → unreadable) | High | R5 frustration | Internal playtest R5S4 and R5S5 in greybox before final tuning; consider toning down concurrent gimmicks if testers consistently lose to "too many things happening" |
| **R3 vine-lock confuses players** | Medium | Q2 fail | Vine-locked bubbles get pulsing green outline + tutorial popup on first encounter ("clear adjacent rows or use Color Bomb") |
| **Shielder kills Archer / Wizard execute fantasy** | Low-Med | Burst-class feels weak | Execute (Archer special) still applies AFTER shield breaks; document this clearly in tooltip |

### 8.11 What's deferred to post-launch (R6+)

- **R6+ realms:** Each adds 1 new class color (need 8 total to fully fill the 5-color × 2-class slot grid), 1 new enemy variant, 1 new boss mechanic. Cadence: 1 realm every 4-6 weeks.
- **Hero level cap raises:** L30 → L40 at R8 launch, L40 → L50 at R12 launch.
- **Endless mode / weekly tower:** A "infinite scaling realm" where the player picks up where they left off each week. Drives whales who hit L30 on multiple heroes.
- **PvP arena:** Async, hero-roster vs hero-roster simulation. Post-launch month 3+.
- **Clan/guild raids:** Shared color-themed raid boss with damage contribution from each member. Post-launch month 4+.

---

## Section 9 — Phase 2: full R1-R5 playable + chapter UI

> **What this phase is.** Once R1 hypothesis test passes (§6.5), build the rest of the content runway: R2-R5 (specced in §8.3-§8.6), all new classes/enemies/bosses, and the chapter map UI that ties them together. Meta economy still OUT of scope — see §9.3 for the playtest-mode toggle that lets us validate content without it.

### 9.1 What ships in this phase

| Category | Adds beyond R1 |
|---|---|
| Realms | R2 / R3 / R4 / R5 (full content per §8.3-§8.6) |
| Hero classes | + Green (Druid, R3) / + Purple (Wizard, R5) |
| Enemy variants | + Shielder / Healer / Accelerator / Phaser |
| Bosses | + Storm Tyrant / Verdant Warden / Spire Ravager / Echo of Voidcrown / Voidcrown Twins |
| Realm gimmicks | + Cluster shake S3-5 (R2), vine-lock rows (R3), descent-on-all-stages (R4), two-boss finale (R5) |
| UI screens | + Chapter map / stage select / realm complete (3 screens, 11 total) |
| Cluster patterns | + Per-realm starting sizes per §3.10.1 |
| Cross-realm scaling | All §3.10 scaling tables active (cluster / enemy / hero level / modifier stacking) |

### 9.2 Chapter map UI

Navigation hub between realms. Replaces current "MetaHub → MatchScene loop." Greybox-friendly.

**Realm map screen**
- 5 realm tiles in a path metaphor (linear, not branching). Vertical or horizontal scroll.
- Each tile: realm name, theme image (greybox = colored block), star count (e.g. "★★★★★ 15/15"), state.
- States: **Locked** (greyed + padlock), **Available** (highlighted), **Completed** (gold trim).
- Tap → stage select for that realm.

**Stage select screen (per realm)**
- 5 stage nodes in a path matching realm theme (clouds R1 / lightning R2 / vines R3 / falling rocks R4 / stars R5).
- Each node: stage number, ★/★★/★★★ display, locked/available state.
- Boss stage (S5): visually distinguished — larger, animated, boss silhouette.
- Tap → loadout → MatchScene.

**Unlock rules**
- R1 always available. R2 unlocks on R1S5 clear (1+ star). R3 on R2S5. R4 on R3S5. R5 on R4S5.
- Within a realm: S2 unlocks on S1 clear, S3 on S2, etc.

**Replay rules**
- Any previously-cleared stage is replayable.
- Best star count displayed; improvable on replay.
- Star upgrades persist (★★ → ★★★ if better run).

**Realm complete screen**
- First clear of a realm's boss → "Realm Complete" screen with star tally + reward.
- Greybox reward: confetti + new realm reveal animation (locked tile flips to available with sound cue).
- Launch-mode reward (when meta is built): 1 premium chest + 50 shards + 500 gems.

| Screen | When shown | Greybox shape |
|---|---|---|
| Chapter map | After splash, after run end, "Map" button from any screen | 5 realm tiles in a path, scroll if needed |
| Stage select | Tap realm tile | 5 stage nodes + boss node, current stars shown |
| Realm complete | First boss clear per realm | Star tally + reward + "Continue" → next realm reveal |

### 9.3 Playtest mode vs Launch mode (config toggle)

**The problem.** §3.10 enemy scaling assumes the player levels heroes. An unleveled L1 Bronze roster will wall at R3+ and cannot beat R5. Meta progression is OUT of scope, so the player has no way to *actually* level heroes.

**The solution.** Two config presets in `GameConfig.gd`:

| Preset | Hero state | Enemy stats | Use case |
|---|---|---|---|
| **playtest_mode** (default for this phase) | All 5 classes unlocked. Heroes spawn at simulated L15 (1.60× base stats) — represents typical D14 player. | Full R1→R5 scaling per §3.10. | External tester plays full content runway without meta built. Validates content + difficulty curve. |
| **v1_test_mode** (Phase 1 only) | R/B/Y only. Heroes at L1 base. | R1 only — locked at §3.9 values. | Original v1 hypothesis test config. |
| **launch_mode** (v2+) | Heroes start L1, level via shards. Full meta progression. | Full R1→R5 scaling per §3.10. | Shipped game. NOT in scope for this phase. |

**Why this matters.** Playtest mode separates "is the difficulty curve readable?" from "is the shard drop rate right?" Content gets validated first, economy second (the meta pass that follows this phase).
