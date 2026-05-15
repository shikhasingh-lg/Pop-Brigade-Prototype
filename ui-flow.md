---
name: Pop Brigade — UI Flow
status: draft
created: 2026-05-11
updated: 2026-05-13
design_spec: ~/game-research/pop-brigade/design-spec.md
combat_doc: ~/game-research/pop-brigade/combat-design.md
---

# Pop Brigade — UI Flow

> **Scope:** Every screen needed for the v1 greybox playtest. No art direction — grayscale boxes only. The match screen gets the most detail because it's 80%+ of player time.

> **Architecture (recap):** Phased Build → Wave. Phase 1 has the move-budget counter + cluster + hero-bubble portraits. Phase 2 has cannon dimmed + draggable heroes + cluster-converted-enemy spawn at transition.

---

## 1. Screen inventory

| # | Screen | Purpose | Time budget |
|---|---|---|---|
| 1 | **Boot** | Logo + loading bar | 2 s passive |
| 2 | **Meta hub** | Single "Play" button + run counter | <5 s |
| 3 | **Loadout** | Pick starting cannon color bias (1 of 3) | 10 s |
| 4 | **Match** | The game itself — cluster + lane + HUD | 60-150 s per stage |
| 5 | **Pause** | Resume / Quit overlay | 2-5 s |
| 6 | **Stage clear** | Boon pick (1 of 3) | 10 s |
| 7 | **Stage fail** | End Run overlay | 5 s |
| 8 | **Run end** | Run results screen → back to Meta hub | 15 s |

**Out of v1:** Settings menu (use device defaults), audio toggle (system volume), tutorial overlay (testers will be guided verbally).

---

## 2. Wireflow

```
                       ┌────────────────┐
                       │  1. BOOT       │
                       │  (logo + load) │
                       └───────┬────────┘
                               │ auto after 2s
                               ▼
                       ┌────────────────┐
              ┌───────►│  2. META HUB   │◄──────┐
              │        │  [PLAY] btn    │       │
              │        └───────┬────────┘       │
              │                │ tap PLAY        │
              │                ▼                 │
              │        ┌────────────────┐       │
              │        │  3. LOADOUT    │       │
              │        │  3 cannon picks│       │
              │        └───────┬────────┘       │
              │                │ tap a cannon   │
              │                ▼                 │
              │        ┌─────────────────────┐  │
              │  ┌────►│  4. MATCH           │  │
              │  │     │  P1: Build → P2: Def│  │
              │  │     └─┬────┬──────┬───────┘  │
              │  │       │    │      │           │
              │  │  pause│ HP=0│  cleared        │
              │  │       ▼    ▼      ▼           │
              │  │   ┌─────┐ ┌─────┐ ┌──────┐   │
              │  │   │  5. │ │  7. │ │  6.  │   │
              │  │   │PAUSE│ │FAIL │ │CLEAR │   │
              │  │   └──┬──┘ └──┬──┘ └──┬───┘   │
              │  │      │       │       │        │
              │  │   resume   end run boon pick  │
              │  └──────┘       │       │        │
              │                 │       │        │
              │                 │  ┌────▼────┐   │
              │                 │  │ next    │   │
              │                 │  │ stage?  │   │
              │                 │  └─┬─────┬─┘   │
              │                 │  yes  no(boss done)
              │                 │   │     │     │
              │                 │   └► back to 4 (next stage)
              │                 │         │     │
              │                 ▼         ▼     │
              │           ┌──────────────────┐  │
              └───────────│   8. RUN END     │──┘
                          │  results + back  │
                          └──────────────────┘
```

**Trigger summary table:**
| From → To | Trigger |
|---|---|
| Boot → Meta hub | 2 s auto |
| Meta hub → Loadout | Tap "Play" |
| Loadout → Match (Stage 1) | Tap any cannon card |
| Match → Pause | Tap pause button |
| Pause → Match | Tap "Resume" |
| Pause → Run end | Tap "Quit Run" |
| Match P1 → Match P2 transition | Move budget = 0 OR cluster cleared OR cluster reaches row 0 (stage 4+) |
| Match → Stage clear | Wave defeated + 2 s grace (no enemies on lane) |
| Match → Stage fail | Player HP = 0 |
| Stage clear → Match (next stage) | Tap a boon card |
| Stage clear → Run end | Cleared Stage 5 (boss) |
| Stage fail → Run end | Tap "End Run" (no retry in v1 — keep instrumentation clean) |
| Run end → Meta hub | Tap "Continue" |

