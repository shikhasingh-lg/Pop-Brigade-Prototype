---
name: Bubble Shooter TD — Concept One-Pager (Pop Brigade)
status: active
created: 2026-05-11
updated: 2026-05-13
---

## Goal
A 1-pager pitch for a Bubble Shooter Tower Defense hybrid targeting the Slime Legion player.

## Context
- Studio pivot post-BLACK: hybrid casual game, 6-8 month ship, team of 10. See [new_project_market_research.md](~/.claude/projects/-Users-shikhasingh/memory/new_project_market_research.md).
- Top 3 candidates from research: Lucky Defense (merge), Slime Legion (match), GearPaw Defenders (gear).
- AppMagic competitive scan (2026-05-10) validated:
  - Bubble shooter lane: 5 publishers in top 5, no UA giant. $500-700K/mo across King / Jam City / LINE / Miniclip. Most fragmented lane.
  - Slingshot lane: XFLAG/Monster Strike ($27M/mo) JP-locked monster collector — global slingshot-TD essentially empty.
  - Plinko lane: top game $10K/mo. Genre too small.
- Audience decision: target Slime Legion player → bubble shooter has stronger DNA match than slingshot (color = match, pattern recognition, female-skew casual audience overlap).
- Methodology: [game_research_methodology.md](~/.claude/projects/-Users-shikhasingh/memory/game_research_methodology.md).

---

# One-Pager: Pop Brigade (working title)

## Pitch (30 sec)

A vertical-lane tower defense in two phases. **Phase 1 (Build):** you have a fixed number of shots — 10 at level 1 — to fire at a cluster of bubbles overhead. Match 3+ same-color pops bubbles. Specific bubbles have heroes trapped inside (visible from spawn, ~1-in-8 density) — popping those frees the trapped heroes onto your lane. **When your shots run out, every bubble left in the cluster becomes an enemy** that falls toward your line, plus a scripted enemy wave also begins. **Phase 2 (Combat):** your heroes auto-attack the wave, and you can **drag them horizontally along the line** in real time to meet the threat — and **drag a hero onto another of the same class to merge them into a stronger tier** (Bronze + Bronze → Silver → Gold). Build, then defend, then upgrade on the line.

**Same brain as Slime Legion, different gesture — and a sharper causal link: the bubbles you don't pop become the wave you fight. Same merge depth as Lucky Defense, but the units come from a bubble shooter.**

---

## Target player

Slime Legion / Lucky Defense / Bubble Witch / Capybara Go player. Hybrid casual, female-skew, 5-15 min sessions, comfortable with ~4 cognitive layers, plays multiple Habby-tier TD hybrids.

---

## Core loop (phased: Build → Combat)

### Phase 1 — Build (uses your move budget)

| Beat | Action | Outcome |
|---|---|---|
| Fire | Aim and fire a bubble | Move budget −1 |
| Pop | Match 3 same color (no hero bubble in match) | Clear bubbles, reduce cluster pressure |
| Pop hero | Match 3+ that includes a **hero bubble** | Free trapped hero onto row 0 below the popped bubble's column |
| Pop hero (big) | Match 6-9 / Match 10+ with a hero bubble | Silver / Gold tier hero (Gold is rare — usually via Color Bomb on a stage 4-5 cluster) |
| Frenzy | Clear all of one color | That color is "frenzied" — its heroes get +50% damage in Phase 2 |
| End | Move budget reaches 0 (or cluster cleared, or descent hits row 0 stages 4+) | **Phase 1 ends** |

### Transition (1 s "GET READY!" wipe)

| Event | Effect |
|---|---|
| Cluster leftovers | **Every bubble still in the cluster spawns an enemy** of that color, falling from its position |
| Scripted wave | Also starts — fixed composition per stage |

### Phase 2 — Combat (no firing, but you can drag)

