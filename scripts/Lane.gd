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
const MERGE_BUTTON_SIZE := Vector2(74.0, 32.0)
const MERGE_BUTTON_Y := -122.0
const MERGEABLE_TIERS := {
	"bronze": "silver",
	"silver": "gold",
}

var _heroes_by_cell: Array = []   # [row][col] = Hero | null
var _enemies: Array = []          # Array[Enemy]
var _merge_buttons: Array = []    # Button controls for adjacent mergeable pairs
var _last_merge_ms: int = -100000
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
	# Initialise damage mults for ALL 5 colors so R3+ heroes don't read missing keys.
	for color in [GameConfig.BubbleColor.RED, GameConfig.BubbleColor.BLUE,
			GameConfig.BubbleColor.YELLOW, GameConfig.BubbleColor.GREEN,
			GameConfig.BubbleColor.PURPLE]:
		class_damage_mult[color] = 1.0

# Wipe heroes + enemies. Used by MatchScene debug stage-skip (F2).
func reset() -> void:
	_clear_merge_options()
	for r in ROWS:
		for c in COLS:
			var h: Hero = _heroes_by_cell[r][c]
			if h != null and is_instance_valid(h):
				h.queue_free()
			_heroes_by_cell[r][c] = null
	for e in _enemies:
		if e != null and is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	frenzied_colors.clear()
	for color in [GameConfig.BubbleColor.RED, GameConfig.BubbleColor.BLUE,
			GameConfig.BubbleColor.YELLOW, GameConfig.BubbleColor.GREEN,
			GameConfig.BubbleColor.PURPLE]:
		class_damage_mult[color] = 1.0
	combat_enabled = false

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
	# §4.2 boon overrides (one-shot; consumed in priority order):
	#   - Legendary Pact: first hero spawned this run is GOLD.
	#   - Lucky Draw:     next hero is silver-or-better.
	if RunState.boon_first_hero_gold_pending:
		tier = "gold"
		RunState.boon_first_hero_gold_pending = false
	elif RunState.boon_next_hero_silver_plus_pending and tier == "bronze":
		tier = "silver"
		RunState.boon_next_hero_silver_plus_pending = false
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
	_refresh_merge_options()

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
	_refresh_merge_options()

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
	Vfx.spawn_flash(hero)
	Telemetry.log_hero_spawn(color, tier, col, target_row, source)

func _next_tier(tier: String) -> String:
	return String(MERGEABLE_TIERS.get(tier, ""))

func _heroes_can_merge(a: Hero, b: Hero) -> bool:
	if a == null or b == null: return false
	if not is_instance_valid(a) or not is_instance_valid(b): return false
	if a.color != b.color: return false
	if a.tier != b.tier: return false
	return _next_tier(a.tier) != ""

func _clear_merge_options() -> void:
	for btn in _merge_buttons:
		if btn != null and is_instance_valid(btn):
			btn.queue_free()
	_merge_buttons.clear()

func clear_merge_options() -> void:
	_clear_merge_options()

func refresh_merge_options() -> void:
	_refresh_merge_options()

func _refresh_merge_options() -> void:
	_clear_merge_options()
	for c in range(COLS - 1):
		var a: Hero = _heroes_by_cell[0][c]
		var b: Hero = _heroes_by_cell[0][c + 1]
		if not _heroes_can_merge(a, b):
			continue
		_add_merge_button(c, c + 1, a.tier)

func _add_merge_button(left_col: int, right_col: int, tier: String) -> void:
	var btn := Button.new()
	btn.text = "MERGE"
	btn.tooltip_text = "%s + %s -> %s" % [
		tier.capitalize(),
		tier.capitalize(),
		_next_tier(tier).capitalize(),
	]
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.z_index = 80
	btn.size = MERGE_BUTTON_SIZE
	var mid_x: float = (float(left_col + right_col) + 1.0) * CELL_W * 0.5
	btn.position = Vector2(mid_x - MERGE_BUTTON_SIZE.x * 0.5, MERGE_BUTTON_Y)
	_style_merge_button(btn, tier)
	btn.set_meta("left_col", left_col)
	btn.set_meta("right_col", right_col)
	btn.pressed.connect(func():
		_merge_pair(left_col, right_col))
	add_child(btn)
	_merge_buttons.append(btn)

