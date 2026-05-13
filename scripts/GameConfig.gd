# GameConfig — autoload singleton
#
# Single source of truth for every tuning value in v1.
# 1:1 mirror of design spec §3.10 (Tuning value summary).
# Change values here; do not hard-code in gameplay scripts.
#
# Designer note: every exported var is editable in the Inspector
# when you select the autoload in the project settings, OR via
# remote-tweak during play in the Godot debugger.

extends Node

# ============================================================
# §3.1 / 3.4 — Color palette (v1 has 3 of 5 colors enabled)
# ============================================================
enum BubbleColor { RED, BLUE, YELLOW }
# Reserved for v2: GREEN (heal), PURPLE (AOE/boss)
# NOTE: named BubbleColor (not Color) to avoid shadowing the built-in Color type.

const COLOR_HEX := {
	BubbleColor.RED:    "e74c3c",
	BubbleColor.BLUE:   "3498db",
	BubbleColor.YELLOW: "f1c40f",
}

# ============================================================
# §3.1 — Spatial layout (portrait, 720×1560 reference)
# ============================================================
@export_group("Layout")
@export var cluster_zone_pct: float = 0.55   # top 55%
@export var lane_zone_pct:    float = 0.30   # middle 30%
@export var hud_zone_pct:     float = 0.15   # bottom 15%

# ============================================================
# §3.2 — Cluster
# ============================================================
@export_group("Cluster")
@export var cluster_grid_width: int = 8         # columns
@export var cluster_grid_max_height: int = 12   # rows (cluster fails if exceeds)
@export var cluster_start_rows_s1_s2: int = 3
@export var cluster_start_rows_s3_s4: int = 5
@export var cluster_start_rows_s5:    int = 7   # boss
@export var cluster_descent_rate_sec: float = 8.0   # legacy time-based; unused since shot-triggered descent
@export var cluster_descent_pause_after_pop_sec: float = 1.0   # legacy; unused
@export var cluster_grow_trigger_misses: int = 8    # adds 1 row at top
@export var bubble_diameter_px: int = 72        # at 720-wide reference
# Shot-triggered descent (idle pacing — cluster only moves when player fires)
@export var cluster_descent_rows_per_shot_s1_s2: int = 2   # stage 1-2: ~6 shots to first conversion
@export var cluster_descent_rows_per_shot_s3_s4: int = 3   # stage 3-4: ~4 shots
@export var cluster_descent_rows_per_shot_s5:    int = 3   # boss: ~3 shots
@export var cluster_descent_pop_relief_rows: int = 1       # rows refunded when a shot results in a pop

# ============================================================
# §3.3 — Aim & fire
# ============================================================
@export_group("Aim & Fire")
@export var bubble_speed_px_per_sec: float = 1500.0
@export var fire_rate_cap_sec: float = 0.5      # min interval between shots
@export var aim_assist_enabled: bool = true     # locked ON v1
@export var aim_ricochet_count: int = 1         # walls bounced before attach
@export var queue_depth: int = 2                # current + on-deck

# ============================================================
# §3.4 — Hero spawn (match-size → tier)
# ============================================================
@export_group("Heroes — Tiers")
@export var bronze_hp: int = 100
@export var bronze_dmg: int = 10
@export var silver_hp: int = 150
@export var silver_dmg: int = 20
@export var gold_hp:   int = 200
@export var gold_dmg:  int = 30

# Class behavior — color → class mapping is locked.
# See combat-design.md §2 for per-class targeting zones + VFX.
@export_group("Heroes — Class Behavior")
# Fire Knight (RED) — close-range cone
@export var red_cone_rows: int = 4              # rows -4..0 in front of hero
@export var red_cone_cols: int = 1              # ±1 col around hero
@export var red_fire_rate_sec: float = 0.75
@export var red_dmg_mult: float = 1.0
@export var red_cleave_chance: float = 0.25
@export var red_cleave_targets: int = 2
# Ice Mage (BLUE) — column lob with AoE splash
@export var blue_col_radius: int = 1            # ±1 col primary target zone
@export var blue_reach_rows: int = 10           # rows -10..0
@export var blue_fire_rate_sec: float = 1.6
@export var blue_dmg_mult: float = 0.7
@export var blue_aoe_radius_cells: float = 1.5
@export var blue_slow_pct: float = 0.30         # 30% slow
@export var blue_slow_duration_sec: float = 2.0
# Archer (YELLOW) — full-column snipe
@export var yellow_reach_rows: int = 15         # rows -15..0 (full screen)
@export var yellow_fire_rate_sec: float = 1.2
@export var yellow_dmg_mult: float = 1.4
@export var yellow_execute_threshold: float = 0.30
@export var yellow_execute_bonus: float = 0.50

