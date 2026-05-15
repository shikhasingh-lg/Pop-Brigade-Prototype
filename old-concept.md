---
name: Pop Brigade — Concept One-Pager (Pitch)
status: active
created: 2026-05-11T00:00:00.000Z
updated: 2026-05-14T00:00:00.000Z
audience: leadership pitch (concept selection)
scope: pitch only — build detail lives in design-spec.md, combat-design.md, ui-flow.md
---
# Pop Brigade

A bubble-shooter × lane-tower-defense hybrid for the Slime Legion / GearPaw Defender/Galaxy Defense audience. 

---

## The bet
| **Game** | Two-phase lane TD: a bubble shooter recruits your army, then your army defends a lane. Hero collection meta, gacha-tied. |
| **Audience** | Hybrid-casual , 5–15 min sessions, plays Slime Legion / Lucky Defense / Bubble Witch / Capybara Go. |
| **Why now** | Bubble-shooter lane is the most fragmented in mobile (5 publishers, none with 2 slots, no UA giant). Bubble-TD hybrid is empty. Slime Legion proves the 2-phase prep→defend pattern at small-team scale. |

---

## How this concept was chosen

This isn't an "I had an idea." It's the output of the 6-phase research methodology applied across ~25 comp games. Full audit in `game_comparison_framework.md`; summary here:

**Six kill filters applied** (team-of-10 buildable, MVP in 8–12 weeks, UA giant risk, variant space, 10–30% innovation viable, $200K+/mo plausible). 17 games killed at Phase 1–2 — including Last War, Whiteout Survival, Kingshot, Coin Master, Archero 2 (UA-giant hard veto), Random Dice / Rush Royale / Hero Wars Alliance (saturation + ops-model mismatch).

**Survivors scored on 8 weighted dimensions** (market, UA, variant fit, core loop, retention, monetization, team fit, MVP speed). Top of matrix:

| Rank | Game | Score | Why we didn't just clone |
| --- | --- | --- | --- |
| 1 | Cell Survivor | 85 | 1D lane shooter with biology art; commercially proven but the lane already has a fast-growing comp set we'd enter as the 4th clone. |
| 2 | Slime Legion | 82 | Best floor-case proof for team-of-10 $200K+/mo. Pop Brigade *targets this exact player* — clone risk is real, but a direct slime/merge-TD clone enters a lane Perfeggs and 4399 already occupy. |
| 3 | GearPaw Defenders! | 80 | Fastest-growing direct comp. Static-shooter defense; direct-clone bid against Perfeggs in their growth window is a fight on their creative axis. |

**Why Pop Brigade slots in here:**
- **Empty lane.** Bubble-TD hybrid has only one indie attempt (Bubble Shooter Tower Defense) and it fails the cluster–lane unification test — confirmed by direct playthrough. The lane is open because nobody has solved it, not because nobody wants it.
- **No UA giant in the parent lane.** Bubble shooter is the most fragmented Top Free category — King, Jam City, LINE, Miniclip share it at $500–700K/mo each. King is the only meaningful risk and has not historically moved into TD hybrids in 5+ years.
- **Targets the highest-scoring small-team audience in our matrix.** Slime Legion players. We are not entering Slime Legion's lane; we are recruiting from its audience using a different input gesture.
- **10–30% innovation envelope holds.** Base loop (lane TD + hero gacha) is proven by 3 scored comps. The bubble shooter is the input swap. Differentiation is testable in playtest, not invented from scratch.