func _style_merge_button(btn: Button, tier: String) -> void:
	var tint: Color = Hero.TIER_COLORS.get(tier, Color(1.0, 0.86, 0.25))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(tint.r, tint.g, tint.b, 0.92)
	bg.border_color = Color(1, 1, 1, 0.85)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	var hover := bg.duplicate() as StyleBoxFlat
	hover.bg_color = bg.bg_color.lightened(0.10)
	var pressed := bg.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.bg_color.darkened(0.18)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.10, 0.08, 0.04, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.06, 0.04, 0.02, 1))
	btn.add_theme_font_size_override("font_size", 13)

func try_activate_merge_at_world_pos(world_pos: Vector2) -> bool:
	if not is_merge_option_at_world_pos(world_pos):
		return false
	for btn in _merge_buttons:
		if btn == null or not is_instance_valid(btn):
			continue
		if not btn.visible:
			continue
		if btn.get_global_rect().has_point(world_pos):
			_merge_pair(int(btn.get_meta("left_col")), int(btn.get_meta("right_col")))
			return true
	return false

func is_merge_option_at_world_pos(world_pos: Vector2) -> bool:
	for btn in _merge_buttons:
		if btn == null or not is_instance_valid(btn):
			continue
		if not btn.visible:
			continue
		if btn.get_global_rect().has_point(world_pos):
			return true
	return false

func _merge_pair(left_col: int, right_col: int) -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_merge_ms < 120:
		return
	_last_merge_ms = now_ms
	if left_col < 0 or right_col >= COLS or right_col != left_col + 1:
		return
	var a: Hero = _heroes_by_cell[0][left_col]
	var b: Hero = _heroes_by_cell[0][right_col]
	if not _heroes_can_merge(a, b):
		_refresh_merge_options()
		return
	var new_tier := _next_tier(a.tier)
	var new_color := a.color
	var target_col := left_col
	var badge_pos := (a.position + b.position) * 0.5 + Vector2(0, -30)
	_heroes_by_cell[0][left_col] = null
	_heroes_by_cell[0][right_col] = null
	a.queue_free()
	b.queue_free()
	_instantiate_hero(new_color, new_tier, 0, target_col, "merge")
	Vfx.floating_badge(self, badge_pos, new_tier.to_upper(), Hero.TIER_COLORS.get(new_tier, Color.WHITE))
	Telemetry.log_hero_merge(new_color, new_tier, left_col, right_col, target_col)
	_refresh_merge_options()

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
	_refresh_merge_options()

# Hit-test heroes against a world-space point. v2 §3.2 drag uses this — only
# row-0 heroes are draggable. Returns the row-0 hero whose center is closest
# to `world_pos` within `radius_px`, or null.
const _HERO_HIT_RADIUS_PX := 48.0
func find_hero_at_world_pos(world_pos: Vector2) -> Hero:
	var best: Hero = null
	var best_d2: float = _HERO_HIT_RADIUS_PX * _HERO_HIT_RADIUS_PX
	for c in COLS:
		var h: Hero = _heroes_by_cell[0][c]
		if h == null or not is_instance_valid(h): continue
		var d2: float = h.global_position.distance_squared_to(world_pos)
		if d2 < best_d2:
			best_d2 = d2
			best = h
	return best

# Find the nearest row-0 column to a world-space x (used during drag preview).
func world_x_to_row0_col(world_x: float) -> int:
	var local_x: float = world_x - global_position.x
	var c: int = int(round((local_x - CELL_W * 0.5) / CELL_W))
	return clamp(c, 0, COLS - 1)

