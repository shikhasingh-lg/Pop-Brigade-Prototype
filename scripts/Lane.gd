# Lane — manages hero placement, enemy spawning, combat targeting.
# Design spec §3.5 + §3.6.

class_name Lane
extends Node2D

signal enemy_reached_cannon(hp_damage: int)
signal lane_cleared()  # all enemies dead, no new spawns expected

const COLS := 8
const ROWS := 6
# Lane zone is 720x370 (MatchScene.tscn LaneZone, shrunk to push spawn line lower).
# CELL_H sized so 6 rows fit comfortably (6 * 60 = 360 < 370).
const CELL_W := 90.0
const CELL_H := 60.0
# Enemies "drop in" from near the top of the device. Lane is at world y=1020,
# so lane-local y = -15 * 60 + 30 = -870 puts them at world y≈150 (just below
# the HUDTop bar at y=120). They fast-travel through this above-lane region
# (Enemy uses ENEMY_FAST_SEC_PER_CELL when lane_row < 0), then switch to their
# color-stat speed once they reach row 0 (= the spawn line where heroes stand).
const ENEMY_SPAWN_ROW := -15
const ENEMY_FAST_SEC_PER_CELL := 0.25

var _heroes_by_cell: Array = []   # [row][col] = Hero | null
var _enemies: Array = []          # Array[Enemy]
@export var hero_scene: PackedScene
@export var enemy_scene: PackedScene

# Boon-applied damage multipliers (§4.2)
var class_damage_mult: Dictionary = {}  # color enum → mult; initialised in _ready()

# V8 §3.5: heroes are idle during Phase 1 (no enemies, no firing). MatchScene
# flips this true on _enter_phase_2 and false on _enter_phase_1.
var combat_enabled: bool = false

# V8 §3.5: colors that achieved a full-cluster clear during Phase 1 get a
# persistent +color_frenzy_buff_pct buff for ALL of Phase 2 (not a timer).
# MatchScene sets this on _enter_phase_2 before combat starts.
var frenzied_colors: Dictionary = {}  # color enum → true

func _ready() -> void:
	_heroes_by_cell.clear()
	for r in ROWS:
		var row := []
		for c in COLS: row.append(null)
		_heroes_by_cell.append(row)
	for color in GameConfig.all_bubble_colors():
		class_damage_mult[color] = 1.0

# Cell (row, col) → local position (lane-space). Centre of the cell.
func cell_to_local_pos(row: int, col: int) -> Vector2:
	return Vector2(col * CELL_W + CELL_W * 0.5, row * CELL_H + CELL_H * 0.5)

# ============================================================
# §3.4 — Hero spawn (from match pops)
# ============================================================
func spawn_hero(color: int, tier: String, col: int, source: String) -> void:
	# V8 §3.4 (v1 simplification): heroes stand ON the spawn line — only row 0
	# is used. If requested column is empty, place there. If occupied, find the
	# nearest empty row-0 cell. If row 0 is fully populated, replace the
	# most-damaged hero in row 0 (tie: oldest).
	col = clamp(col, 0, COLS - 1)
	if hero_scene == null:
		print("[Lane:no-hero-scene] spawn_hero color=%d tier=%s col=%d source=%s" % [color, tier, col, source])
		Telemetry.log_hero_spawn(color, tier, col, 0, source)
		return
	var target_col: int = _find_nearest_empty_col_in_row_0(col)
	if target_col == -1:
		_replace_most_damaged_hero_in_row_0(color, tier, source)
		return
	_instantiate_hero(color, tier, 0, target_col, source)

func _find_nearest_empty_col_in_row_0(preferred_col: int) -> int:
	if _heroes_by_cell[0][preferred_col] == null:
		return preferred_col
	# Search outward from preferred_col for the closest empty cell.
	for d in range(1, COLS):
		var left: int = preferred_col - d
		var right: int = preferred_col + d
		if left >= 0 and _heroes_by_cell[0][left] == null: return left
		if right < COLS and _heroes_by_cell[0][right] == null: return right
	return -1  # row 0 fully occupied

func _replace_most_damaged_hero_in_row_0(color: int, tier: String, source: String) -> void:
	var victim: Hero = null
	var victim_col := -1
	for c in COLS:
		var h: Hero = _heroes_by_cell[0][c]
		if h == null: continue
		if victim == null:
			victim = h; victim_col = c
			continue
		if h.hp < victim.hp:
			victim = h; victim_col = c
		elif h.hp == victim.hp and h.spawn_ms() < victim.spawn_ms():
			victim = h; victim_col = c
	if victim == null:
		push_warning("Lane._replace_most_damaged_hero_in_row_0: row 0 reported full but no victim found")
		return
	_heroes_by_cell[0][victim_col] = null
	victim.queue_free()
	_instantiate_hero(color, tier, 0, victim_col, source)