| Beat | Action | Outcome |
|---|---|---|
| Auto-combat | Heroes auto-fire at incoming enemies | Cluster-converted + scripted wave both attack |
| Drag (reposition) | Press-hold any hero, drag to empty cell, release | Hero repositioned (no cooldown, full range) |
| Drag (merge) | Press-hold any hero, drag onto **same-class same-tier** hero, release | **Merge** → one hero, next tier (B+B → S, S+S → G). Full new-tier HP. Gold is the cap. |
| Drag (swap) | Drag onto a hero that doesn't match class/tier | Swap places (existing behaviour) |
| Clear | All enemies defeated, no enemies on lane 2 s | Stage clear → boon pick → next stage |
| Fail | Player HP = 0 | Stage fail → run ends |

**Cognitive layers (Slime Legion ceiling = 4; we sit at 5 with merge as the optional layer):**
1. Aim + fire with limited shots (Phase 1)
2. Hero-bubble priority — which hero do I free vs which wall do I clear (Phase 1)
3. Color frenzy setup — should I starve a color to enable Phase 2 buff (Phase 1)
4. Hero positioning under wave pressure (Phase 2)
5. **Merge vs spread** — do I stack same-class heroes for tier-up power, or spread them for column coverage (Phase 2). Optional — players who ignore merging still have a complete game; merging is the depth ceiling. Also auto-resolves in Phase 1 when matching heroes land on the same row-0 cell, so beginners are pulled into the mechanic passively.

---

## Hero bubbles + colour relationship

| Element | Role |
|---|---|
| **Bubble colour** | Chaining + clearing — colour-matched groups pop together. Drives puzzle feel. |
| **Hero bubble** | A specific hero trapped inside, **shown as a bubble with a hero face/portrait** (always visible — the player can plan around it). Hero identity lives **in the bubble**, not the colour. ~1 in 8 bubbles is a hero bubble (v1 greybox). |
| **Hero class** | Determined by the trapped hero. A Fire Knight (DPS) can be in a green bubble. |
| **Colour frenzy** | Clear all of one colour in Phase 1 → its heroes get +50% damage for the full Phase 2 wave. |

This decouples the four-way tuning bind from the original color-=-class design. Colour is now a puzzle layer; hero identity lives in gacha + bubble drops.

---

## Five-class hero system (v1 enabled: 3)

| Color | Class | Fantasy | v1? |
|---|---|---|---|
| Red | DPS | Fire Knight | ✅ |
| Blue | Slow | Ice Mage | ✅ |
| Yellow | Range | Archer | ✅ |
| Green | Heal | Druid | v1.5 |
| Purple | AOE | Wizard | v1.5 |

---

## Move budget per stage

| Stage | Move budget | Notes |
|---|---|---|
| 1 | 10 | Tutorial pace, no descent |
| 2 | 11 | + Blue introduced |
| 3 | 13 | + Yellow + Runner enemy |
| 4 | 14 | + Cluster descent (stages 4+) |
| 5 (boss) | 16 | + cluster shake during P1 |

The budget creates a clear player goal each stage — "make these shots count." Run out before clearing the cluster → leftover bubbles become enemies → Phase 2 is harder.

---

## Hero placement & movement

- Hero spawns at row 0 in the **column directly below** the popped hero bubble.
- If that column is full: nearest empty cell. No silent overwrite (tier-upgrade replace OR FIFO queue).
- **Phase 1: heroes are stationary.** They idle on the line, waiting.
- **Phase 2: heroes are fully draggable.** Touch and hold → drag horizontally along row 0 → release commits. No cooldown, swap-on-occupied.
- Carry-over: surviving heroes go to the next level with **HP + column placement preserved**.

---

## Progression (3-layer meta, copied from Slime Legion playbook)

| Layer | Length | Hook |
|---|---|---|
| Stage | 60-150 sec | Phase 1 puzzle pressure + Phase 2 wave |
| Run | 10-12 min | 5 stages + boss, pick-3 boons including 1 synergy (Color Affinity) |
| Meta | Long-term | Hero gacha (~25 heroes), cannon upgrades (incl. move-budget upgrades), battle pass, daily/weekly events, clan raids (post-launch) |