# v2 §3.2 — drop a row-0 hero into target_col. Swap if occupied. No-op if the
# hero is already in target_col. Returns the resulting col (post-move).
func move_hero(hero: Hero, target_col: int) -> int:
	if hero == null or not is_instance_valid(hero): return -1
	target_col = clamp(target_col, 0, COLS - 1)
	# Locate hero's current cell (row 0 only — v1 lock).
	var src_col := -1
	for c in COLS:
		if _heroes_by_cell[0][c] == hero:
			src_col = c
			break
	if src_col == -1: return -1
	if src_col == target_col: return src_col
	_clear_merge_options()
	var occupant: Hero = _heroes_by_cell[0][target_col]
	_heroes_by_cell[0][target_col] = hero
	hero.lane_col = target_col
	hero.position = cell_to_local_pos(0, target_col)
	hero.position.y = -CELL_H * 0.5
	if occupant != null and is_instance_valid(occupant):
		_heroes_by_cell[0][src_col] = occupant
		occupant.lane_col = src_col
		occupant.position = cell_to_local_pos(0, src_col)
		occupant.position.y = -CELL_H * 0.5
	else:
		_heroes_by_cell[0][src_col] = null
	_refresh_merge_options()
	return target_col

# Snapshot of all living heroes for cross-stage carry-over.
# Returns Array of dicts: {color, tier, hp, row, col}.
func snapshot_heroes() -> Array:
	var out: Array = []
	for r in ROWS:
		for c in COLS:
			var h: Hero = _heroes_by_cell[r][c]
			if h == null or not is_instance_valid(h): continue
			out.append({
				"color": h.color,
				"tier":  h.tier,
				"hp":    h.hp,
				"row":   r,
				"col":   c,
			})
	return out

# Re-spawn previously-saved heroes at their exact saved cells with their saved HP.
# No heal, no reposition. Class-damage boons applied via class_damage_mult are
# picked up at instantiate time, so call this AFTER boons have been applied.
func restore_heroes(records: Array) -> void:
	for rec in records:
		var row: int = int(rec["row"])
		var col: int = int(rec["col"])
		if row < 0 or row >= ROWS or col < 0 or col >= COLS:
			continue
		if _heroes_by_cell[row][col] != null:
			continue
		_instantiate_hero(int(rec["color"]), String(rec["tier"]), row, col, "carryover")
		var h: Hero = _heroes_by_cell[row][col]
		if h != null:
			h.hp = int(rec["hp"])
	_refresh_merge_options()

func _on_hero_died(_id: int, _color: int, _tier: String, _life_ms: int, _dmg: int) -> void:
	# Find the cell holding this hero (its node is already queue_free'd, so compare instance id).
	for r in ROWS:
		for c in COLS:
			var h: Hero = _heroes_by_cell[r][c]
			if h != null and h.get_instance_id() == _id:
				_heroes_by_cell[r][c] = null
				_refresh_merge_options()
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

# Boss spawn — caller supplies realm-scaled HP/damage. Used by MatchScene for
# every S5 boss and the R5S3 mini-boss.
func spawn_boss(color: int, col: int, realm_num: int = 1, stage_num: int = 5,
		hp_override: int = 0, dmg_override: int = 0) -> Enemy:
	col = clamp(col, 0, COLS - 1)
	if enemy_scene == null:
		return null
	var e: Enemy = enemy_scene.instantiate()
	e.color = color
	e.lane_col = col
	e.lane_row = ENEMY_SPAWN_ROW
	e.lane_ref = self
	e.position = Vector2(col * CELL_W + CELL_W * 0.5,
		float(ENEMY_SPAWN_ROW) * CELL_H + CELL_H * 0.5)
	e.is_boss = true
	e.realm_num = realm_num
	e.stage_num = stage_num
	if hp_override > 0:
		e.boss_hp_override = hp_override
	else:
		e.boss_hp_override = GameConfig.get_realm_boss_hp(realm_num)
	if dmg_override > 0:
		e.boss_damage_override = dmg_override
	else:
		e.boss_damage_override = GameConfig.get_realm_boss_damage(realm_num)
	add_child(e)
	_enemies.append(e)
	e.reached_cannon.connect(_on_enemy_reached_cannon)
	e.died.connect(_on_enemy_died)
	Telemetry.log_enemy_spawn(e.get_instance_id(), color, col, 0, -1)
	return e

