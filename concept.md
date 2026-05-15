---
name: Pop Brigade — Concept (Template v2)
status: active
created: 2026-05-11
updated: 2026-05-14
audience: leadership pitch (concept selection)
template: New Game Concept — Template v2
scope: concept-level pitch. Full mechanics live in `design-spec.md`, `combat-design.md`, `ui-flow.md`. Original pitch preserved as `old-concept.md`.
---

# Pop Brigade

## 1. Identity

| Field | Value |
| --- | --- |
| Working title | **Pop Brigade** |
| Genre / subgenre | Lane tower defense × bubble shooter, with hero-collection gacha meta and a same-class merge ladder. Two-phase per stage: Build (bubble-shoot to recruit heroes) → Defend (auto-combat + drag-to-merge). |
| Target audience | Hybrid-casual mobile players, female-skew, 5–15 minute sessions, who already play **Slime Legion / Lucky Defense / GearPaw Defenders / Bubble Witch 3** and want a build→defend rhythm with a collectible-hero hook. Not the pure-puzzle Panda Pop player; not the Last War / Whiteout SLG player. |

---

## 2. Core thesis / idea

**Player-voice, ~115 words.**

There's a cluster of bubbles hanging overhead, and some of those bubbles have my heroes locked inside. I get a fixed number of shots — every shot I waste on a regular bubble is a hero I never recruit. The second I free the last hero (or run out of shots), the cluster vanishes and a wave of enemies starts marching down my lane. My heroes auto-attack. I drag them left and right to meet the threats. When two of the same hero bump into each other they merge into a bigger, badder version. Clear five stages and a boss in about 90 seconds each, then I pull the gacha and the heroes I unlock show up trapped in the next run's cluster.

---

## 3. Hypothesis — why this game, why it will work

This concept was not picked from a brainstorm. It is the output of a 6-phase research methodology applied across ~25 comp games (full audit in `game_comparison_framework.md`). Three testable hypotheses underpin the bet.

### H1. The audience exists and is reachable on a different input gesture.

**Claim.** Slime Legion / Lucky Defense / GearPaw / Galaxy Defense / Cell Survivor / Gear Defender players will accept a bubble-shooter input as the prep phase of their familiar lane-TD loop.

**Evidence.** All six comps share session length, audience skew, ~4-layer cognitive ceiling, prep→defend rhythm, gacha meta. Bubble Witch 3's audience overlaps demographically.

**Falsification.** UA creative test in PH/ID/PL: bubble-shooter input depresses CTR vs match-3 by >30% on the same lane-TD frame.

### H2. No UA giant in the parent category will enter the hybrid.

**Claim.** Bubble shooter is the most fragmented Top Free category. King is the only structural threat and has not moved into TD hybrids in 5+ years. 12–18 month first-mover window.

**Evidence.** AppMagic publisher revenue distribution + 5-year King portfolio scan. Habby is survivor/auto-shooter, not bubble; Perfeggs is lane-TD, not bubble.

**Falsification.** King or Habby soft-launches a direct clone in PH/CA/BR within 6 months of our soft launch.

### H3. The 10–30% innovation envelope holds.

**Claim.** Pop Brigade is 70% proven DNA + 20% input swap + 5% merge depth + 5% novel hooks. None of the innovation is invented from scratch; every layer is borrowed from a shipped, profitable game.

**Evidence.** 70% Slime Legion DNA (phased build→defend, lane TD, gacha hero collection). 20% bubble-shooter input (Bubble Witch / Panda Pop pattern). 5% Lucky Defense merge ladder (B+B → S → G). 5% novel — hero-bubble recruitment, race-to-burst Phase 1 end condition, dual-intent Phase 2 drag.

**Falsification.** Greybox playtest shows testers describe the two phases as "two games" → the cluster–lane unification thesis fails and the concept dies pre-prototype.

---

### Why this concept will work (the bet, plain)

The audience is already proven by six comp games. The input is already proven by Bubble Witch. The lane is empty because nobody has solved the cluster–lane disconnect, and we have a named fix for it. There is no UA giant in the parent category willing to enter the hybrid. The economics are floor-case ($500K–$2M/mo Slime Legion band), not Habby-tier — and that's the right ambition for a team-of-10. If H3 holds in greybox playtest, this concept ships. If it fails, it dies cheap, before prototype.

---

## 4. Player journey

### Detailed D1 — first 60 seconds (beat-by-beat)