@export_group("Heroes — Color Rules")
@export var color_counter_multiplier: float = 2.0  # same-color hero vs enemy = 2× dmg
@export var color_frenzy_buff_pct: float = 0.50   # +50% damage on full-clear
@export var color_frenzy_duration_sec: float = 10.0

# ============================================================
# §3.6 — Enemies (v1: 3 types, 1 per color)
# ============================================================
@export_group("Enemies")
@export var red_enemy_hp:    int = 50
@export var red_enemy_speed_sec_per_cell: float = 1.0
@export var blue_enemy_hp:   int = 80
@export var blue_enemy_speed_sec_per_cell: float = 1.5
@export var yellow_enemy_hp: int = 120
@export var yellow_enemy_speed_sec_per_cell: float = 1.2
@export var red_enemy_damage_on_reach:    int = 10
@export var blue_enemy_damage_on_reach:   int = 10
@export var yellow_enemy_damage_on_reach: int = 15
# Variants (combat-design.md §3.2). "walker" = baseline.
@export var runner_hp_mult: float = 0.7
@export var runner_speed_mult: float = 0.6      # smaller sec/cell = faster
@export var brute_hp_mult: float = 2.0
@export var brute_speed_mult: float = 1.3       # bigger sec/cell = slower
@export var brute_dmg_mult: float = 1.5
# Per-stage scalars applied on top of color + variant (combat-design.md §3.3).
@export var stage_hp_mults: Array[float]  = [1.0, 1.1, 1.2, 1.35, 1.5]
@export var stage_dmg_mults: Array[float] = [1.0, 1.0, 1.05, 1.1, 1.2]

# ============================================================
# §3.7 — Special bubbles (v1: color bomb + hero bubbles)
# ============================================================
@export_group("Specials")
@export var color_bomb_cadence_shots_min: int = 12
@export var color_bomb_cadence_shots_max: int = 18
# Hero bubbles: matching one spawns a hero of its color. Regular matches no
# longer spawn heroes — only hero bubbles do. Count grows ~2-3 per stage so
# later stages can field a bigger army.
@export var hero_bubbles_per_stage: Array[int] = [3, 5, 8, 10, 13]
@export var hero_bubble_grow_chance: float = 0.0   # per bubble via _grow_top_row (off by default)

# ============================================================
# §3.8 — Player & stage
# ============================================================
@export_group("Player & Stage")
@export var stage_start_hp: int = 100
@export var stage_clear_no_enemies_sec: float = 2.0   # §3.10: 2s after last enemy death
@export var coins_per_stage_clear: int = 50           # in-run, logged only
@export var boss_hp: int = 1000
@export var boss_damage_on_reach: int = 50

# ============================================================
# §3.6 / §4.3 — Phase 2 wave script (V8: scripted, not derived from Phase 1)
# Wave composition per stage = array of enemy colors, spawned in order at
# `wave_spawn_interval_sec` apart, round-robin across lane columns.
# Boss for Stage 5 is appended after the walker wave — handled in MatchScene.
# ============================================================
@export_group("Phase Pacing")
@export var wave_spawn_interval_sec: float = 1.5
@export var phase_transition_sec: float = 1.0   # GET READY wipe duration

# OQ11 (§7.1) — hero carry-over toggle. true: surviving heroes carry forward
# with HP+cell preserved (default). false: each stage starts with an empty lane.
@export var carry_over_heroes_enabled: bool = true

# OQ10 (§7.1) — Phase 1 early-clear bonus. When > 0, clearing the cluster
# before the cap awards 1 Bronze hero per N seconds of cap remaining.
# 0 = no bonus (speed clearing is its own reward).
@export var phase1_early_clear_secs_per_bonus_hero: int = 0

@export var phase1_cap_s1: float = 45.0
@export var phase1_cap_s2: float = 50.0
@export var phase1_cap_s3: float = 60.0
@export var phase1_cap_s4: float = 65.0
@export var phase1_cap_s5: float = 75.0
@export var phase2_cap_s1: float = 30.0
@export var phase2_cap_s2: float = 35.0
@export var phase2_cap_s3: float = 45.0
@export var phase2_cap_s4: float = 50.0
@export var phase2_cap_s5: float = 90.0

# ============================================================
# §4.3 — Stage pacing (enemy spawn cadence, base — pre-conversion)
# ============================================================
@export_group("Stage Pacing")
@export var s1_enemy_spawn_sec: float = 8.0
@export var s2_enemy_spawn_sec: float = 6.0
@export var s3_enemy_spawn_sec: float = 5.0
@export var s4_enemy_spawn_sec: float = 4.0
@export var s5_enemy_spawn_sec: float = 3.0
@export var stage_max_duration_sec: float = 120.0     # soft cap for telemetry