# V8 §3.6: scripted Phase 2 wave spawner. wave_index is the cumulative enemy
# index across the wave (0-based), used for round-robin column assignment + telemetry.
# `variant`: walker|runner|brute|shielder|healer|accelerator|phaser (§3.10.5)
# `realm_num` + `stage_num` drive scaling (§3.10.4).
func spawn_wave_enemy(color: int, col: int, wave_index: int, variant: String = "walker", stage_num: int = 1, realm_num: int = 1) -> void:
	col = clamp(col, 0, COLS - 1)
	if enemy_scene == null:
		Telemetry.log_enemy_spawn(0, color, col, 0, wave_index)
		return
	var e: Enemy = enemy_scene.instantiate()
	e.color = color
	e.lane_col = col
	e.variant = variant
	e.realm_num = realm_num
	e.stage_num = stage_num
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
# §3.5 — Per-class targeting (combat-design.md §2.1)
# ============================================================

# Fire Knight (RED) — cone in front: cols [hero.col ± red_cone_cols],
# rows [-red_cone_rows .. 0]. Pick the enemy CLOSEST to spawn line
# (largest lane_row in that range — i.e. about to cross).
func find_target_red(hero: Hero) -> Enemy:
	var best: Enemy = null
	var best_row := -9999
	var max_rows_up: int = GameConfig.red_cone_rows
	var col_span: int = GameConfig.red_cone_cols
	for e in _enemies:
		if e == null or not is_instance_valid(e): continue
		if abs(e.lane_col - hero.lane_col) > col_span: continue
		if e.lane_row > 0 or e.lane_row < -max_rows_up: continue
		if e.lane_row > best_row:
			best = e; best_row = e.lane_row
		elif e.lane_row == best_row and best != null and e.hp < best.hp:
			best = e
	return best

# Ice Mage (BLUE) — column lob: cols [hero.col ± blue_col_radius],
# rows [-blue_reach_rows .. 0]. Pick the enemy FURTHEST UP (smallest lane_row)
# so the lob lands among the densest pack.
func find_target_blue(hero: Hero) -> Enemy:
	var best: Enemy = null
	var best_row := 9999
	var max_rows_up: int = GameConfig.blue_reach_rows
	var col_span: int = GameConfig.blue_col_radius
	for e in _enemies:
		if e == null or not is_instance_valid(e): continue
		if abs(e.lane_col - hero.lane_col) > col_span: continue
		if e.lane_row > 0 or e.lane_row < -max_rows_up: continue
		if e.lane_row < best_row:
			best = e; best_row = e.lane_row
		elif e.lane_row == best_row and best != null and e.hp > best.hp:
			best = e  # tie: tag the beefier one
	return best

# Archer (YELLOW) — column snipe: cols == hero.col (fallback ±1),
# rows [-yellow_reach_rows .. 0]. Pick the enemy FURTHEST UP (smallest lane_row).
func find_target_yellow(hero: Hero) -> Enemy:
	var max_rows_up: int = GameConfig.yellow_reach_rows
	var best: Enemy = _scan_column(hero.lane_col, max_rows_up)
	if best != null:
		return best
	# Fallback: adjacent columns
	var left: Enemy = _scan_column(hero.lane_col - 1, max_rows_up)
	var right: Enemy = _scan_column(hero.lane_col + 1, max_rows_up)
	if left == null:  return right
	if right == null: return left
	# Pick the one furthest up
	return left if left.lane_row < right.lane_row else right

# Druid (GREEN, §8.4) — mid-range cone like Fire Knight but wider and longer.
# Picks the enemy nearest to row 0 (about to cross) within col_radius and reach.
func find_target_green(hero: Hero) -> Enemy:
	var best: Enemy = null
	var best_row := -9999
	var max_rows_up: int = GameConfig.green_reach_rows
	var col_span: int = GameConfig.green_col_radius
	for e in _enemies:
		if e == null or not is_instance_valid(e): continue
		if abs(e.lane_col - hero.lane_col) > col_span: continue
		if e.lane_row > 0 or e.lane_row < -max_rows_up: continue
		if e.lane_row > best_row:
			best = e; best_row = e.lane_row
		elif e.lane_row == best_row and best != null and e.hp < best.hp:
			best = e
	return best

