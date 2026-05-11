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
@export var cluster_descent_rate_sec: float = 8.0   # 1 row per N sec
@export var cluster_descent_pause_after_pop_sec: float = 1.0
@export var cluster_grow_trigger_misses: int = 8    # adds 1 row at top
@export var bubble_diameter_px: int = 72        # at 720-wide reference

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
@export_group("Heroes — Class Behavior")
@export var red_range_cells:    int = 3
@export var red_fire_rate_sec:  float = 1.0
@export var blue_range_cells:   int = 5
@export var blue_fire_rate_sec: float = 1.5
@export var blue_slow_pct:      float = 0.30    # 30% slow
@export var blue_slow_duration_sec: float = 2.0
@export var yellow_range_cells: int = 6         # full lane
@export var yellow_fire_rate_sec: float = 2.0

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

# ============================================================
# §3.7 — Special bubbles (v1: color bomb only)
# ============================================================
@export_group("Specials")
@export var color_bomb_cadence_shots_min: int = 12
@export var color_bomb_cadence_shots_max: int = 18

# ============================================================
# §3.8 — Player & stage
# ============================================================
@export_group("Player & Stage")
@export var stage_start_hp: int = 100
@export var stage_clear_no_enemies_sec: float = 3.0   # grace period
@export var coins_per_stage_clear: int = 50           # in-run, logged only
@export var boss_hp: int = 1000
@export var boss_damage_on_reach: int = 50

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