**v1 decision: no retry on stage fail.** Single attempt per run.

---

## 3. Per-screen low-fi wireframes

### 3.1 Boot (screen 1)
```
┌──────────────────────────────┐
│                              │
│                              │
│         POP BRIGADE          │
│         (greybox logo)       │
│                              │
│       ████░░░░░░░░░░ 40%     │
│         loading...           │
│                              │
└──────────────────────────────┘
```

### 3.2 Meta hub (screen 2)
```
┌──────────────────────────────┐
│  ⚙             POP BRIGADE   │
│                              │
│     Runs completed: 3        │
│                              │
│      ┌──────────────┐        │
│      │              │        │
│      │     PLAY     │        │
│      │              │        │
│      └──────────────┘        │
│                              │
│         (v1 build)           │
└──────────────────────────────┘
```

### 3.3 Loadout (screen 3)
```
┌──────────────────────────────┐
│  ◄  Choose your cannon       │
│                              │
│  ┌──────┐  ┌──────┐  ┌─────┐│
│  │  🔴  │  │  🔵  │  │  🟡 ││
│  │ Red  │  │ Blue │  │Yellw││
│  │ bias │  │ bias │  │bias ││
│  │+30%R │  │+30%B │  │+30%Y││
│  │bubbls│  │bubbls│  │bubls││
│  └──────┘  └──────┘  └─────┘│
│                              │
│         tap to start         │
└──────────────────────────────┘
```

---

### 3.4 Match (screen 4) — **most important**

**Phase 1 (BUILD) layout:**
```
┌──────────────────────────────┐
│ HP ████████░░  Stage 2/5   ⏸ │ ← Top HUD
│   ╔══════════════════════╗   │
│   ║   PHASE 1: BUILD     ║   │ ← Phase banner (blue P1 / red P2)
│   ╚══════════════════════╝   │
│                              │
│      [▓▓░░░░░] descent       │ ← Cluster descent bar (stages 4+ ONLY)
│                              │
├──────────────────────────────┤
│      ● ● ●(😊)● ● ● ●        │
│     ● ● ● ● ● ● ● ●          │ ← Cluster: normal bubbles + HERO BUBBLES
│      ● ●(😎)● ● ● ● ●        │   (face/portrait visible, always)
│     ● ● ● ● ● ● ● ●          │
│                              │
│ ⚔️ ⚔️ ⚔️ ⚔️ ⚔️ ⚔️ ⚔️ ⚔️    │
│ ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ ◄ spawn line — heroes idle here in P1
│                              │
│                              │ ← Lane rows 1-5 (empty during P1)
│                              │
├──────────────────────────────┤
│   MOVES: 7 / 10              │ ← MOVE BUDGET COUNTER (prominent)
│     ╭───╮  ┌─────┐ ┌─────┐  │
│     │ 🔴│  │  🔵 │ │  Q  │  │ ← Cannon ACTIVE in P1
│     ╰───╯  └─────┘ └─────┘  │
│      cannon  on-deck         │
└──────────────────────────────┘
```

**Phase 1 → Phase 2 transition (1 s "GET READY!" wipe):**
```
┌──────────────────────────────┐
│   ╔══════════════════════╗   │
│   ║                      ║   │
│   ║    GET READY!        ║   │
│   ║                      ║   │
│   ║  3 bubbles incoming  ║   │ ← Tells the player explicitly that
│   ║                      ║   │   leftover bubbles are becoming enemies
│   ╚══════════════════════╝   │   (Q1 causal-arc reinforcement)
└──────────────────────────────┘
```

During the wipe, every remaining cluster bubble visibly drops out of formation and turns into an enemy in the same column. Stagger 80 ms per bubble so the player can read each conversion.

**Phase 2 (DEFEND) layout:**
```
┌──────────────────────────────┐
│ HP ████████░░  Stage 2/5   ⏸ │
│   ╔══════════════════════╗   │
│   ║   PHASE 2: DEFEND    ║   │ ← Phase banner red
│   ╚══════════════════════╝   │
│        👹    👹              │ ← Cluster-converted enemies + scripted
│       (falling from cluster)  │   wave both falling from top
├──────────────────────────────┤
│                              │   Cluster zone EMPTY in P2
│                              │
│                              │
│                              │
│ ⚔️ ⚔️ ⚔️ ⚔️ ⚔️ ⚔️ ⚔️ ⚔️    │ ← Heroes auto-firing; DRAG to reposition
│ ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬       │
│         👹                    │ ← Enemies marching top → cannon
│              👹              │
├──────────────────────────────┤
│   (no moves counter)         │
│     ╭───╮  ┌─────┐ ┌─────┐  │
│     │░░░│  │░░░░░│ │░░░░░│  │ ← Cannon DIMMED + tap-inert in P2
│     ╰───╯  └─────┘ └─────┘  │
└──────────────────────────────┘
```