# Wizard (PURPLE, §8.6) — full-column snipe like Archer (target picker shared).
func find_target_purple(hero: Hero) -> Enemy:
	var max_rows_up: int = GameConfig.purple_reach_rows
	var best: Enemy = _scan_column(hero.lane_col, max_rows_up)
	if best != null: return best
	var left: Enemy = _scan_column(hero.lane_col - 1, max_rows_up)
	var right: Enemy = _scan_column(hero.lane_col + 1, max_rows_up)
	if left == null:  return right
	if right == null: return left
	return left if left.lane_row < right.lane_row else right

# Druid chain heal — finds N nearest wounded allied heroes (excluding caster)
# and tops them up. Each healed hero gets capped at heal_per_hero_cap_per_sec.
func druid_chain_heal(caster: Hero) -> int:
	var amount: int = GameConfig.green_chain_heal_amount
	var max_targets: int = GameConfig.green_chain_heal_targets
	var cap: int = GameConfig.green_heal_per_hero_cap_per_sec
	# Find heroes by distance.
	var candidates: Array = []
	for r in ROWS:
		for c in COLS:
			var h: Hero = _heroes_by_cell[r][c]
			if h == null or not is_instance_valid(h): continue
			if h == caster: continue
			# Track wounded heroes only — heroes at full HP gain nothing.
			if h.hp >= h.max_total_hp(): continue
			candidates.append({"h": h, "d": (h.position - caster.position).length_squared()})
	candidates.sort_custom(func(a, b): return a.d < b.d)
	var healed: int = 0
	for entry in candidates:
		if healed >= max_targets: break
		var h: Hero = entry.h
		if not is_instance_valid(h): continue
		var ticked: int = h.try_heal(amount, cap)
		if ticked > 0:
			Vfx.floating_badge(self, h.position + Vector2(0, -36),
				"+%d" % ticked, Color(0.45, 1.0, 0.55))
		healed += 1
	return healed

# Public — front-most enemy in a column within reach. Used by tier lane-spread.
func find_front_in_col(col: int, max_rows_up: int) -> Enemy:
	return _scan_column(col, max_rows_up)

func _scan_column(col: int, max_rows_up: int) -> Enemy:
	if col < 0 or col >= COLS: return null
	var best: Enemy = null
	var best_row := 9999
	for e in _enemies:
		if e == null or not is_instance_valid(e): continue
		if e.lane_col != col: continue
		if e.lane_row > 0 or e.lane_row < -max_rows_up: continue
		if e.lane_row < best_row:
			best = e; best_row = e.lane_row
	return best

# AoE helper for Ice Mage splash. Returns enemies within `radius_cells` of
# a lane-local pixel point (CELL_W on x, CELL_H on y).
func enemies_in_aoe(center_local_pos: Vector2, radius_cells: float) -> Array:
	var hits: Array = []
	var r_sq_px: float = (radius_cells * CELL_H) * (radius_cells * CELL_H)
	for e in _enemies:
		if e == null or not is_instance_valid(e): continue
		var d_sq: float = (e.position - center_local_pos).length_squared()
		if d_sq <= r_sq_px:
			hits.append(e)
	return hits

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

# §4.2 Hero Synergy — every duplicate hero of a class adds +20% damage to that
# class. Idempotent: recomputes class multipliers from the current live roster
# each call. Stacks multiplicatively with apply_damage_boon (color_dmg boons).
func apply_hero_synergy() -> void:
	if not RunState.boon_hero_synergy: return
	var counts: Dictionary = {}
	for r in ROWS:
		for c in COLS:
			var h: Hero = _heroes_by_cell[r][c]
			if h != null and is_instance_valid(h):
				counts[h.color] = counts.get(h.color, 0) + 1
	for color in counts.keys():
		var dupes: int = max(0, int(counts[color]) - 1)
		var synergy_mult: float = 1.0 + 0.20 * float(dupes)
		var base_mult: float = class_damage_mult.get(color, 1.0)
		var final_mult: float = base_mult * synergy_mult
		for r in ROWS:
			for c in COLS:
				var h: Hero = _heroes_by_cell[r][c]
				if h != null and h.color == color:
					h.damage_mult_class = final_mult
