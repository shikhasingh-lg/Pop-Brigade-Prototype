# GameConfig — autoload singleton
#
# Single source of truth for every tuning value.
# Mirrors design spec §3.10 (cross-realm scaling) + §8.2-§8.6 (realm content).

extends Node

# ============================================================
# §3.1 / 3.4 — Color palette (5 colors total, 3-5 active per realm)
# ============================================================
enum BubbleColor { RED, BLUE, YELLOW, GREEN, PURPLE }

const COLOR_HEX := {
	BubbleColor.RED:    "e74c3c",
	BubbleColor.BLUE:   "3498db",
	BubbleColor.YELLOW: "f1c40f",
	BubbleColor.GREEN:  "27ae60",
	BubbleColor.PURPLE: "9b59b6",
}

# ============================================================
# §3.1 — Spatial layout (portrait, 720×1560 reference)
# ============================================================
@export_group("Layout")
@export var cluster_zone_pct: float = 0.55
@export var lane_zone_pct:    float = 0.30
@export var hud_zone_pct:     float = 0.15

# ============================================================
# §9.3 — Mode preset. playtest_mode = heroes ship at simulated L15 (1.60×
# base stats) so R3-R5 are beatable without meta progression.
# ============================================================
@export_group("Mode")
@export var playtest_mode: bool = true
@export var playtest_level_mult: float = 1.60   # §3.10.6 L15

# ============================================================
# §3.2 — Cluster (legacy R1 values kept for backward compat; realm helpers below)
# ============================================================
@export_group("Cluster")
@export var cluster_grid_width: int = 11
@export var cluster_grid_max_height: int = 12
@export var cluster_start_rows_s1_s2: int = 3
@export var cluster_start_rows_s3_s4: int = 5
@export var cluster_start_rows_s5:    int = 7
@export var cluster_descent_rate_sec: float = 8.0
@export var cluster_descent_pause_after_pop_sec: float = 1.0
@export var cluster_grow_trigger_misses: int = 8
@export var bubble_diameter_px: int = 72
@export var cluster_descent_rows_per_shot_s1_s2: int = 0
@export var cluster_descent_rows_per_shot_s3_s4: int = 0
@export var cluster_descent_rows_per_shot_s5:    int = 0
@export var cluster_descent_pop_relief_rows: int = 0

# Legacy R1 move budget. Realm-aware version below.
@export var move_budget_per_stage: Array[int] = [8, 9, 10, 11, 13]

# ============================================================
# §3.10.1 — Cluster + move budget per realm
# Rows per realm × stage (cols come from realm_cluster_cols).
# ============================================================
const REALM_CLUSTER_ROWS: Array = [
	[4, 4, 5, 6, 7],   # R1
	[5, 5, 6, 7, 8],   # R2
	[5, 6, 7, 7, 8],   # R3
	[6, 7, 8, 8, 9],   # R4
	[7, 8, 8, 9, 10],  # R5
]
const REALM_CLUSTER_COLS_BY_STAGE: Array = [
	# Stage 1..5; for R1/R2 narrower in S1-3 then widens, R3+ fixed 6.
	[5, 5, 5, 6, 6],   # R1
	[5, 5, 5, 6, 6],   # R2
	[6, 6, 6, 6, 6],   # R3
	[6, 6, 6, 6, 6],   # R4
	[6, 6, 6, 6, 6],   # R5
]
const REALM_MOVE_BUDGET: Array = [
	[8, 9, 10, 11, 13],     # R1
	[12, 13, 15, 17, 18],   # R2
	[14, 15, 17, 19, 20],   # R3
	[16, 17, 19, 21, 22],   # R4
	[18, 19, 21, 22, 24],   # R5
]

# §3.10.2 hero-bubble density per realm (1 in N bubbles).
const REALM_HERO_DENSITY_DIVISOR: Array = [8, 8, 9, 9, 10]

# §3.10.4 enemy scaling per realm.
const REALM_MULT_HP:       Array = [1.00, 1.35, 1.80, 2.40, 3.20]
const REALM_MULT_DMG:      Array = [1.00, 1.35, 1.80, 2.40, 3.20]
# NOTE: applied as sec_per_cell *= mult, so values < 1 = FASTER. R5 = ~27% faster than R1.
const REALM_MULT_SPEED:    Array = [1.00, 0.94, 0.87, 0.80, 0.73]
const REALM_MULT_ATKRATE:  Array = [1.00, 1.10, 1.20, 1.30, 1.42]