- **0–5s.** Vertical phone screen. A cluster of coloured bubbles fills the top two-thirds; a launcher sits at the bottom. One bubble at the cluster's edge glows gold with a tiny hero silhouette inside it. Tutorial finger taps it: "free your first hero."
- **5–15s.** Player drags to aim, releases. A bubble flies up, hits a 3-of-a-colour match, pops, and a chibi hero drops onto the lane below the cluster with a satisfying *thunk* + voice line ("Reporting!").
- **15–25s.** Three more hero bubbles light up. The move counter shows **8 shots left**. Player fires again — this time a 5-match. The freed hero drops as a **Silver** tier (an "S" badge on their head, slightly bigger sprite).
- **25–40s.** Last hero bubble pops. The whole cluster sweeps away in a satisfying clear. Screen banner: **"WAVE INCOMING."** Three goblins start marching down the lane.
- **40–60s.** Heroes auto-attack. Player drags the front-line tank a step left to intercept the first goblin. A second goblin lane-switches; player drags a matching hero across, the two heroes meet, snap-zoom merge animation, one bigger hero remains. Wave dies. **"STAGE 1 CLEAR."** Confetti + a coin spray. Tutorial finger taps **Next Stage**.

### Rest of D1 (next 5–10 minutes)

- **Stages 2–3** introduce a bigger cluster, 2–3 hero bubbles each, slightly harder waves. Player learns: matching bigger chains frees stronger heroes.
- **Stage 4** is the first wall. Player runs out of moves with one hero bubble still trapped. Stage starts the Defend phase short-handed; player loses. **Continue offer** appears: +3 moves for ad/$4.99.
- **Stage 5 (boss).** Single fat enemy with a shield. The only way to break it cleanly is to drag two Silver heroes together into a Gold merge. First "aha" beat for the merge layer.
- **Run end.** Coins + a gacha currency drip. First **gacha pull** unlocks a new hero ("Bramble the Druid"). A pop-up promises: "Bramble will appear in your next run's cluster."
- **Home screen.** Daily-login chest queued for tomorrow. Battle pass tile at 5%. Energy: 4/5 runs left.

### Vague D1–D14 idea

| Day | What the player has | What brings them back |
| --- | --- | --- |
| **D1** | 3–5 heroes collected; Realm 1 Run 1 cleared; first gacha pull done; first-win chest queued for tomorrow | First-win chest, "Bramble appears in cluster" promise, second free gacha pull |
| **D3** | 8–10 heroes; first ascension on starter hero; mid-way through Realm 1; daily quests rhythm established | Realm 1 boss kill, banner rotation, battle-pass milestone, guild invite prompt |
| **D7** | First **Gold-tier** hero; Realm 2 unlocked; joined a guild; first $4.99 offer surfaced | Guild boss event, weekly banner drop, first paid starter offer expiring, ranked lane preview |
| **D14** | Multiple ascended heroes; full team comp forming; daily run cap matters; weekend tournament unlocked | Ranked lanes, weekend tournament, new banner with limited hero, guild-coop run mode |

---

## 5. Risks

The four reasons this game could fail (full mitigations + kill signals in `old-concept.md` / strategic risks table):

1. **Cluster–lane disconnect** — the inherited failure mode of every shipped bubble-TD hybrid: Phase 1 and Phase 2 feel like two glued-together games. Hero bubbles + spawn-column-from-pop-point are our direct fix. **Kill signal:** greybox playtesters describe the two phases as "two games."
2. **Slime Legion clone perception** — we share architecture, gacha pattern, and audience. **Kill signal:** UA creative test reads as "Slime Legion but worse" rather than its own hook.
3. **Monetization ceiling below soft-launch bar** — D1 35% / D7 15% / ARPDAU $0.15–$0.25 is a Slime Legion / Lucky Defense floor-case, not a Habby band. **Kill signal:** first 14-day soft-launch ARPDAU below $0.10.
4. **King or Habby copies post-launch** — bubble shooter is King's home turf; lane TD is Habby's. **Kill signal:** Habby soft-launches a direct clone in PH/CA/BR within 6 months of our soft launch.

---

## 6. Reference games

Player-perception comparables.