---

## Monetization

| Stream | Notes |
|---|---|
| Gacha | Hero pulls — pulled heroes appear in hero bubbles during runs. **Direct gacha-to-gameplay link.** |
| Energy | 5 runs/day, refill paid or ad |
| Boosters | Pre-run: hero-bubble density +50%, extra moves, special bubble loadout |
| Battle pass | Seasonal, $5-10 |
| Ad rewards | Revive on stage fail, double rewards, free hero bubble |

**First $4.99 moment:** "Extra Moves" continue offer — when Phase 1 budget hits 0 with cluster still full, pay gems for +3 moves. Players will be deep into a stage when this fires.

**Target ARPDAU:** $0.15-0.25 (Slime Legion / Lucky Defense band)
**Target D1 / D7 / D30:** 35% / 15% / 6%

---

## Differentiation (10-30% innovation framing)

| Slice | What |
|---|---|
| 50% Slime Legion DNA | Phased build → defend, lane TD, gacha meta, hero-collection drives gameplay |
| 20% bubble shooter input | Aim-fire with move budget, cluster planning, colour chaining |
| 15% Lucky Defense merge depth | Drag-to-merge same-class same-tier heroes into next tier (B+B → S → G). Lifted from Lucky Defense / merge-game pattern, but layered on top of bubble-shooter input rather than being the only input. |
| 15% novel hooks | **(a) Hero bubbles** — heroes are trapped in specific bubbles, visible from spawn. **(b) Leftover-bubbles-become-enemies** — the bubbles you don't pop are the wave you fight (causal link between phases). **(c) Phase 2 hero dragging carries dual intent** — reposition for threat OR merge for tier-up, same gesture. None of the three has a direct equivalent in the comp set. |

---

## Competitive positioning

| Game | Why it's not us |
|---|---|
| Bubble Witch 3 ($622K/mo, King) | Pure puzzle, no TD layer, no hero collection |
| Panda Pop ($575K/mo, Jam City) | Pure puzzle |
| Slime Legion (Habby) | Same TD meta but match-3 input; we offer aim-feel + the leftover-becomes-wave causal link |
| Lucky Defense (IGG) | We share both the active-placement pattern AND the same-class-same-tier merge ladder — but bubble shooting (not gacha-summon) is how units arrive on the line, and merging shares a gesture with repositioning rather than being its own pull-summon shop |
| GearPaw Defenders | Pure placement; we add a continuous Phase 1 input (aim-fire) + the leftover-conversion hook |

**Unclaimed slot:** bubble shooter input + hero-collection TD meta + active hero placement + merge ladder, with the gacha tied directly to in-run hero spawns AND a clear causal link from Phase 1 to Phase 2.

---

## Production

| Item | Estimate |
|---|---|
| Team | 10 |
| Engine | Unity |
| MVP timeline | 6-8 months to soft launch |
| Soft launch markets | PH, ID, BR, TR (Habby-style emerging-market test) |
| Global launch target | Q1 2027 |

---

## Risks + open questions

| Risk | Mitigation |
|---|---|
| Players don't connect "leftover bubbles" with "wave enemies" — Q1 fail | Strong transition VFX: each leftover bubble visibly drops out of cluster and becomes an enemy in same column. "Conversion preview" during 1 s wipe. |
| Move budget too tight or too generous | Pre-tuned ±2 budget configs ready to swap mid-test |
| Cognitive load at stage 4-5 (descent + budget + drag + frenzy) | Stages 1-3 introduce mechanics one at a time. Stage 4 is the descent introduction. |
| Hero dragging unused | First lever: spawn heroes in unhelpful columns; second: positional bonuses |
| Merge mechanic ignored / overlooked | Tune for at least 1 same-class-same-tier matching opportunity per stage by stage 2-3. Auto-merge on P1 row-0 collision pulls beginners in passively. First-time hint on first matching-pair spawn. |
| Merge intent collides with reposition intent in P2 | Telemetry distinguishes resolution=move/swap/merge. If testers fumble — visual highlight of matching-pair on drag-lift; consider long-press → merge-only mode. |
| Merge makes stages 4-5 trivial (one Gold per column) | Wave scripts assume tier mix ~50/35/15 B/S/G by stage 5. If testers hit 60%+ Gold, scale wave +20%. Gold cap (no further merge) already limits the ceiling. |
| King or Habby copies post-launch | First-mover defensibility through gacha pipeline + the hero-bubble-as-gacha-shelf hook is genuinely novel |