# §8.x realm metadata
const REALM_NAMES: Array = [
	"Skyline", "Storm Reach", "Verdant Maze", "Falling Spire", "Voidcrown"
]
const REALM_THEME_COLORS: Array[Color] = [
	Color(0.55, 0.78, 0.95),   # R1 sky
	Color(0.40, 0.42, 0.70),   # R2 storm
	Color(0.30, 0.62, 0.35),   # R3 verdant
	Color(0.70, 0.45, 0.32),   # R4 falling spire
	Color(0.50, 0.30, 0.70),   # R5 voidcrown
]
const BOSS_NAMES: Array = [
	"Sludge Lord", "Storm Tyrant", "Verdant Warden", "Spire Ravager", "Voidcrown Twins"
]
const BOSS_COLORS: Array = [
	BubbleColor.RED,     # R1
	BubbleColor.BLUE,    # R2 (yellow heroes counter)
	BubbleColor.GREEN,   # R3
	BubbleColor.RED,     # R4
	BubbleColor.YELLOW,  # R5 — Lumen first (phase B = purple Umbra)
]

# §8.6 — realm-specific phase-B boss color (only R5 uses it for now).
const BOSS_PHASE_B_COLORS: Array = [
	-1, -1, -1, -1, BubbleColor.PURPLE,
]

# ============================================================
# §3.3 — Aim & fire
# ============================================================
@export_group("Aim & Fire")
@export var bubble_speed_px_per_sec: float = 1500.0
@export var fire_rate_cap_sec: float = 0.5
@export var aim_assist_enabled: bool = true
@export var aim_ricochet_count: int = 1
@export var queue_depth: int = 2

# ============================================================
# §3.4 — Hero spawn (match-size → tier)
# ============================================================
@export_group("Heroes — Tiers")
@export var bronze_hp: int = 100
@export var bronze_dmg: int = 6
@export var silver_hp: int = 150
@export var silver_dmg: int = 8
@export var gold_hp:   int = 200
@export var gold_dmg:  int = 12

@export var tier_silver_match_threshold: int = 6
@export var tier_gold_match_threshold: int = 10

@export_group("Heroes — Class Behavior")
# Fire Knight (RED) — close-range cone
@export var red_cone_rows: int = 4
@export var red_cone_cols: int = 1
@export var red_fire_rate_sec: float = 0.5
@export var red_dmg_mult: float = 1.0
@export var red_cleave_chance: float = 0.25
@export var red_cleave_targets: int = 2
# Ice Mage (BLUE) — column lob with AoE splash
@export var blue_col_radius: int = 1
@export var blue_reach_rows: int = 10
@export var blue_fire_rate_sec: float = 1.0
@export var blue_dmg_mult: float = 0.7
@export var blue_aoe_radius_cells: float = 1.5
@export var blue_slow_pct: float = 0.30
@export var blue_slow_duration_sec: float = 2.0
# Archer (YELLOW) — full-column snipe
@export var yellow_reach_rows: int = 15
@export var yellow_fire_rate_sec: float = 0.8
@export var yellow_dmg_mult: float = 1.4
@export var yellow_execute_threshold: float = 0.30
@export var yellow_execute_bonus: float = 0.50
# Druid (GREEN, R3) — mid-range chain-heal support (§8.4)
@export var green_reach_rows: int = 6
@export var green_col_radius: int = 1
@export var green_fire_rate_sec: float = 0.7
@export var green_dmg_mult: float = 0.9
@export var green_chain_heal_amount: int = 5
@export var green_chain_heal_targets: int = 2
@export var green_heal_per_hero_cap_per_sec: int = 15
# Wizard (PURPLE, R5) — full-lane AOE burst (§8.6)
@export var purple_reach_rows: int = 15
@export var purple_fire_rate_sec: float = 1.4
@export var purple_dmg_mult: float = 2.5
@export var purple_aoe_radius_cells: float = 1.5
@export var purple_burst_every_n_hits: int = 5