- **Slime Legion** — Perfeggs, 2024. Same prep→defend rhythm, same lane TD + gacha-hero meta, same hybrid-casual audience. We share the architecture; we don't share the input gesture (match-3 vs bubble-shoot).
- **Lucky Defense** — 111%, 2024. Same active-placement + same-class same-tier merge ladder (B+B → S → G). We don't share the gacha-summon-as-input shop.
- **GearPaw Defenders!** — Perfeggs, 2025. Same lane-TD + hero-collection loop, fastest-growing direct comp. We don't share the static-shooter input.
- **Galaxy Defense** — lane TD with hero-collection meta and prep-then-defend rhythm. Same architecture and audience as Pop Brigade's TD side; different art lane (sci-fi vs fantasy) and different input on the prep phase. Included specifically because it confirms the lane-TD + hero-gacha pattern works outside the Perfeggs orbit.
- **Cell Survivor** — top-of-matrix comp at 85 in the scoring framework; 1D lane shooter with biology-themed art. Same compressed-lane mental model and same hybrid-casual session shape as Pop Brigade's Phase 2; different in that it's a single-input shooter without a recruit phase or merge ladder.
- **Gear Defender** *(distinct from GearPaw Defenders!)* — lane-TD shape with a different prep gesture and a different art lane. Useful comparable because it shows the lane-TD audience is broad enough to support multiple parallel concepts beyond the Perfeggs flagship — the audience is the addressable surface, not any single title.
- **Bubble Witch 3** — King, 2017. Same bubble-shooter aim-feel and audience-overlap; we don't share the pure-puzzle structure (no TD, no hero meta).
- **Capybara Go!** — Habby, 2024. Same hybrid-casual session shape and gacha-narrative ambition; we don't share the survivor-style auto-combat input.

**Genre mashup formula:** *Lane tower defense × bubble shooter × hero-gacha collector × merge ladder.*

---

## 7. Deliverables

### 7.1 Synthetic testing materials — Design (text)

| Artifact | Used by | Word target | Status | Notes |
| --- | --- | --- | --- | --- |
| Full description of core loop | Stage 1 | ~135–170 | **Drafted** — see §7.1.a below | Player-voice. No title, no monetization, no depth claims. |
| Core loop + 1 meta progression | Stage 1 (genre-conditional) | ~150–200 | **Drafted** — see §7.1.b below | Collection-driven concept → required. |
| Store-page variant | Stage 1b (optional) | ~50 | **Drafted** — see §7.1.c below | Pre-install pitch; reads like a Play Store description. |
| First 1–5 minutes the player experiences | Stage 1 supporting / Stage 2 prep | ~200–300 | **Drafted** — see §7.1.d below | Expansion of §4's first-60s into full opening session. |
| D1–D14 player journey (progression description) | Stage 2 | ~200–400 | **Drafted** — see §7.1.e below | Prose, not feature list. Maps to §4's D1–D14 table, expanded. |

---

#### 7.1.a Full description of core loop (player-voice, ~155 words)

A run starts with a cluster of bubbles overhead and a launcher at the bottom of the screen. Some bubbles have heroes trapped inside them. I have a fixed number of shots — usually eight to twelve. I aim, fire, and pop matches of three or more same-colour bubbles. When a match clears a hero bubble, that hero drops onto a lane below the cluster as my unit for the fight. Bigger matches free higher-tier heroes. The instant the last hero is freed, or I run out of shots, the cluster sweeps away and a wave of enemies starts marching down the lane. My heroes auto-attack. I drag them left and right to intercept threats and to merge same-class heroes into stronger versions. A stage clears when the wave dies. A run is five stages and a boss, maybe seven or eight minutes total.

#### 7.1.b Core loop + 1 meta progression (~190 words)

A run is five stages and a boss. Each stage is the same two beats: bubble-shoot to recruit heroes from a cluster, then drag-and-merge those heroes through an incoming wave. Finish the run, win currency, win a chance at a new hero from the gacha.

The meta sits on top of the run. Heroes I unlock from the gacha aren't just permanent additions to my roster; they show up *trapped inside the bubble cluster* on my next run. The heroes I collect literally repopulate my future runs. Upgrading a hero between runs makes them spawn at a higher base tier, so the same Silver-match in the cluster now drops a Gold instead of a Bronze.

Outside the run, there's a realm map — beat enough stages to unlock the next realm with new enemy types and a stronger boss. Daily energy gates how many runs I can do without paying. A weekly banner rotates the gacha. A guild and a weekend tournament sit at the edges for week-two players to keep returning.

#### 7.1.c Store-page variant (~55 words)

Pop bubbles. Free heroes. Defend the lane.

A vertical tower-defense game where the bubble shooter *is* how you recruit your army. Free heroes from a cluster of bubbles, then drag and merge them through waves of enemies. Collect hundreds of heroes — every one you unlock shows up in your next run.

#### 7.1.d First 1–5 minutes the player experiences (~270 words)

The game opens on a vertical screen with a colourful bubble cluster overhead and a launcher at the bottom. A tutorial finger points at a glowing bubble at the cluster's edge with a tiny hero silhouette inside — "free your first hero." The player drags to aim, releases, and a bubble flies up, hits a three-of-a-colour match, pops, and the first hero drops onto the lane with a satisfying *thunk* and a voice line.

Three more hero bubbles light up. The move counter shows eight shots remaining. The player fires again, this time landing a five-match — and the freed hero drops at Silver tier, a touch bigger and badged with an "S." Two more shots, both hero bubbles cleared. The cluster sweeps away and a wave-incoming banner takes the screen.