# ============================================================
# §4.2 — Boon pool (v1 has 9 boons)
# ============================================================
const BOON_IDS := [
	"red_bias", "blue_bias", "yellow_bias",
	"red_dmg",  "blue_dmg",  "yellow_dmg",
	"extra_special", "faster_fire", "ricochet_plus",
]

# ============================================================
# Helpers (read-only)
# ============================================================
func get_stage_start_rows(stage_num: int) -> int:
	if stage_num <= 2: return cluster_start_rows_s1_s2
	if stage_num <= 4: return cluster_start_rows_s3_s4
	return cluster_start_rows_s5

func get_hero_bubble_count(stage_num: int) -> int:
	var idx: int = clamp(stage_num - 1, 0, hero_bubbles_per_stage.size() - 1)
	return hero_bubbles_per_stage[idx]

func get_stage_descent_rows_per_shot(stage_num: int) -> int:
	if stage_num <= 2: return cluster_descent_rows_per_shot_s1_s2
	if stage_num <= 4: return cluster_descent_rows_per_shot_s3_s4
	return cluster_descent_rows_per_shot_s5

func get_stage_spawn_rate_sec(stage_num: int) -> float:
	match stage_num:
		1: return s1_enemy_spawn_sec
		2: return s2_enemy_spawn_sec
		3: return s3_enemy_spawn_sec
		4: return s4_enemy_spawn_sec
		5: return s5_enemy_spawn_sec
		_: return s1_enemy_spawn_sec

func get_color_bomb_next_cadence() -> int:
	return randi_range(color_bomb_cadence_shots_min, color_bomb_cadence_shots_max)

func all_bubble_colors() -> Array:
	return [BubbleColor.RED, BubbleColor.BLUE, BubbleColor.YELLOW]

# §4.3 — Wave composition lookup. Returns Array of Dictionary entries:
#   { "color": BubbleColor, "variant": "walker" | "runner" | "brute" }
# Boss in Stage 5 is appended by MatchScene (not in this list).
# Variant mix per stage from combat-design.md §3.3.
func get_wave_composition(stage_num: int) -> Array:
	var R: int = BubbleColor.RED
	var B: int = BubbleColor.BLUE
	var Y: int = BubbleColor.YELLOW
	var W := "walker"
	var RUN := "runner"
	var BR := "brute"
	match stage_num:
		1:
			return [
				{"color": R, "variant": W}, {"color": R, "variant": W},
				{"color": R, "variant": W}, {"color": R, "variant": W},
				{"color": R, "variant": W},
			]
		2:
			return [
				{"color": R, "variant": W}, {"color": R, "variant": W},
				{"color": R, "variant": W}, {"color": R, "variant": W},
				{"color": B, "variant": W}, {"color": B, "variant": W},
			]
		3:
			return [
				{"color": R, "variant": W}, {"color": R, "variant": W},
				{"color": R, "variant": W}, {"color": R, "variant": W},
				{"color": B, "variant": W}, {"color": B, "variant": W},
				{"color": B, "variant": W},
				{"color": Y, "variant": W}, {"color": Y, "variant": RUN},
			]
		4:
			return [
				{"color": R, "variant": W}, {"color": R, "variant": W},
				{"color": R, "variant": W}, {"color": R, "variant": W},
				{"color": R, "variant": RUN},
				{"color": B, "variant": W}, {"color": B, "variant": W},
				{"color": B, "variant": W},
				{"color": Y, "variant": W}, {"color": Y, "variant": W},
				{"color": Y, "variant": BR},
			]
		5:
			return [
				{"color": R, "variant": W}, {"color": R, "variant": W},
				{"color": R, "variant": W}, {"color": R, "variant": W},
				{"color": R, "variant": RUN}, {"color": R, "variant": RUN},
				{"color": B, "variant": W}, {"color": B, "variant": W},
				{"color": B, "variant": W}, {"color": B, "variant": W},
				{"color": Y, "variant": W}, {"color": Y, "variant": W},
				{"color": Y, "variant": BR}, {"color": Y, "variant": BR},
			]
		_:
			return [{"color": R, "variant": W}]

func get_phase1_cap_sec(stage_num: int) -> float:
	match stage_num:
		1: return phase1_cap_s1
		2: return phase1_cap_s2
		3: return phase1_cap_s3
		4: return phase1_cap_s4
		5: return phase1_cap_s5
		_: return phase1_cap_s1

func get_phase2_cap_sec(stage_num: int) -> float:
	match stage_num:
		1: return phase2_cap_s1
		2: return phase2_cap_s2
		3: return phase2_cap_s3
		4: return phase2_cap_s4
		5: return phase2_cap_s5
		_: return phase2_cap_s1