@export_group("Heroes — Color Rules")
@export var color_counter_multiplier: float = 2.0
@export var color_frenzy_buff_pct: float = 0.50
@export var color_frenzy_duration_sec: float = 10.0

# ============================================================
# §3.6 — Enemies (5-color baseline; realm mults applied on top)
# ============================================================
@export_group("Enemies")
@export var red_enemy_hp:    int = 50
@export var red_enemy_speed_sec_per_cell: float = 0.55
@export var blue_enemy_hp:   int = 80
@export var blue_enemy_speed_sec_per_cell: float = 0.9
@export var yellow_enemy_hp: int = 120
@export var yellow_enemy_speed_sec_per_cell: float = 0.7
@export var green_enemy_hp: int = 65
@export var green_enemy_speed_sec_per_cell: float = 0.55
@export var purple_enemy_hp: int = 75
@export var purple_enemy_speed_sec_per_cell: float = 0.65
@export var red_enemy_damage_on_reach:    int = 10
@export var blue_enemy_damage_on_reach:   int = 10
@export var yellow_enemy_damage_on_reach: int = 15
@export var green_enemy_damage_on_reach:  int = 8
@export var purple_enemy_damage_on_reach: int = 12
# Variants (combat-design.md §3.2). "walker" = baseline.
@export var runner_hp_mult: float = 0.7
@export var runner_speed_mult: float = 0.6
@export var brute_hp_mult: float = 2.0
@export var brute_speed_mult: float = 1.3
@export var brute_dmg_mult: float = 1.5
# §3.10.5 — variant-specific base stats.
@export var shielder_shield_hits: int = 2
@export var shielder_hp_mult: float = 1.2
@export var shielder_speed_mult: float = 1.1
@export var healer_heal_per_sec: int = 5
@export var healer_radius_cells: float = 3.0
@export var healer_hp_mult: float = 1.0
@export var accelerator_speed_buff_pct: float = 0.50
@export var accelerator_speed_buff_duration_sec: float = 5.0
@export var accelerator_buff_target_count: int = 2
@export var phaser_phase_interval_min_sec: float = 4.0
@export var phaser_phase_interval_max_sec: float = 6.0
@export var phaser_skip_rows: int = 1                # extra rows skipped
# §3.10.4 — stage multipliers within realm.
@export var stage_hp_mults: Array[float]  = [1.0, 1.2, 1.45, 1.75, 2.10]
@export var stage_dmg_mults: Array[float] = [1.0, 1.1, 1.25, 1.4, 1.6]
# sec/cell mult — lower = faster. ~20% faster by S5.
@export var stage_speed_mults: Array[float] = [1.0, 0.95, 0.90, 0.85, 0.80]

# ============================================================
# §3.7 — Special bubbles
# ============================================================
@export_group("Specials")
@export var color_bomb_cadence_shots_min: int = 12
@export var color_bomb_cadence_shots_max: int = 18
@export var hero_bubble_count_weights: Array[float] = [0.20, 0.30, 0.30, 0.20]
@export var hero_bubble_grow_chance: float = 0.0

# ============================================================
# §3.8 — Player & stage
# ============================================================
@export_group("Player & Stage")
@export var stage_start_hp: int = 100
# Tower HP scales per realm so endgame enemy DMG doesn't one-shot the base.
const REALM_TOWER_HP: Array = [100, 130, 160, 200, 250]
@export var stage_clear_no_enemies_sec: float = 2.0
@export var coins_per_stage_clear: int = 50
@export var boss_hp: int = 1000
@export var boss_damage_on_reach: int = 50
@export var boss_hp_mult: float = 1.5             # §3.10.4 boss +50% HP over realm mult