---

## Ask

- Sign-off to start paper prototype
- 1 designer + 1 engineer dedicated for 4 weeks
- Reference budget approval (~$200 for buying competitor gems / battle passes for teardown)

---

## Phases

- [ ] Phase 1: CEO review of one-pager + go/no-go for paper prototype
- [ ] Phase 2 (Week 1-2): Paper prototype of phased loop (Figma + manual playtest, focus on leftover-converts-to-wave readability)
- [ ] Phase 3 (Week 2-3): Greybox vertical slice (5 stages, 3 hero colours, no meta, no art)
- [ ] Phase 4 (Week 4): Internal playtest — Q1 causal-arc gate, drag-agency gate
- [ ] Phase 5: Decision gate — go to vertical slice (with art + descent + boss shake) or kill
- [ ] Phase 6: If go — add to game_comparison_framework.md as self-designed entry

---

## Notes / decisions

**2026-05-11**
- Bubble shooter chosen on three signals: closest DNA to Slime Legion, most fragmented competitive lane, audience overlap.

**2026-05-12**
- V8 phased build-then-defend locked over V2 simultaneous-cluster-as-spawner.

**2026-05-13**
- **Hero bubbles introduced.** Only specific bubbles (visible face/portrait, ~1-in-8 density) spawn heroes. Other bubbles clear pressure only. Class decoupled from bubble colour.
- **Heroes are draggable during Phase 2.** Lucky Defense pattern — full row-0 range, no cooldown, swap-on-occupied. (Implemented in godot-prototype.)
- **Phase 1 end trigger: move budget** (10 at L1, scaling up) instead of time cap. Clearer player goal.
- **Phase 1 → Phase 2 transition: leftover bubbles convert to enemies.** Replaces v1's "misses vanish below spawn line." The bubbles you didn't pop become the wave you fight — sharper causal link.
- **Carry-over rule confirmed: HP + column placement preserved.** No Bronze downgrade, no heal. (Implemented in godot-prototype, toggleable via GameConfig.)
- Druid and Wizard deferred to v1.5.
- Open: move budget tuning (10 / 12 / 15 at L1); transition VFX (1 s wipe vs longer with conversion preview); hero-bubble density tier (flat 1-in-8 vs scaling).
- **Hero merge added.** Same class + same tier → next tier (Bronze + Bronze → Silver, Silver + Silver → Gold; Gold caps). Phase 2 = drag-to-merge (replaces swap-on-occupied only when class + tier match); Phase 1 = auto-merge when a freed hero lands on a matching row-0 cell. Lifted from Lucky Defense, layered on top of bubble-shooter input. Adds an optional 5th cognitive layer (merge vs spread). Open: merge HP rule (full new-tier vs sum), legibility without tutorial, cascade behaviour (currently no — each merge is one discrete event).
- **Spawn-tier thresholds widened.** Match 3-5 = Bronze, 6-9 = Silver, 10+ = Gold (was: 3 / 4 / 5+). Spawn-Gold now requires a 10-bubble chain — realistic only on a stage 4-5 Color Bomb. Bronze is the default for any normal pop *and* early-stage Color Bombs; Silver is a real chain reward (6+ connected); Gold mostly comes from merging. The merge ladder is no longer redundant — it's the primary path to Gold.
