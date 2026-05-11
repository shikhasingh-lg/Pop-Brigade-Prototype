# Cluster — manages the hex grid of bubbles + descent + match detection.
# Design spec §3.2.
# This is THE V2 cluster-as-spawner core. Most playtest signal lives here.

class_name Cluster
extends Node2D

signal cluster_grew(new_height: int)
signal cluster_descended(rows_now: int)
signal match_popped(color: int, match_size: int, chain_count: int, positions: Array)
signal bubble_crossed_spawn_line(color: int, col: int)
signal cluster_reached_lane()  # game over signal

const COLS_EVEN := 8
const COLS_ODD  := 7   # offset rows have 1 less for hex packing
const BUBBLE_SIZE_PX := 64.0
const ROW_HEIGHT_PX  := 56.0  # tighter than diameter for hex tessellation

# Grid storage: rows × cols. null = empty cell.
var grid: Array = []        # grid[row][col] = Bubble | null
var current_height: int = 0
var _descent_timer: float = 0.0
var _consecutive_misses: int = 0
var _last_descend_ms: int = 0
var _initial_y: float = 0.0

@export var bubble_scene: PackedScene
@export var spawn_line_y: float = 0.0   # set by MatchScene based on layout

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	_initial_y = position.y

func setup_for_stage(stage_num: int) -> void:
	current_height = GameConfig.get_stage_start_rows(stage_num)
	_clear_visual_grid()
	grid.clear()
	for row in range(current_height):
		var is_offset := row % 2 == 1
		var cols_this_row := COLS_ODD if is_offset else COLS_EVEN
		var row_data: Array = []
		for col in range(cols_this_row):
			var b: Bubble = bubble_scene.instantiate()
			b.color = _pick_random_color()
			# 1 color bomb on stage >= 4 (§3.7)
			if stage_num >= 4 and row == 1 and col == 3:
				b.is_special_color_bomb = true
			b.position = _cell_to_local_pos(row, col, is_offset)
			add_child(b)
			row_data.append(b)
		grid.append(row_data)
	position.y = _initial_y
	_descent_timer = 0.0
	_last_descend_ms = Time.get_ticks_msec()

func _clear_visual_grid() -> void:
	for child in get_children():
		if child is Bubble:
			child.queue_free()

func _pick_random_color() -> int:
	var colors := GameConfig.all_bubble_colors()
	return colors[randi() % colors.size()]

func _cell_to_local_pos(row: int, col: int, is_offset: bool) -> Vector2:
	var x := col * BUBBLE_SIZE_PX + (BUBBLE_SIZE_PX * 0.5 if is_offset else 0.0)
	var y := row * ROW_HEIGHT_PX
	return Vector2(x, y)

# ============================================================
# §3.2 — Descent (visual + spawn-line crossing)
# ============================================================
func _process(delta: float) -> void:
	_descent_timer += delta
	if _descent_timer >= GameConfig.cluster_descent_rate_sec:
		_descent_timer = 0.0
		_descend_one_row()

func _descend_one_row() -> void:
	# Smooth slide down by 1 row height
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + ROW_HEIGHT_PX, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var now_ms := Time.get_ticks_msec()
	Telemetry.log_cluster_descend(current_height, now_ms - _last_descend_ms)
	_last_descend_ms = now_ms
	emit_signal("cluster_descended", current_height)
	# TODO §3.2: any bubble whose world-Y now exceeds spawn_line_y → emit bubble_crossed_spawn_line(), remove from grid.
	# TODO §3.2: if grid is empty above spawn line → emit cluster_reached_lane() (game over).

func pause_descent(seconds: float) -> void:
	# Called by MatchScene after a pop (§3.2: "Descent is paused for 1s after every successful pop").
	_descent_timer = -seconds

# ============================================================
# §3.2 — Attach + match (TODO — W1 of build sprint)
# ============================================================
func attach_bubble(bubble: Bubble, _at_world_pos: Vector2) -> void:
	# TODO: convert world pos → nearest empty hex (row, col) adjacent to existing bubble or top wall.
	# TODO: if (row, col) is below spawn line → emit bubble_crossed_spawn_line(), DO NOT attach.
	# TODO: else → place into grid, bubble.attach_to_grid(row, col).
	# TODO: run match detection from this bubble. If match ≥ 3, call _pop_match(...).
	# TODO: if no match, increment _consecutive_misses. After GameConfig.cluster_grow_trigger_misses, add 1 row.
	push_warning("Cluster.attach_bubble: TODO")
	Telemetry.log_bubble_attached(bubble.color, bubble.grid_row, bubble.grid_col, _count_bubbles())

func _pop_match(color: int, positions: Array) -> void:
	# §3.4: match-3 = bronze, match-4 = silver, match-5+ = gold (+ bronzes for 6+).
	# After pop, run _process_falling() for disconnect cascade.
	# Each falling bubble = bronze hero of its color (§3.2).
	# Emit match_popped() with chain_count to MatchScene for hero spawn.
	_consecutive_misses = 0
	push_warning("Cluster._pop_match: TODO")
	emit_signal("match_popped", color, positions.size(), 0, positions)
	pause_descent(GameConfig.cluster_descent_pause_after_pop_sec)

func _process_falling() -> Array:
	# §3.2: any bubble disconnected from top after a pop falls.
	# Returns list of (color) for cascade heroes. Falling bubbles do NOT convert to enemies (v1).
	# TODO: flood-fill from top row; anything not reached falls.
	return []

# ============================================================
# Helpers
# ============================================================
func _count_bubbles() -> int:
	var n := 0
	for row in grid:
		for cell in row:
			if cell != null: n += 1
	return n

# ============================================================
# Open question OQ8 (§7.1): should falling bubbles convert to enemies?
# v1 = NO. Re-test in v2 if Q2 passes "too easy".
# ============================================================