# ============================================================
# §3.10 — Realm gimmicks
# ============================================================
@export_group("Realm Gimmicks")
# Cluster shake — every N seconds during P1, descend 1 row.
@export var cluster_shake_interval_sec: float = 18.0
# R4 descent cadences per stage (sec/row). 0 = no descent.
const R4_DESCENT_SEC_PER_ROW: Array = [10.0, 9.0, 8.0, 7.0, 6.0]
# R5 descent cadences per stage (only S3-5 have descent).
const R5_DESCENT_SEC_PER_ROW: Array = [0.0, 0.0, 8.0, 8.0, 8.0]
# Storm Tyrant (R2S5)
@export var storm_tyrant_zap_interval_sec: float = 8.0
@export var storm_tyrant_zap_telegraph_sec: float = 2.0
@export var storm_tyrant_zap_active_sec: float = 4.0
@export var storm_tyrant_zap_damage_mult: float = 1.5
# Verdant Warden (R3S5)
@export var warden_vine_root_hp: int = 200
@export var warden_vine_pillar_interval_sec: float = 12.0
@export var warden_damage_taken_while_vines_alive: float = 0.50
@export var warden_damage_dealt_while_vines_alive: float = 1.25
# Spire Ravager (R4S5)
@export var ravager_slam_interval_sec: float = 10.0
@export var ravager_slam_telegraph_sec: float = 2.0
# Voidcrown Twins (R5S5)
@export var twins_phase_b_trigger_hp_pct: float = 0.50
@export var twins_synergy_heal_per_sec: int = 10
@export var twins_synergy_dmg_bonus_pct: float = 0.15
@export var twins_lumen_beam_interval_sec: float = 7.0
@export var twins_lumen_beam_telegraph_sec: float = 1.5
@export var twins_umbra_swap_interval_sec: float = 8.0
# Echo of Voidcrown (R5S3 mini-boss)
@export var echo_hp: int = 1500
@export var echo_damage_on_reach: int = 60
@export var echo_phaser_spawn_interval_sec: float = 6.0

# ============================================================
# §3.6 / §4.3 — Phase pacing
# ============================================================
@export_group("Phase Pacing")
@export var phase_transition_sec: float = 1.0
@export var carry_over_heroes_enabled: bool = true
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
# §4.3 — Stage pacing
# ============================================================
@export_group("Stage Pacing")
# Per-stage wave spawn cadence (seconds between enemy spawns). Consumed by
# MatchScene wave loop via get_stage_spawn_rate_sec(stage_num). Tightens ~40%
# from S1 to S5 — combines with HP×1.5 and damage×1.2 ramp.
@export var s1_enemy_spawn_sec: float = 1.5
@export var s2_enemy_spawn_sec: float = 1.35
@export var s3_enemy_spawn_sec: float = 1.2
@export var s4_enemy_spawn_sec: float = 1.05
@export var s5_enemy_spawn_sec: float = 0.9
@export var stage_max_duration_sec: float = 120.0

# ============================================================
# Helpers — legacy (stage-only)
# ============================================================
func get_stage_start_rows(stage_num: int) -> int:
	if stage_num <= 2: return cluster_start_rows_s1_s2
	if stage_num <= 4: return cluster_start_rows_s3_s4
	return cluster_start_rows_s5

func get_hero_bubble_count(stage_num: int) -> int:
	if hero_bubble_count_weights.is_empty():
		return max(1, _hero_bubble_stage_min(stage_num))
	var total: float = 0.0
	for w in hero_bubble_count_weights:
		total += w
	if total <= 0.0:
		return max(1, _hero_bubble_stage_min(stage_num))
	var roll: float = randf() * total
	var acc: float = 0.0
	var rolled: int = hero_bubble_count_weights.size()
	for i in range(hero_bubble_count_weights.size()):
		acc += hero_bubble_count_weights[i]
		if roll <= acc:
			rolled = i + 1
			break
	return max(rolled, _hero_bubble_stage_min(stage_num))

func _hero_bubble_stage_min(stage_num: int) -> int:
	return 2 if stage_num == 1 else 1

func get_stage_descent_rows_per_shot(stage_num: int) -> int:
	if stage_num <= 2: return cluster_descent_rows_per_shot_s1_s2
	if stage_num <= 4: return cluster_descent_rows_per_shot_s3_s4
	return cluster_descent_rows_per_shot_s5

func get_stage_move_budget(stage_num: int) -> int:
	var idx: int = clamp(stage_num - 1, 0, move_budget_per_stage.size() - 1)
	return move_budget_per_stage[idx]

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

# Legacy 3-color palette (kept for code paths that don't yet route through realm).
func all_bubble_colors() -> Array:
	return [BubbleColor.RED, BubbleColor.BLUE, BubbleColor.YELLOW]