**Hero drag interaction (Phase 2 only):**
```
   Player presses-and-holds a hero on row 0:
   
   ┌──────────────────────────────┐
   │ (cluster empty)              │
   │                              │
   │ ⚔️ ⚔️ ⚔️ ⚔️ [⚔️] ⚔️ ⚔️ ⚔️  │ ← ghost outline shows where hero
   │ ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬       │   will land. Column highlights.
   │                              │   Any row-0 hero of the SAME class +
   │                              │   SAME tier as the lifted hero gets a
   │                              │   pulsing tier-colour glow (merge target).
   │ (cannon dimmed: P2 anyway)   │
   └──────────────────────────────┘
   
   Release on empty col:                hero moves there.
   Release on same-class + same-tier:   MERGE → one hero of next tier
                                        (B+B → S, S+S → G). Source cell empties.
                                        Brief flash + tier-coloured glow + scale-up.
   Release on any other occupied col:   heroes swap places.
```

**HUD elements (annotated):**

| Element | Position | Behavior | Why it's here |
|---|---|---|---|
| HP bar | Top-left | Decrements when enemy reaches cannon (P2 only); flashes red on hit | Constant HP awareness |
| Stage indicator | Top-center | "Stage N/5" + sub-text "BUILD" / "DEFEND" + wave-remaining count in P2 | Pacing feedback |
| **Phase banner** | Below HUD | Persistent: blue "PHASE 1: BUILD" or red "PHASE 2: DEFEND" | Critical readability — testers must always know which phase |
| **Move budget counter** | **Two locations, P1 only:** primary above cannon (large "MOVES: 7 / 10"); secondary echo number painted on the cannon barrel itself. | Decrements with each shot. Multi-channel low-moves warning kicks in at ≤5 (see "Low-moves urgency" below). | The phase-1 fail clock is moves, not time. Echo on barrel keeps eyes in the aim zone. |
| **Cluster descent bar** | Top of cluster zone, stages 4+ ONLY | Thin progress bar to next descent tick | Telegraphs the secondary P1 pressure |
| Pause btn | Top-right | Opens Pause overlay | Standard mobile |
| Cluster grid | Upper 55% | Hex grid of bubbles + hero bubbles (face/portrait overlay, glow ring). **Empty in P2.** | Bubble shooter playfield + hero gacha shelf |
| Spawn line | Mid-screen | Glowing horizontal. **Heroes stand on this line.** | Dual purpose: hero defense line + cluster-descent fail line |
| Lane | Middle 30% | Row 0 = heroes (idle in P1, draggable in P2); rows 1-5 = enemy march path (P2 only) | Hero positioning + enemy path |
| Cannon | Bottom-center | **Active P1 (glowing). Dimmed + tap-inert in P2.** | Primary input (P1 only) |
| On-deck bubble | Right of cannon, P1 only | Tap to swap with current | Swap is core skill expression |
| Color frenzy indicator | Screen-edge tint pulse on trigger + hero aura during P2 buff | Edge pulses on full color clear; aura persists during P2 wave | Reward feedback across phases |

**Match screen design rules (lock for v1):**
1. **No tutorial overlay.** Testers guided verbally.
2. **Cluster + lane share visual language.** Same colour palette; colour is a chaining mechanic, NOT hero class.
3. **Phase banner unmistakable.** Color + text. Mid-screen wipe between phases must be impossible to miss.
4. **Conversion VFX is the Q1 hook.** Each leftover bubble visibly drops out of cluster and becomes an enemy in the same column at transition. This is the moment that sells "the bubbles I didn't pop are the wave I'm fighting."
5. **Move counter is the P1 fail clock.** Must be prominent — testers need to feel "running out" tension. Top-corner placement does NOT count as prominent (eyes are on cannon + cluster during P1). Counter lives above the cannon AND echoes on the cannon barrel, with multi-channel urgency at ≤5 moves.
6. **Hero drag affordance only in P2.** Cannon dimmed signals "now you can reposition."
7. **No purchase buttons, no ads, no popups, no daily reward.** v1 is pure mechanic test.

