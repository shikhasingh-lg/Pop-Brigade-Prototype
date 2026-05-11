# Lane — manages hero placement, enemy spawning, combat targeting.
# Design spec §3.5 + §3.6.

class_name Lane
extends Node2D

signal enemy_reached_cannon(hp_damage: int)
signal lane_cleared()  # all enemies dead, no new spawns expected

const COLS := 8
const ROWS := 6

var _heroes_by_cell: Array = []   # [row][col] = Hero | null
var _enemies: Array = []          # Array[Enemy]
@export var hero_scene: PackedScene
@export var enemy_scene: PackedScene

# Boon-applied damage multipliers (§4.2)
var class_damage_mult: Dictionary = {}  # color enum → mult; initialised in _ready()

func _ready() -> void:
	_heroes_by_cell.clear()
	for r in ROWS:
		var row := []
		for c in COLS: row.append(null)
		_heroes_by_cell.append(row)
	for color in GameConfig.all_bubble_colors():
		class_damage_mult[color] = 1.0

# ============================================================
# §3.4 — Hero spawn (from match pops)
# ============================================================
func spawn_hero(color: int, tier: String, col: int, source: String) -> void:
	# §3.4: spawn at lowest empty cell in `col` (bottom-up fill).
	# If column full, replace most-damaged hero in any column (tie: oldest).
	var target_row := -1
	for r in range(ROWS - 1, -1, -1):
		if _heroes_by_cell[r][col] == null:
			target_row = r
			break
	if target_row == -1:
		_replace_most_damaged_hero(color, tier, col)
		return
	var hero: Hero = hero_scene.instantiate()
	hero.color = color
	hero.tier = tier
	hero.lane_col = col
	hero.lane_row = target_row
	hero.damage_mult_class = class_damage_mult.get(color, 1.0)
	add_child(hero)
	# TODO: position hero at world coords for (target_row, col).
	_heroes_by_cell[target_row][col] = hero
	hero.died.connect(_on_hero_died)
	Telemetry.log_hero_spawn(color, tier, col, target_row, source)

func _replace_most_damaged_hero(new_color: int, new_tier: String, col: int) -> void:
	# TODO: find hero with lowest hp across whole lane (tie: oldest spawn_ms).
	# Remove it, recurse spawn_hero() into freed cell.
	push_warning("Lane._replace_most_damaged_hero: TODO")

func _on_hero_died(_id: int, _color: int, _tier: String, _life_ms: int, _dmg: int) -> void:
	# TODO: clear _heroes_by_cell[row][col] for the dead hero.
	pass

# ============================================================
# §3.6 — Enemy spawn (from cluster conversion + base stage pacing)
# ============================================================
func spawn_enemy_from_conversion(color: int, col: int) -> void:
	_spawn_enemy(color, col, "descent")

func spawn_enemy_from_stage_pacing(_stage_num: int) -> void:
	# Base pacing: random column, random color from current palette.
	var col := randi() % COLS
	var colors := GameConfig.all_bubble_colors()
	var picked: int = colors[randi() % colors.size()]
	_spawn_enemy(picked, col, "pacing")

func _spawn_enemy(color: int, col: int, source: String) -> void:
	var e: Enemy = enemy_scene.instantiate()
	e.color = color
	e.lane_col = col
	e.lane_row = 0  # top of lane
	add_child(e)
	_enemies.append(e)
	# TODO: position e at world coords for (0, col).
	e.reached_cannon.connect(_on_enemy_reached_cannon)
	e.died.connect(_on_enemy_died)
	Telemetry.log_enemy_spawn(e.get_instance_id(), color, col, 0)

func _on_enemy_reached_cannon(enemy_id: int, color: int, hp_damage: int) -> void:
	Telemetry.log_enemy_reached_cannon(enemy_id, color, hp_damage)
	emit_signal("enemy_reached_cannon", hp_damage)
	# Enemy frees itself.

func _on_enemy_died(enemy_id: int, _color: int, _killed_by: int, _life_ms: int) -> void:
	_enemies = _enemies.filter(func(en: Enemy): return en.get_instance_id() != enemy_id)
	if _enemies.is_empty():
		emit_signal("lane_cleared")

# ============================================================
# §3.5 — Targeting helper for heroes
# ============================================================
func find_enemy_in_range(hero: Hero, range_cells: int) -> Enemy:
	# §3.5: nearest enemy in range, prefer lowest-HP on ties (focus-fire).
	# TODO: iterate _enemies, compute cell-distance from hero, filter by range, sort.
	return null

# ============================================================
# §3.5 — Color frenzy buff (called by MatchScene when cluster clears a color)
# ============================================================
func apply_color_frenzy(color: int) -> void:
	var count := 0
	for r in ROWS:
		for c in COLS:
			var h: Hero = _heroes_by_cell[r][c]
			if h != null and h.color == color:
				h.apply_frenzy_buff()
				count += 1
	Telemetry.log_color_frenzy(color, count)

# ============================================================
# §4.2 — Apply class damage boon ("+25% red dmg" etc.)
# ============================================================
func apply_damage_boon(color: int, mult: float) -> void:
	class_damage_mult[color] = mult
	# Propagate to all live heroes of that color.
	for r in ROWS:
		for c in COLS:
			var h: Hero = _heroes_by_cell[r][c]
			if h != null and h.color == color:
				h.damage_mult_class = mult