Three goblins start marching down. The player's heroes auto-attack. A tutorial finger demonstrates a horizontal drag — the front-line tank slides left to intercept the first goblin. A second goblin lane-switches. The player drags a matching hero across, the two units meet, snap-zoom merge animation, one bigger hero remains. The wave dies and Stage 1 clears with confetti and a coin spray.

Stages 2 and 3 reuse the same loop with a bigger cluster and harder waves. By Stage 4 the player has missed a hero bubble and must defend short-handed for the first time; if they fail, a continue offer surfaces. Stage 5 introduces the boss — a fat enemy with a shield only a Gold-tier merge can break. The boss falls, the run ends, the first gacha pull plays. A new hero is unlocked with a promise: "she appears in your next cluster."

#### 7.1.e D1–D14 player journey (~340 words)

**D1** is about teaching the recruit-then-defend rhythm and earning the first emotional beat at the gacha screen. The player clears Realm 1's opening run, collects three to five starter heroes, gets their first gacha pull, and goes to bed with a first-win chest queued for tomorrow and a freshly unlocked hero named in the home screen feed.

**D2–D3** open the merge layer. The player has enough duplicate heroes to start landing same-class merges deliberately rather than accidentally. Daily quests start nudging specific behaviours — "free 10 Silver-tier heroes," "merge to Gold three times." The first ascension is offered on the starter hero, teaching the meta-progression loop: heroes I upgrade between runs spawn at a higher tier inside the cluster. By D3 the player has cleared most of Realm 1 and the first boss-of-realm fight is on deck.

**D4–D7** open the social and economic layers. Realm 1 boss falls. Realm 2 unlocks with new enemy types and a stronger boss. A guild invite prompt appears. The first paid offer — a $4.99 starter pack with a guaranteed Silver-tier hero — surfaces. By D7 the player has their first Gold-tier hero, has joined a guild, and has watched a banner rotate at least once. The weekly battle pass is roughly half complete.

**D8–D14** is when the daily run cap actually starts to bite and the player has to choose what to spend energy on: clearing new realm stages, farming a specific hero for ascension, or qualifying for the weekend tournament. Multiple ascended heroes are in rotation. The team composition becomes a deliberate choice — front-line tanks, back-line ranged, support — rather than "whoever I unlocked." A ranked lanes mode unlocks at D14, giving committed players a reason to log in beyond the campaign. By the end of week two the player either has a roster they care about, or they've already churned.

---

### 7.2 Synthetic testing materials — Art

*Left blank intentionally for this revision. To be filled when art deliverables enter scope.*

| Artifact | Used by | Status | Notes |
| --- | --- | --- | --- |
| Mockup of gameplay screen | Stage 3 | **TBD** | All in-match elements visible — heroes, cluster, lane, HUD, environment. Single static frame a player could understand the game from. |
| Key art | Stage 3 + Stage 1b pairing | **TBD** | Marketing-style hero shot. Featured heroes. Image that leads a store listing. |
| Key UI frames | Stage 3 | **TBD** | Genre-conditional set: gameplay HUD, hero collection, hero upgrade / skill tree, gacha banner, realm map. |
| App store icon | Stage 3 | **TBD** | 1024×1024. Tests whether the concept reads at thumbnail size. |

### 7.3 Playable prototype

| Artifact | Used by | Status | Notes |
| --- | --- | --- | --- |
| Playable prototype | Greenlight gate | In progress — see `godot-prototype/` | Scope: one core-loop session end-to-end. No meta-loop, no monetization. Must be feel-representative on the bubble-shoot input and the drag-to-merge gesture. |
| Gameplay video (30–90s, beat-sliced) | Stage 4 | **TBD** | Cut from the prototype. Beats: first 30s onboarding, first win, first loss, first monetization touchpoint. Each beat scored separately. |

---

## 8. Greenlight checklist

- [ ] Hypotheses H1–H3 reviewed against latest evidence (§3)
- [ ] Core loop description signed off (§7.1.a)
- [ ] Core loop + meta description signed off (§7.1.b)
- [ ] Store-page variant signed off (§7.1.c)
- [ ] First 1–5 minutes signed off (§7.1.d)
- [ ] D1–D14 journey signed off (§7.1.e)
- [ ] Gameplay screen mockup approved (§7.2)
- [ ] Key art approved (§7.2)
- [ ] Key UI frames approved (§7.2)
- [ ] App store icon approved (§7.2)
- [ ] Playable prototype passes cluster–lane unification test (§5 risk 1, H3)
- [ ] Gameplay video cut and scored on all four beats (§7.3)
- [ ] Strategic risks reviewed against current build (§5)