# §3.10.3 — colors available in the cluster per realm. Class-color reveal is
# chapter-gated: R1/R2 = RBY, R3/R4 = +Green, R5 = +Purple.
func get_palette_for_realm(realm: int) -> Array:
	var base: Array = [BubbleColor.RED, BubbleColor.BLUE, BubbleColor.YELLOW]
	if realm >= 3: base.append(BubbleColor.GREEN)
	if realm >= 5: base.append(BubbleColor.PURPLE)
	return base

# ============================================================
# Helpers — realm-aware
# ============================================================
func clamp_realm(r: int) -> int:
	return clamp(r, 1, RunState.REALM_COUNT)

func clamp_stage(s: int) -> int:
	return clamp(s, 1, RunState.STAGES_PER_REALM)

func realm_name(realm: int) -> String:
	var idx: int = clamp_realm(realm) - 1
	return String(REALM_NAMES[idx])

func realm_theme_color(realm: int) -> Color:
	var idx: int = clamp_realm(realm) - 1
	return REALM_THEME_COLORS[idx]

func boss_name(realm: int) -> String:
	var idx: int = clamp_realm(realm) - 1
	return String(BOSS_NAMES[idx])

func boss_color_for_realm(realm: int) -> int:
	var idx: int = clamp_realm(realm) - 1
	return int(BOSS_COLORS[idx])

func boss_phase_b_color(realm: int) -> int:
	var idx: int = clamp_realm(realm) - 1
	return int(BOSS_PHASE_B_COLORS[idx])

func get_realm_cluster_rows(realm: int, stage: int) -> int:
	var r: int = clamp_realm(realm) - 1
	var s: int = clamp_stage(stage) - 1
	return int(REALM_CLUSTER_ROWS[r][s])

func get_realm_cluster_cols(realm: int, stage: int) -> int:
	var r: int = clamp_realm(realm) - 1
	var s: int = clamp_stage(stage) - 1
	return int(REALM_CLUSTER_COLS_BY_STAGE[r][s])

func get_realm_move_budget(realm: int, stage: int) -> int:
	var r: int = clamp_realm(realm) - 1
	var s: int = clamp_stage(stage) - 1
	return int(REALM_MOVE_BUDGET[r][s])

func get_realm_hero_density(realm: int) -> int:
	var idx: int = clamp_realm(realm) - 1
	return int(REALM_HERO_DENSITY_DIVISOR[idx])

# §3.10.4 — realm × stage scaling lookups.
func get_realm_hp_mult(realm: int) -> float:
	return float(REALM_MULT_HP[clamp_realm(realm) - 1])

func get_realm_dmg_mult(realm: int) -> float:
	return float(REALM_MULT_DMG[clamp_realm(realm) - 1])

func get_realm_speed_mult(realm: int) -> float:
	return float(REALM_MULT_SPEED[clamp_realm(realm) - 1])

func get_realm_atkrate_mult(realm: int) -> float:
	return float(REALM_MULT_ATKRATE[clamp_realm(realm) - 1])

func get_stage_hp_mult(stage: int) -> float:
	var i: int = clamp(stage - 1, 0, stage_hp_mults.size() - 1)
	return float(stage_hp_mults[i])

func get_stage_dmg_mult(stage: int) -> float:
	var i: int = clamp(stage - 1, 0, stage_dmg_mults.size() - 1)
	return float(stage_dmg_mults[i])

func get_stage_speed_mult(stage: int) -> float:
	var i: int = clamp(stage - 1, 0, stage_speed_mults.size() - 1)
	return float(stage_speed_mults[i])

func get_realm_tower_hp(realm: int) -> int:
	return int(REALM_TOWER_HP[clamp_realm(realm) - 1])

# §3.10.4 boss HP/dmg per realm. Damage = 50 × realm_dmg_mult. HP = 1000 × realm_hp_mult × 1.5 boss bump.
func get_realm_boss_hp(realm: int) -> int:
	return int(round(float(boss_hp) * get_realm_hp_mult(realm) * boss_hp_mult))

func get_realm_boss_damage(realm: int) -> int:
	return int(round(float(boss_damage_on_reach) * get_realm_dmg_mult(realm)))