**The existential risk this concept inherits** (and how it's tested): The one shipped bubble-TD hybrid feels like "two games glued together" — cluster and lane disconnected. Our variant plan (cluster-as-spawner via hero bubbles, pop-point hero spawn column) is a direct fix; if greybox playtest fails the unification test, the concept dies. This is named as the kill criterion before prototype, not after.

---

## 30-second pitch

A vertical-lane tower defense in two phases. **Phase 1 (Build):** you have a fixed number of shots to fire at a bubble cluster overhead. Specific bubbles have heroes trapped inside — popping those frees the heroes onto your lane. Phase 1 ends the moment every hero bubble is freed, or you run out of shots — whichever comes first. **Phase 2 (Combat):** your heroes auto-attack the incoming wave; you drag them along the line to meet threats, and drag a hero onto another of the same class to merge them into a stronger tier (Bronze → Silver → Gold). Build, defend, upgrade — in a 90-second stage.

**The hook in one line:** the bubble shooter is how you recruit your army.

---

## Core loop (summary)

**Phase 1 — Build** *(uses a fixed move budget)*
1. Aim and fire at the cluster. Match 3+ same-colour pops bubbles.
2. Specific bubbles trap heroes (visible from spawn, 1–4 per stage). Pop them to free a hero onto the lane.
3. Match size determines hero tier: 3–5 = Bronze, 6–9 = Silver, 10+ = Gold (rare; requires a chain).
4. Phase ends when all hero bubbles are freed OR moves run out. Leftover non-hero bubbles are swept.

**Phase 2 — Defend** *(no firing — drag instead)*
1. A scripted wave spawns. Heroes auto-attack.
2. Drag heroes horizontally along row 0 to meet incoming threats.
3. Drag onto a matching hero to merge into the next tier. Gold caps.
4. Stage clears when the wave dies. Run = 5 stages + boss.

**Cognitive layers** (Slime Legion ceiling = 4; we sit at 5 with merge as the optional layer):
1. Aim + fire under a limited budget. 2. Hero-bubble priority — which hero do I free? 3. Colour frenzy setup — should I starve a colour for a Phase 2 buff? 4. Hero positioning under wave pressure. 5. **Merge vs spread** — stack same-class for tier-up power, or spread for column coverage.

> Full mechanics spec, tuning values, prototype status, and decision log live in `design-spec.md`.

---
## Why the Slime Legion / Lucky Defense / GearPaw audience moves

The crossover thesis, not just asserted:

| Bridge | Evidence |
| --- | --- |
| **Same player profile** | Hybrid-casual, female-skew, 5–15 min sessions, ~4 cognitive layers tolerated. Same demographic plays Bubble Witch 3 ($622K/mo) and Slime Legion ($613K/mo) — they're in the same Top Free band. |
| **Same meta architecture** | 3-layer (stage → run → meta) progression with gacha-driven hero collection. Lifted directly from the Slime Legion playbook. |
| **Same prep→defend rhythm** | Slime Legion: match-3 prep, then TD wave. Pop Brigade: bubble-shoot prep, then TD wave. Same dopamine shape, different input. |
| **Lucky Defense merge depth, inherited** | Drag-to-merge same-class same-tier heroes (B+B → S → G). Reads as a familiar mechanic to anyone who has played Lucky Defense or Merge Mansion. |
| **For the GearPaw audience specifically** | What GearPaw players actually return for is the lane TD + collectible-hero loop, not the gear-mount input. We keep both. The bubble shooter replaces the static-shooter input, which is where GearPaw is currently most exposed to Habby's Wittle Defender pattern. |

**Not a fit for:** pure puzzle Bubble Witch / Panda Pop audience. We do not compete with them — we borrow their input.

## Differentiation (10–30% innovation framing)

| Slice | What |
| --- | --- |
| 70% Slime Legion DNA | Phased build → defend, lane TD, gacha meta, hero-collection drives gameplay |
| 20% bubble shooter input | Aim-fire with a move budget, cluster planning, colour chaining |
| 5% Lucky Defense merge depth | Drag-to-merge same-class same-tier heroes (B+B → S → G), layered on a bubble-shooter input rather than gacha-summon-only |
| 5% novel hooks | **(a) Hero bubbles** — heroes are trapped in specific bubbles, visible from spawn; the bubble shooter is a hero-recruitment layer, not a pure puzzle. **(b) Race-to-burst Phase 1 end condition** — Phase 1 ends the instant hero bubbles run out OR moves run out, so every shot is a recruit-or-waste choice. **(c) Phase 2 drag carries dual intent** — reposition for threat OR merge for tier-up, same gesture. |

---

## Competitive positioning

| Game | Why it's not us |
| --- | --- |
| Bubble Witch 3 ($622K/mo, King) | Pure puzzle, no TD layer, no hero collection |
| Panda Pop ($575K/mo, Jam City) | Pure puzzle |
| Slime Legion ($613K/mo, Perfeggs) | Same TD meta but match-3 input; we offer aim-feel + hero-bubble recruitment as a richer Phase 1 |
| Lucky Defense ($5M/mo, 111%) | We share the active-placement + same-class-same-tier merge ladder, but units arrive from a bubble shooter (not a gacha summon shop), and merging shares a gesture with repositioning |
| GearPaw Defenders! ($880K/mo growing, Perfeggs) | Pure placement; we add a continuous Phase 1 input + hero-bubble recruitment that gates Phase 2 |
| Bubble Shooter TD (indie hybrid) | Cluster and lane feel disconnected — the failure mode we are explicitly designing against |

**Unclaimed slot:** bubble shooter input + hero-collection TD meta + active hero placement + merge ladder, with the gacha tied directly to in-run hero spawns.

---

## Monetization

| Stream | Notes |
| --- | --- |
| Gacha | Hero pulls — pulled heroes appear in hero bubbles during runs. Direct gacha-to-gameplay link. |
| Energy | 5 runs/day, refill paid or ad |
| Boosters | Pre-run: hero-bubble density +50%, extra moves, special bubble loadout |
| Battle pass | Seasonal, $5–10 |
| Ad rewards | Revive on stage fail, double rewards, free hero bubble |

**First $4.99 moment:** "Extra Moves" continue offer when Phase 1 budget hits 0 with cluster still full.

| Target | Pop Brigade | Soft-launch bar (hybrid casual) | Gap |
| --- | --- | --- | --- |
| D1 | 35% | 40% | Below — Slime Legion / Lucky Defense band, not Habby band |
| D7 | 15% | 18% | Below |
| D30 | 6% | 8% | Below |
| ARPDAU | $0.15–$0.25 | $0.40 | Below |

**This is a deliberate floor-case business shape, not a Habby-tier target.** The realistic exit is the $500K–$2M/mo Slime Legion / Lucky Defense band. A Capybara Go!-tier outcome ($19M/mo peak) would require the gacha-narrative pipeline to land harder than current scope supports. Leadership should evaluate this concept against that ceiling, not against $19M/mo.

---

## Strategic risks (the four that matter)

| Risk | Mitigation | Kill signal |
| --- | --- | --- |
| **Cluster–lane disconnect** (the inherited bubble-TD failure mode) | Hero bubbles make the cluster *about* the lane: every shot is a recruitment decision, not a puzzle move. Hero spawn column tied to popped match. | Greybox playtest: testers describe Phase 1 and Phase 2 as "two games." If true, kill the concept. |
| **Slime Legion clone perception** | Different input (aim-fire vs match-3), gacha tied to bubble drops, merge ladder on top. Marketed against the Slime Legion player, not against Slime Legion the product. | UA creative test: if our hook reads as "Slime Legion but worse," kill. |
| **Monetization ceiling below soft-launch bar** | Gacha-in-run + hero-bubble-density boosters create direct spend hooks. Battle pass + chests sit on top. | First 14-day soft-launch ARPDAU below $0.10 = re-architect monetization or kill. |
| **King or Habby copies post-launch** | First-mover defensibility via gacha pipeline + the hero-bubble-as-gacha-shelf hook. Realistic 12–18 month window. | Habby soft-launches a direct clone in PH/CA/BR within 6 months of our soft launch = leadership decision point. |

> Prototype-tuning risks (budget calibration, frenzy duration, drag-intent collision, etc.) live in `design-spec.md`. The four above are the strategic risks that decide whether the concept survives.

---

## 