**Low-moves urgency (multi-channel warning ladder):**

Players ignore a quiet number in the corner. Once `moves_remaining ≤ 5`, escalate across **four channels** (visual, motion, haptic, audio) on a rising ladder so the warning is impossible to miss without being noisy at higher move counts.

| Moves left | Visual | Motion | Haptic | Audio |
|---|---|---|---|---|
| **6+** | Counter neutral white | Static | — | — |
| **5** (yellow alert) | Counter + barrel echo turn **yellow** | Counter pulses 1×/sec; center-screen toast **"5 MOVES LEFT!"** for 1.2 s (one-shot, never repeats) | Single light tick | Soft "tick" SFX layer starts (1 Hz, low volume) |
| **3** (red alert) | Counter + barrel echo turn **red**; cannon glow shifts to amber | Counter pulses 2×/sec; second one-shot toast **"3 MOVES LEFT!"** 1.2 s | Medium tick at the moment of transition | Tick SFX picks up to 2 Hz, gains a sharper attack |
| **1** (critical) | Counter scales to **1.3×**, deep red; screen-edge **red vignette** pulse once | Counter pulses 3×/sec | Sharp haptic accent | Tick SFX peaks at 3 Hz; one urgent musical sting on the transition into "1 left" |

Rules:
- Toasts are one-shot per stage (not per-frame). If the player gains moves back via an "Extra Moves" boon and crosses the threshold again, toasts re-arm and can fire once more.
- Color states are sticky going down (5 → 3 → 1) but reset cleanly to white if moves are added back above 6.
- Haptic and the urgent sting respect the OS mute / system haptic-off settings.
- The on-barrel echo number is the smallest channel but always present — guarantees the player sees the number even when their eyes never leave the aim zone.

---

### 3.5 Pause (screen 5)
```
┌──────────────────────────────┐
│         (match dimmed)       │
│         ┌────────────┐       │
│         │  PAUSED    │       │
│         │ [RESUME]   │       │
│         │ [QUIT RUN] │       │
│         └────────────┘       │
└──────────────────────────────┘
```

### 3.6 Stage clear (screen 6)
```
┌──────────────────────────────┐
│         STAGE 2 CLEAR        │
│                              │
│       Pick one boon:         │
│                              │
│  ┌──────┐ ┌──────┐ ┌──────┐ │
│  │ +30% │ │ +2   │ │Hero  │ │
│  │  RED │ │MOVES │ │Bubble│ │
│  │bubbls│ │nxt st│ │ +50% │ │
│  │      │ │      │ │nxt st│ │
│  └──────┘ └──────┘ └──────┘ │
│                              │
│        tap to continue       │
└──────────────────────────────┘
```

### 3.7 Stage fail (screen 7)
```
┌──────────────────────────────┐
│        (match dimmed)        │
│         ┌────────────┐       │
│         │ STAGE FAIL │       │
│         │            │       │
│         │ Reached    │       │
│         │ Stage 3/5  │       │
│         │            │       │
│         │ [END RUN]  │       │
│         └────────────┘       │
└──────────────────────────────┘
```
No retry in v1 — clean instrumentation.

### 3.8 Run end (screen 8)
```
┌──────────────────────────────┐
│          RUN COMPLETE        │
│                              │
│   Stages cleared:   5 / 5   │
│   Total moves used: 64      │
│   Heroes freed:     12      │
│   Hero drags (P2):   8      │
│   Cluster leftovers: 7      │ ← The Q1 metric — fewer = better play
│   Enemies defeated: 67      │
│   Color frenzies:    2      │
│   Best chain:        6      │
│                              │
│      [CONTINUE]              │
└──────────────────────────────┘
```
Stats also logged to telemetry. **"Cluster leftovers" is a Q1-relevant stat** — players who connect Phase 1 leftovers to Phase 2 difficulty will minimize this number.

---

## 4. Match screen HUD spec — readability checklist

Before greybox is shown to testers, every item below must be true:

| Check | Pass criteria |
|---|---|
| Phase banner is unmistakable | Tester always knows which phase; can point within 3 s |
| Move-budget counter is felt | Tester adjusts strategy as moves run low (e.g., "I have 2 moves, I should pick carefully") |
| Hero bubbles are unmistakable | Tester points one out within 5 s when asked "what's the bubble with the face?" |
| **Conversion-at-transition reads as causal** | Tester points to leftover bubbles becoming enemies and describes "those came from up there" |
| Cluster descent indicator (stage 4+) is felt | Tester reacts when descent timer fills |
| Drag affordance (P2) is intuitive | Tester drags a hero without verbal prompting |
| Cannon-disabled in P2 is clear | Tester does not repeatedly try to fire during P2 |
| Hero color → class is learnable in 1 stage | After Stage 1, tester can predict role from colour |
| HP loss is felt | Tester reacts to HP bar drop within 1 s |
| Color frenzy reward is noticed | Tester comments on screen tint OR carryover buff |

If 4+ fail, the match-screen layout is wrong — not the mechanic.

---

## 5. Asset checklist for v1 greybox

**Sprites (placeholder shapes OK):**
- 1 bubble (3 colors via tint)
- 1 **hero bubble overlay** — face/portrait icon + glow ring
- 1 hero unit (3 classes via tint, tier shown as 1/2/3 stars overlay)
- 1 enemy unit (3 colors via tint, 3 variants via outline/scale)
- 1 boss unit
- 1 cannon
- 1 spawn-line glow strip
- 1 color-bomb (rainbow gradient)
- 1 cluster descent timer bar (stages 4+)

**UI:**
- HP bar
- Stage indicator text
- **Phase banner** (BUILD blue / DEFEND red)
- **Move budget counter** (prominent number "7 / 10")
- Cluster descent bar (stages 4+)
- Pause icon
- Boon cards (3 generic card frames + text)
- Buttons (Play, Resume, Quit, Continue, End Run)

**VFX (minimum viable):**
- Pop burst (3 colors)
- **Hero-bubble pop** — face-burst, hero emerges with brief scale-up + glow ring before settling onto row 0
- **Hero merge** — two heroes pull together over 0.4 s, brief flash, merged hero scale-up + tier-coloured glow ring (Silver = silver-blue, Gold = gold-orange). Source cell empties. Same VFX in P1 (auto-merge) and P2 (drag-merge)
- **Merge-target highlight (P2)** — during a drag-lift, any row-0 hero matching class + tier pulses with a tier-coloured glow to telegraph "this is mergeable"
- Falling bubble (gravity + fade)
- Hero spawn flash
- **Hero idle bobble (P1)** + **drag-lift (P2)** — hero lifts ~6 px, column highlights as ghost
- **Phase transition wipe** ("GET READY!" + conversion preview)
- **Cluster-converted enemy spawn** — bubble visibly drops out of formation, becomes an enemy in same column
- Enemy hit (color flash)
- Color frenzy screen tint
- **Cluster descent tick** (stages 4+) — cluster nudges down 1 row + small pulse
- **Boss cluster shake** (stage 5) — bigger nudge + screen shake every 15 s
- HP loss screen shake

**Audio (optional v1, recommended v1.1):**
- Bubble fire SFX, pop SFX (3 colors), hero-bubble break SFX (distinct), hero spawn SFX, drag-lift SFX, **merge stinger (tier-coloured, distinct from spawn)**, phase transition stinger, conversion VFX SFX, enemy death SFX, HP loss SFX, color frenzy stinger.

---

## 6. Open UI questions (resolve before greybox build)

| Question | Owner | Deadline |
|---|---|---|
| Move budget display style: countdown ("MOVES: 7") vs ammo dots ("●●●●●●●○○○") vs both | Designer | W1 |
| Cluster width: 5 / 6 columns by tier — readability on small phones | Designer | W1 prototype on small device |
| Hero-bubble portrait treatment — generic face icon vs class-specific silhouette in greybox | Designer | W1 |
| Phase transition wipe length: 1 s "GET READY!" vs 2 s with full conversion preview | Engineer + Designer | W2 — the longer wipe might help Q1 |
| Cluster-converted enemy visual: distinct ("angry bubble") vs identical to walkers | Designer | W2 — distinct strengthens Q1 |
| Drag affordance — column highlight follow finger vs snap-to-column | Engineer + Designer | W2 |
| Cluster descent indicator (stages 4+): thin bar vs bubble glow when near spawn line | Designer | W3 |
| Color-frenzy buff visual: tinted screen edges + hero glow | Designer | W2 |
| Stage fail copy — "HP depleted" vs "your line broke" / specific cause label | Designer | W4 |
| Cannon dim treatment in P2: just dim or "WATCHING" label | Designer | W2 |