# §8.x — realm-specific gimmick lookups.
func realm_has_cluster_shake(realm: int, stage: int) -> bool:
	# §8.3: R2 shake on S3-S5. §8.5/8.6: also active when descent is on.
	if realm == 2 and stage >= 3: return true
	if realm == 4 and stage >= 4: return true
	if realm == 5 and stage >= 4: return true
	return false

# Returns sec/row for time-based descent, or 0 if no descent this realm/stage.
func realm_descent_sec_per_row(realm: int, stage: int) -> float:
	var s: int = clamp_stage(stage) - 1
	match realm:
		4: return float(R4_DESCENT_SEC_PER_ROW[s])
		5: return float(R5_DESCENT_SEC_PER_ROW[s])
		_: return 0.0

func realm_has_vine_lock(realm: int, _stage: int) -> bool:
	return realm == 3

func realm_has_mini_boss(realm: int, stage: int) -> bool:
	# §8.6 — R5S3 Echo of Voidcrown.
	return realm == 5 and stage == 3

func realm_has_two_boss_finale(realm: int, stage: int) -> bool:
	return realm == 5 and stage == 5

# §3.10.6 hero level multiplier — only applied when playtest_mode is on
# (greybox stand-in for actual leveling).
func hero_level_mult() -> float:
	return playtest_level_mult if playtest_mode else 1.0