func _instantiate_hero(color: int, tier: String, target_row: int, col: int, source: String) -> void:
	var hero: Hero = hero_scene.instantiate()
	hero.color = color
	hero.tier = tier
	hero.lane_col = col
	hero.lane_row = target_row
	hero.damage_mult_class = class_damage_mult.get(color, 1.0)
	# If this color already earned a P1 frenzy, the new hero inherits the buff.
	if frenzied_colors.get(color, false):
		hero.damage_mult_global = 1.0 + GameConfig.color_frenzy_buff_pct
	hero.lane_ref = self
	# V1 simplification: row 0 heroes stand ON the spawn line (visual y offset
	# moves the hero up by CELL_H/2 so its bottom edge lands on the red line).
	hero.position = cell_to_local_pos(target_row, col)
	if target_row == 0:
		hero.position.y = -CELL_H * 0.5
	add_child(hero)
	_heroes_by_cell[target_row][col] = hero
	hero.died.connect(_on_hero_died)
	Telemetry.log_hero_spawn(color, tier, col, target_row, source)

func _replace_most_damaged_hero(new_color: int, new_tier: String, source: String) -> void:
	# §3.4: when no column has empty cells, find the hero with lowest HP across the whole lane.
	# Tie-break: oldest spawn (longest lifetime), since they've delivered the most value already.
	var victim: Hero = null
	var victim_row := -1
	var victim_col := -1
	for r in ROWS:
		for c in COLS:
			var h: Hero = _heroes_by_cell[r][c]
			if h == null: continue
			if victim == null:
				victim = h
				victim_row = r
				victim_col = c
				continue
			if h.hp < victim.hp:
				victim = h; victim_row = r; victim_col = c
			elif h.hp == victim.hp and h.spawn_ms() < victim.spawn_ms():
				victim = h; victim_row = r; victim_col = c
	if victim == null:
		# Should not happen — lane was reported full, but no heroes found. Log & bail.
		push_warning("Lane._replace_most_damaged_hero: lane reported full but no victim found")
		return
	# Free the victim and place the new hero in its cell.
	_heroes_by_cell[victim_row][victim_col] = null
	victim.queue_free()
	_instantiate_hero(new_color, new_tier, victim_row, victim_col, source)

func _on_hero_died(_id: int, _color: int, _tier: String, _life_ms: int, _dmg: int) -> void:
	# Find the cell holding this hero (its node is already queue_free'd, so compare instance id).
	for r in ROWS:
		for c in COLS:
			var h: Hero = _heroes_by_cell[r][c]
			if h != null and h.get_instance_id() == _id:
				_heroes_by_cell[r][c] = null
				return

# ============================================================
# §3.6 — Enemy spawn (from cluster conversion + base stage pacing)
# ============================================================
func spawn_enemy_from_conversion(color: int, col: int) -> void:
	# Legacy V2 path (cluster-as-spawner). V8 spec uses spawn_wave_enemy() instead.
	_spawn_enemy(color, col, "descent")

func spawn_enemy_from_stage_pacing(_stage_num: int) -> void:
	# Legacy V2 path. Unused under V8.
	var col := randi() % COLS
	var colors := GameConfig.all_bubble_colors()
	var picked: int = colors[randi() % colors.size()]
	_spawn_enemy(picked, col, "pacing")

# V8 §4.3 Stage 5: boss spawned by MatchScene after the walker wave finishes.
# Boss uses GameConfig.boss_hp / boss_damage_on_reach; visual = larger ColorRect
# via Enemy's tier-style scale heuristic (kept simple in v1 greybox).
func spawn_boss(color: int, col: int) -> Enemy:
	col = clamp(col, 0, COLS - 1)
	if enemy_scene == null:
		return null
	var e: Enemy = enemy_scene.instantiate()
	e.color = color
	e.lane_col = col
	# Match wave-enemy entry: drop in from near the top of the device.
	e.lane_row = ENEMY_SPAWN_ROW
	e.lane_ref = self
	e.position = Vector2(col * CELL_W + CELL_W * 0.5,
		float(ENEMY_SPAWN_ROW) * CELL_H + CELL_H * 0.5)
	e.is_boss = true
	e.boss_hp_override = GameConfig.boss_hp
	e.boss_damage_override = GameConfig.boss_damage_on_reach
	add_child(e)
	_enemies.append(e)
	e.reached_cannon.connect(_on_enemy_reached_cannon)
	e.died.connect(_on_enemy_died)
	Telemetry.log_enemy_spawn(e.get_instance_id(), color, col, 0, -1)
	return e