# ============================================================
# §3.6 / §8.x — wave compositions per (realm, stage)
# Each entry: { "color": int, "variant": String }.
# Variants: "walker" | "runner" | "brute" | "shielder" | "healer" | "accelerator" | "phaser"
# Boss/mini-boss appended separately by MatchScene.
# ============================================================
func get_wave_composition(realm: int, stage: int) -> Array:
	var R: int = BubbleColor.RED
	var B: int = BubbleColor.BLUE
	var Y: int = BubbleColor.YELLOW
	var G: int = BubbleColor.GREEN
	var P: int = BubbleColor.PURPLE
	var W := "walker"
	var RUN := "runner"
	var BR := "brute"
	var SH := "shielder"
	var HL := "healer"
	var AC := "accelerator"
	var PH := "phaser"
	realm = clamp_realm(realm)
	stage = clamp_stage(stage)
	# §8.2 R1 — Skyline (5/8/12/15/20 counts)
	if realm == 1:
		match stage:
			1: return _w_color_x(R, W, 5)
			2: return _w_color_x(R, W, 5) + _w_color_x(B, W, 3)
			3: return _w_color_x(R, W, 5) + [{"color": R, "variant": RUN}] + _w_color_x(B, W, 3) + _w_color_x(Y, W, 2) + [{"color": Y, "variant": RUN}]
			4: return _w_color_x(R, W, 5) + _w_color_x(R, RUN, 2) + _w_color_x(B, W, 4) + _w_color_x(Y, W, 3) + [{"color": Y, "variant": BR}]
			5: return _w_color_x(R, W, 6) + _w_color_x(R, RUN, 3) + _w_color_x(B, W, 5) + _w_color_x(Y, W, 3) + _w_color_x(Y, BR, 3)
	# §8.3 R2 — Storm Reach
	if realm == 2:
		match stage:
			1: return _w_color_x(R, W, 6) + _w_color_x(B, W, 2)
			2: return _w_color_x(R, W, 5) + _w_color_x(B, W, 3) + _w_color_x(Y, W, 1)
			3: return _w_color_x(R, W, 5) + _w_color_x(B, W, 3) + _w_color_x(Y, W, 2) + [{"color": R, "variant": SH}]
			4: return _w_color_x(R, W, 6) + _w_color_x(B, W, 4) + _w_color_x(Y, W, 3) + [{"color": B, "variant": SH}, {"color": Y, "variant": BR}]
			5: return _w_color_x(R, W, 7) + _w_color_x(B, W, 5) + _w_color_x(Y, W, 4) + [{"color": R, "variant": SH}, {"color": B, "variant": SH}, {"color": R, "variant": BR}, {"color": Y, "variant": BR}]
	# §8.4 R3 — Verdant Maze
	if realm == 3:
		match stage:
			1: return _w_color_x(R, W, 4) + _w_color_x(B, W, 2) + _w_color_x(G, W, 2)
			2: return _w_color_x(R, W, 4) + _w_color_x(B, W, 2) + _w_color_x(G, W, 3) + _w_color_x(Y, W, 1)
			3: return _w_color_x(R, W, 5) + _w_color_x(B, W, 3) + _w_color_x(G, W, 3) + _w_color_x(Y, W, 1) + [{"color": G, "variant": HL}]
			4: return _w_color_x(R, W, 6) + _w_color_x(B, W, 4) + _w_color_x(G, W, 4) + _w_color_x(Y, W, 2) + [{"color": G, "variant": HL}, {"color": R, "variant": SH}]
			5: return _w_color_x(R, W, 6) + _w_color_x(B, W, 4) + _w_color_x(G, W, 5) + _w_color_x(Y, W, 3) + [{"color": G, "variant": HL}, {"color": G, "variant": HL}]
	# §8.5 R4 — Falling Spire
	if realm == 4:
		match stage:
			1: return _w_color_x(R, W, 5) + _w_color_x(B, W, 3) + _w_color_x(G, W, 3) + _w_color_x(Y, W, 1)
			2: return _w_color_x(R, W, 5) + _w_color_x(B, W, 4) + _w_color_x(G, W, 4) + _w_color_x(Y, W, 2) + [{"color": R, "variant": AC}]
			3: return _w_color_x(R, W, 6) + _w_color_x(B, W, 4) + _w_color_x(G, W, 4) + _w_color_x(Y, W, 2) + [{"color": R, "variant": AC}, {"color": B, "variant": AC}, {"color": G, "variant": HL}]
			4: return _w_color_x(R, W, 7) + _w_color_x(B, W, 5) + _w_color_x(G, W, 4) + _w_color_x(Y, W, 3) + [{"color": B, "variant": SH}, {"color": R, "variant": AC}, {"color": G, "variant": HL}, {"color": Y, "variant": BR}]
			5: return _w_color_x(R, W, 7) + _w_color_x(B, W, 5) + _w_color_x(G, W, 5) + _w_color_x(Y, W, 3) + [{"color": R, "variant": AC}, {"color": B, "variant": AC}, {"color": G, "variant": HL}, {"color": R, "variant": SH}, {"color": Y, "variant": BR}]
	# §8.6 R5 — Voidcrown
	if realm == 5:
		match stage:
			1: return _w_color_x(R, W, 5) + _w_color_x(B, W, 3) + _w_color_x(G, W, 3) + _w_color_x(Y, W, 2) + _w_color_x(P, W, 2)
			2: return _w_color_x(R, W, 5) + _w_color_x(B, W, 4) + _w_color_x(G, W, 4) + _w_color_x(Y, W, 3) + _w_color_x(P, W, 3) + [{"color": R, "variant": SH}, {"color": G, "variant": HL}]
			3: return _w_color_x(R, W, 5) + _w_color_x(B, W, 3) + _w_color_x(G, W, 3) + _w_color_x(Y, W, 2) + _w_color_x(P, W, 3) + [{"color": P, "variant": PH}, {"color": P, "variant": PH}]
			4: return _w_color_x(R, W, 5) + _w_color_x(B, W, 4) + _w_color_x(G, W, 4) + _w_color_x(Y, W, 3) + _w_color_x(P, W, 3) + [{"color": P, "variant": PH}, {"color": P, "variant": PH}, {"color": P, "variant": PH}, {"color": G, "variant": HL}, {"color": R, "variant": AC}, {"color": B, "variant": SH}]
			5: return _w_color_x(R, W, 6) + _w_color_x(B, W, 4) + _w_color_x(G, W, 4) + _w_color_x(Y, W, 3) + _w_color_x(P, W, 4) + [{"color": P, "variant": PH}, {"color": P, "variant": PH}, {"color": P, "variant": PH}, {"color": P, "variant": PH}, {"color": G, "variant": HL}, {"color": G, "variant": HL}, {"color": R, "variant": AC}, {"color": B, "variant": AC}]
	return [{"color": R, "variant": W}]

func _w_color_x(color: int, variant: String, count: int) -> Array:
	var out: Array = []
	for i in count: out.append({"color": color, "variant": variant})
	return out

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