# V8 §3.6: scripted Phase 2 wave spawner. wave_index is the cumulative enemy
# index across the wave (0-based), used for round-robin column assignment + telemetry.
func spawn_wave_enemy(color: int, col: int, wave_index: int) -> void:
	col = clamp(col, 0, COLS - 1)
	if enemy_scene == null:
		Telemetry.log_enemy_spawn(0, color, col, 0, wave_index)
		return
	var e: Enemy = enemy_scene.instantiate()
	e.color = color
	e.lane_col = col
	# Spawn near the top of the device, well above the cluster, then march down
	# through the cluster area to the spawn line (where heroes wait at row 0).
	# Lane is at world y=1020; row 0 is at lane-local y=30. Virtual row
	# ENEMY_SPAWN_ROW puts the enemy near world y=150 (just below HUDTop).
	e.lane_row = ENEMY_SPAWN_ROW
	e.lane_ref = self
	e.position = Vector2(col * CELL_W + CELL_W * 0.5,
		float(ENEMY_SPAWN_ROW) * CELL_H + CELL_H * 0.5)
	add_child(e)
	_enemies.append(e)
	e.reached_cannon.connect(_on_enemy_reached_cannon)
	e.died.connect(_on_enemy_died)
	Telemetry.log_enemy_spawn(e.get_instance_id(), color, col, 0, wave_index)

func _spawn_enemy(color: int, col: int, source: String) -> void:
	col = clamp(col, 0, COLS - 1)
	if enemy_scene == null:
		print("[Lane:no-enemy-scene] spawn color=%d col=%d source=%s" % [color, col, source])
		Telemetry.log_enemy_spawn(0, color, col, 0)
		return
	var e: Enemy = enemy_scene.instantiate()
	e.color = color
	e.lane_col = col
	e.lane_row = 0  # top of lane
	e.lane_ref = self
	e.position = cell_to_local_pos(0, col)
	add_child(e)
	_enemies.append(e)
	e.reached_cannon.connect(_on_enemy_reached_cannon)
	e.died.connect(_on_enemy_died)
	Telemetry.log_enemy_spawn(e.get_instance_id(), color, col, 0)

func _on_enemy_reached_cannon(enemy_id: int, color: int, hp_damage: int) -> void:
	Telemetry.log_enemy_reached_cannon(enemy_id, color, hp_damage)
	emit_signal("enemy_reached_cannon", hp_damage)
	# Enemy frees itself; remove from registry.
	_enemies = _enemies.filter(func(en): return is_instance_valid(en) and en.get_instance_id() != enemy_id)
	if _enemies.is_empty():
		emit_signal("lane_cleared")

func _on_enemy_died(enemy_id: int, _color: int, _killed_by: int, _life_ms: int) -> void:
	_enemies = _enemies.filter(func(en): return is_instance_valid(en) and en.get_instance_id() != enemy_id)
	if _enemies.is_empty():
		emit_signal("lane_cleared")

# ============================================================
# §3.5 — Targeting helper for heroes
# ============================================================
# Nearest enemy within `range_cells` Euclidean radius (range is a radius, not column-locked).
# Tie-break: lowest current HP (focus-fire heuristic).
func find_enemy_in_range(hero: Hero, range_cells: int) -> Enemy:
	var best: Enemy = null
	var best_dist := INF
	for e in _enemies:
		if e == null or not is_instance_valid(e): continue
		var dx: float = e.lane_col - hero.lane_col
		var dy: float = e.lane_row - hero.lane_row
		var d := sqrt(dx * dx + dy * dy)
		if d > float(range_cells): continue
		if d < best_dist:
			best = e; best_dist = d
		elif is_equal_approx(d, best_dist) and best != null and e.hp < best.hp:
			best = e
	return best

# ============================================================
# §3.5 — Color frenzy buff
# V8: P1 full-clear of a color grants ALL Phase 2 heroes of that color a
# persistent +color_frenzy_buff_pct buff. Called by MatchScene._enter_phase_2
# AND from spawn_hero for any frenzied color (so heroes spawned in P1 after
# the frenzy event also inherit the buff).
# ============================================================
func apply_color_frenzy_persistent(color: int) -> void:
	frenzied_colors[color] = true
	var count := 0
	var mult: float = 1.0 + GameConfig.color_frenzy_buff_pct
	for r in ROWS:
		for c in COLS:
			var h: Hero = _heroes_by_cell[r][c]
			if h != null and h.color == color:
				h.damage_mult_global = mult
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
